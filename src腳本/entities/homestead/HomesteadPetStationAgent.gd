# res://src腳本/entities/homestead/HomesteadPetStationAgent.gd
extends CharacterBody2D
## 腳底 `CollisionShape2D`（與 `PetCompanion` 同尺寸）供 `move_and_slide` 與 `TerrainCollision`（預設 layer 1）相碰；`InteractionArea` 僅供玩家靠近互動。
## `_ready` 對主角做雙向 `add_collision_exception_with`，避免與玩家 CharacterBody2D 互推黏連（仍會撞牆）。

const _ID_PREFIX := "homestead_station:"
const _PLAYER_BASE_Z := 5
## 閒晃節奏：數值為「待機多久再選下一個漫遊點」；加倍後較悠哉、較好找。
const _IDLE_MIN_SEC := 1.6
const _IDLE_MAX_SEC := 4.4
const _DEFAULT_MIN_SPACING := 24.0
const _ARRIVE_DIST := 8.0
const _FOLLOW_LERP_WEIGHT := 0.2
const _HOMESTEAD_TILL_RANGE := 58.0
const _LIGHT_TICK_DIST := 540.0
## 離線超過此秒數：清移動目標，避免半路上凍結太久
const _OFFLINE_CLEAR_MOVE_TARGET_SEC := 48.0
## 離線超過此秒數：速度歸零（短暫離開仍保留慣性語意可有可無）
const _OFFLINE_ZERO_VEL_SEC := 12.0
## 存檔還原的移動目標若離「目前漫遊錨點」過遠（舊版城鎮座標、改場景後遺留），會一路往外衝；載入後丟棄該目標。
const _SNAPSHOT_TARGET_MAX_DIST_FROM_ANY_ROAM_PX := 240.0
const _RECALL_FADE_SEC := 0.16

@onready var _area: Area2D = $InteractionArea
@onready var _prompt_anchor: Marker2D = $PromptAnchor
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _npc_id: String = ""
var _prompt: String = ""
var _inside: bool = false
var _wired: bool = false
var _pet: PetResource = null
var _roam_points: Array[Vector2] = []
var _move_target: Vector2 = Vector2.ZERO
var _idle_timer: float = 0.0
var _has_target: bool = false
var _active_lod: bool = true
var _light_tick_sec: float = 0.45
var _light_tick_left: float = 0.0
var _move_speed: float = 70.0
var _last_dir: String = "down"
var _min_spacing: float = _DEFAULT_MIN_SPACING
var _till_skill: SkillResource = null
var _till_cooldown_left: float = 0.0
var _frozen_for_interaction: bool = false


func _ready() -> void:
	# 與主角 CharacterBody2D 不做實體互推（仍會與地形相碰）；需雙向 exception，否則單向仍可能黏連。
	call_deferred("_apply_player_collision_exceptions")


func _apply_player_collision_exceptions() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var p: Node = tree.get_first_node_in_group("player")
	if p is PhysicsBody2D:
		var pb := p as PhysicsBody2D
		add_collision_exception_with(pb)
		pb.add_collision_exception_with(self)


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if p.global_position.y < global_position.y:
		z_index = _PLAYER_BASE_Z + 1
	else:
		z_index = _PLAYER_BASE_Z - 1


func setup(pet: PetResource) -> void:
	if pet == null or pet.instance_id.strip_edges().is_empty():
		push_warning("[StationAgent] setup failed: pet or instance_id missing")
		return
	_pet = pet
	_npc_id = _ID_PREFIX + pet.instance_id
	var nm := pet.nickname.strip_edges() if pet.nickname.strip_edges() != "" else pet.pet_name
	_prompt = "照顧%s" % nm
	_till_skill = _resolve_homestead_till_skill(pet)
	_move_speed = 68.0 * clampf(pet.follow_speed_mult, 0.55, 1.5)
	_idle_timer = randf_range(_IDLE_MIN_SEC, _IDLE_MAX_SEC)
	_light_tick_left = randf_range(0.12, _light_tick_sec)
	var sf := _resolve_station_sprite_frames(pet)
	if sf and _sprite:
		_sprite.sprite_frames = sf.duplicate(true)
		var anim := "idle_down"
		if not _sprite.sprite_frames.has_animation(anim):
			var names := _sprite.sprite_frames.get_animation_names()
			if names.size() > 0:
				anim = str(names[0])
		if _sprite.sprite_frames.has_animation(anim):
			_sprite.play(anim)
	if _area and not _wired:
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)
	if SignalBus and not _wired:
		SignalBus.dialogue_blocking_changed.connect(_on_dialogue_blocking_changed)
	_wired = true


func get_pet_instance_id() -> String:
	if _pet == null:
		return ""
	return _pet.instance_id.strip_edges()


func fade_out_and_queue_free(duration_sec: float = _RECALL_FADE_SEC) -> void:
	set_physics_process(false)
	set_process(false)
	velocity = Vector2.ZERO
	if self is CanvasItem:
		var ci := self as CanvasItem
		ci.modulate.a = 1.0
		var d := maxf(0.01, duration_sec)
		var tw := ci.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(ci, "modulate:a", 0.0, d)
		tw.finished.connect(func() -> void:
			if is_instance_valid(self):
				queue_free()
		, CONNECT_ONE_SHOT)
		return
	queue_free()


func setup_runtime(roam_points: Array[Vector2], min_spacing: float) -> void:
	_roam_points = roam_points.duplicate()
	_min_spacing = maxf(8.0, min_spacing)
	_move_target = global_position
	_has_target = false


func set_lod_mode(active_mode: bool, light_tick_interval_sec: float) -> void:
	_active_lod = active_mode
	_light_tick_sec = maxf(0.1, light_tick_interval_sec)


func get_runtime_save_snapshot() -> Dictionary:
	if _pet == null or _pet.instance_id.strip_edges().is_empty():
		return {}
	return {
		"instance_id": _pet.instance_id,
		"gx": global_position.x,
		"gy": global_position.y,
		"has_target": _has_target,
		"tx": _move_target.x,
		"ty": _move_target.y,
		"idle_timer": _idle_timer,
		"till_cd": _till_cooldown_left,
		"vx": velocity.x,
		"vy": velocity.y,
	}


func apply_runtime_save_snapshot(data: Dictionary, offline_elapsed_sec: int = 0) -> void:
	if data.is_empty() or _pet == null:
		return
	var gx := float(data.get("gx", global_position.x))
	var gy := float(data.get("gy", global_position.y))
	global_position = Vector2(gx, gy)
	_has_target = bool(data.get("has_target", false))
	_move_target = Vector2(float(data.get("tx", gx)), float(data.get("ty", gy)))
	_idle_timer = clampf(float(data.get("idle_timer", _IDLE_MIN_SEC)), 0.0, 120.0)
	_till_cooldown_left = maxf(0.0, float(data.get("till_cd", 0.0)))
	velocity = Vector2(float(data.get("vx", 0.0)), float(data.get("vy", 0.0)))
	_light_tick_left = randf_range(0.12, _light_tick_sec)
	var el := float(maxi(0, offline_elapsed_sec))
	if el > 0.0:
		_till_cooldown_left = maxf(0.0, _till_cooldown_left - el)
		_idle_timer = maxf(0.0, _idle_timer - el)
		if el >= _OFFLINE_CLEAR_MOVE_TARGET_SEC:
			_has_target = false
			_move_target = global_position
			velocity = Vector2.ZERO
		elif el >= _OFFLINE_ZERO_VEL_SEC:
			velocity = Vector2.ZERO
	_sanitize_runtime_after_snapshot_load()


## 還原存檔後：清掉不可能屬於「目前田園錨點」的遠端目標與殘速，避免一進遊戲就往外衝。
func _sanitize_runtime_after_snapshot_load() -> void:
	velocity = Vector2.ZERO
	if _idle_timer < 0.05:
		_idle_timer = randf_range(_IDLE_MIN_SEC, _IDLE_MAX_SEC)
	if not _has_target:
		return
	var d_to_target := global_position.distance_to(_move_target)
	if d_to_target > 900.0:
		_has_target = false
		_move_target = global_position
		return
	if _roam_points.is_empty():
		return
	var best := INF
	for rp in _roam_points:
		best = minf(best, _move_target.distance_to(rp))
	if best > _SNAPSHOT_TARGET_MAX_DIST_FROM_ANY_ROAM_PX:
		_has_target = false
		_move_target = global_position


func _physics_process(delta: float) -> void:
	if _pet == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _frozen_for_interaction:
		velocity = velocity.lerp(Vector2.ZERO, 0.35)
		move_and_slide()
		_update_visual(Vector2.ZERO, false)
		return
	_till_cooldown_left = maxf(0.0, _till_cooldown_left - delta)
	if _active_lod:
		_tick_agent(delta)
	else:
		_light_tick_left -= delta
		if _light_tick_left <= 0.0:
			_light_tick_left = _light_tick_sec
			_tick_agent(_light_tick_sec)
	move_and_slide()


func _tick_agent(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) > _LIGHT_TICK_DIST:
		velocity = velocity.lerp(Vector2.ZERO, 0.25)
		_update_visual(Vector2.ZERO, false)
		return
	if _try_homestead_till():
		velocity = velocity.lerp(Vector2.ZERO, 0.28)
		return
	if _has_target:
		var to_target := _move_target - global_position
		var dist := to_target.length()
		if dist <= _ARRIVE_DIST:
			_has_target = false
			_idle_timer = randf_range(_IDLE_MIN_SEC, _IDLE_MAX_SEC)
			velocity = velocity.lerp(Vector2.ZERO, 0.3)
			_update_visual(Vector2.ZERO, false)
			return
		var dir := to_target / maxf(0.001, dist)
		var target_vel := dir * _move_speed
		velocity = velocity.lerp(target_vel, _FOLLOW_LERP_WEIGHT)
		_update_visual(dir, true)
		return
	_idle_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, 0.25)
	_update_visual(Vector2.ZERO, false)
	if _idle_timer <= 0.0:
		_pick_new_target()
		_idle_timer = randf_range(_IDLE_MIN_SEC, _IDLE_MAX_SEC)


func _pick_new_target() -> void:
	var candidates: Array[Vector2] = []
	if _roam_points.is_empty():
		candidates.append(global_position + Vector2(randf_range(-56.0, 56.0), randf_range(-44.0, 44.0)))
	else:
		for p in _roam_points:
			var jitter := Vector2(randf_range(-22.0, 22.0), randf_range(-18.0, 18.0))
			candidates.append(p + jitter)
	var best := global_position
	var best_score := -INF
	for c in candidates:
		var score := c.distance_squared_to(global_position)
		for n in get_tree().get_nodes_in_group("homestead_station_visual"):
			if n == null or not is_instance_valid(n) or n == self:
				continue
			if not (n is Node2D):
				continue
			var d := c.distance_to((n as Node2D).global_position)
			if d < _min_spacing:
				score -= 1000000.0
		if score > best_score:
			best_score = score
			best = c
	_move_target = best
	_has_target = true


func _update_visual(move_dir: Vector2, moving: bool) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if move_dir.length_squared() > 0.001:
		if absf(move_dir.y) > absf(move_dir.x) * 1.3:
			_last_dir = "down" if move_dir.y > 0 else "up"
		else:
			_last_dir = "side"
			_sprite.flip_h = move_dir.x > 0.0
	var base := "run_" if moving else "idle_"
	var candidate := base + _last_dir
	if _sprite.sprite_frames.has_animation(candidate):
		if _sprite.animation != candidate:
			_sprite.play(candidate)
		return
	if _sprite.sprite_frames.has_animation("idle_down"):
		if _sprite.animation != "idle_down":
			_sprite.play("idle_down")


func _resolve_homestead_till_skill(pet: PetResource) -> SkillResource:
	if pet == null:
		return null
	for e in pet.skills:
		if e == null:
			continue
		var s := e.skill as SkillResource
		if s != null and s.is_homestead_till_skill:
			return s
	return null


func _try_homestead_till() -> bool:
	if _till_skill == null or _till_cooldown_left > 0.0:
		return false
	var plot := _find_nearest_untilled_plot()
	if plot == null:
		return false
	if not (plot is Node2D):
		return false
	var p2 := plot as Node2D
	if global_position.distance_to(p2.global_position) > _HOMESTEAD_TILL_RANGE:
		return false
	if not plot.has_method("till_from_pet") or not bool(plot.call("till_from_pet", self)):
		return false
	_till_cooldown_left = maxf(1.2, _till_skill.cooldown)
	var d := p2.global_position - global_position
	_update_visual(d.normalized(), false)
	return true


func _find_nearest_untilled_plot() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node = null
	var best_d := INF
	for n in tree.get_nodes_in_group("homestead_soil_plot"):
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method("can_pet_till") or not bool(n.call("can_pet_till")):
			continue
		if not (n is Node2D):
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _resolve_station_sprite_frames(pet: PetResource) -> SpriteFrames:
	if pet == null:
		return null
	if pet.sprite_frames != null:
		return pet.sprite_frames
	var pid := pet.pet_id.strip_edges()
	if not pid.is_empty():
		var mpath := "res://resources身分證/monster/%s.tres" % pid
		if ResourceLoader.exists(mpath):
			var mres := load(mpath) as MonsterResource
			if mres and mres.sprite_frames:
				return mres.sprite_frames
	var fallback := load("res://resources身分證/monster/slime_green.tres") as MonsterResource
	return fallback.sprite_frames if fallback else null


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_frozen_for_interaction = true
	_inside = true
	if _npc_id.is_empty():
		return
	NpcInteractionManager.set_active_proximity(_npc_id, _prompt, _prompt_anchor.global_position)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_frozen_for_interaction = false
	_inside = false
	NpcInteractionManager.clear_proximity_if_match(_npc_id)


func _on_dialogue_blocking_changed(blocked: bool) -> void:
	if blocked or not _inside or _npc_id.is_empty():
		return
	NpcInteractionManager.set_active_proximity(_npc_id, _prompt, _prompt_anchor.global_position)
