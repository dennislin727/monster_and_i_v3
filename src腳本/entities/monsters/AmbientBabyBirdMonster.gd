# res://src腳本/entities/monsters/AmbientBabyBirdMonster.gd
## 湖畔環境：不參與戰鬥 AI；驚飛 → 離屏 → 延遲後隨機落點（lake_baby_bird_perch）。
## 量身訂做：本腳本**只**應掛在 `BabyBirdMonster.tscn`（環境寶寶）。
## 戰鬥隔離：覆寫 `is_targetable() == false` + 關閉 `HurtboxComponent` 碰撞／監測（封印仍用距離判定，不依賴 hurtbox）。
## 若仍出現受擊／鎖定，可能原因：場景複用了別的怪物根節點、hurtbox 被場景覆寫回可碰撞、或直接呼叫 `HealthComponent.take_damage` 的第三方技能。
@tool
extends MonsterBase

## 若場景未帶入 data，執行期補上，避免 `data == null` → 無環境 AI、封印結算讀不到 capture_rate。
const BIRD_MONSTER_DATA := "res://resources身分證/monster/baby_bird_monster.tres"

const GROUP_PERCH := "lake_baby_bird_perch"
## 進入此距離內開始累積「緩衝」，滿了才飛（避免螢幕邊緣一入圈就逃）。
const FLEE_TRIGGER_RADIUS := 92.0
## 累積滿此秒數才驚飛（主角在觸發圈內持續靠近時仍會累積）。
const FLEE_GRACE_SEC := 0.85
## 少於此距離：不等待，立刻飛（貼臉驚嚇）。
const FLEE_PANIC_RADIUS := 48.0
const FLEE_SPEED_START := 195.0
const FLEE_SPEED_MAX := 315.0
const FLEE_SPEED_RAMP := 520.0
const OFFSCREEN_RESPAWN_SEC := 5.0
const WANDER_RADIUS := 38.0
const WANDER_SPEED := 48.0
const WANDER_INTERVAL_MIN := 2.4
const WANDER_INTERVAL_MAX := 5.6
## 較長間隔 + 循環換段，避免隨機硬切像卡頓。
const IDLE_SHUFFLE_MIN := 4.8
const IDLE_SHUFFLE_MAX := 9.0

## 與 `ProgressionManager.lake_ambient_baby_bird_cleared_mask` 對齊；`LakeSideLevel` 多隻時設 0、1、… 不重複。
@export_range(0, 7) var lake_ambient_save_slot: int = 0

enum AmbState { PERCH, FLEE, OFFSCREEN }

var _amb_state: AmbState = AmbState.PERCH
var _player: PlayerController
var _offscreen_timer: float = 0.0
var _wander_timer: float = 0.0
var _perch_anchor: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _flee_dir: Vector2 = Vector2.RIGHT
var _rng := RandomNumberGenerator.new()
## 停佇／閒晃時朝向：不依「面向主角」，改依最近一次位移
var _ambient_motion_ref: Vector2 = Vector2(0, 1)
var _idle_variant_timer: float = 0.0
var _was_wandering_moving: bool = false
var _flee_grace_timer: float = 0.0
var _flee_speed_current: float = FLEE_SPEED_MAX
var _idle_variant_cycle_idx: int = 0
## 與 PetCompanion 相同：本體上移量（影子不跟），驚飛時依與主角距離漸強。
var _ambient_flight_y: float = 0.0
var _bb_anim_base_pos: Vector2 = Vector2.ZERO


func get_lake_ambient_save_slot() -> int:
	return lake_ambient_save_slot


func _is_ambient_baby_bird() -> bool:
	if data == null:
		return false
	if data.participates_in_combat:
		return false
	if data.pet_data == null:
		return false
	return data.pet_data.pet_id == "baby_bird"


## 此類別即「環境寶寶」專用，不依賴 MonsterResource 是否已載入（避免 data 晚一幀時被當成可鎖定怪）。
func is_targetable() -> bool:
	return false


func _deactivate_combat_hurtbox_and_groups() -> void:
	remove_from_group("monsters")
	var hb: Node = get_node_or_null("HurtboxComponent")
	if hb is CollisionObject2D:
		var co := hb as CollisionObject2D
		co.set_deferred("monitoring", false)
		co.set_deferred("monitorable", false)
		co.collision_layer = 0
		co.collision_mask = 0


## 與 MonsterBase 一致：layer 2、mask 1，才能被多數地形 StaticBody（layer 1）擋住。
## 先前誤用 layer 8：地形 mask 若只有 bit0，(8 & 1)==0 會完全穿地墜落 → 看起來像進場就消失。
func _configure_ambient_physics_no_stick_with_player() -> void:
	collision_layer = 2
	collision_mask = 1


## 與出戰寶寶相同：`MonsterBase` 預設影子偏移／縮放是為史萊姆調的，寶寶圖與寵物共用 SpriteFrames 時應對齊 PetCompanion。
func _align_shadow_with_pet_baby() -> void:
	var sc: Node = get_node_or_null("ShadowComponent")
	if sc == null:
		return
	if GlobalBalance != null:
		if sc.get("base_offset") != null:
			sc.set("base_offset", GlobalBalance.PET_COMPANION_SHADOW_BASE_OFFSET)
		if sc.get("shadow_scale") != null:
			sc.set("shadow_scale", GlobalBalance.PET_COMPANION_SHADOW_SCALE)
	else:
		sc.set("base_offset", Vector2(-0.665, 20.715))
		sc.set("shadow_scale", Vector2(0.8, 0.4))


func _update_ambient_flee_flight(delta: float) -> void:
	if GlobalBalance == null:
		return
	var dist: float
	if _player != null and is_instance_valid(_player):
		dist = global_position.distance_to(_player.global_position)
	else:
		dist = GlobalBalance.BABY_BIRD_FLIGHT_DIST_MAX
	var t01 := inverse_lerp(GlobalBalance.BABY_BIRD_FLIGHT_DIST_MIN, GlobalBalance.BABY_BIRD_FLIGHT_DIST_MAX, dist)
	var target_y: float = clampf(t01, 0.0, 1.0) * GlobalBalance.BABY_BIRD_FLIGHT_Y_MAX
	_ambient_flight_y = lerpf(_ambient_flight_y, target_y, GlobalBalance.BABY_BIRD_FLIGHT_LERP * delta)


## 對齊 PetCompanion._apply_baby_bird_visual_offsets：僅移動本體精靈，ShadowComponent 留在原點 → 與影子分離。
func _apply_ambient_flight_visual() -> void:
	if not _is_ambient_baby_bird() or anim == null:
		return
	if _amb_state == AmbState.FLEE:
		var lift := -_ambient_flight_y
		anim.position = Vector2(_bb_anim_base_pos.x, _bb_anim_base_pos.y + lift)
	else:
		_ambient_flight_y = 0.0
		anim.position = _bb_anim_base_pos


func get_dir_string() -> String:
	if not _is_ambient_baby_bird():
		return super.get_dir_string()
	var ref := velocity
	if ref.length() < 10.0:
		ref = _ambient_motion_ref
	if ref.length() < 0.001:
		return last_dir_str
	_dir_smooth_ref = _dir_smooth_ref.lerp(ref, 0.26) if _dir_smooth_ref.length_squared() > 0.0001 else ref
	var sr := _dir_smooth_ref
	if absf(sr.y) > absf(sr.x) * 1.5:
		last_dir_str = "down" if sr.y > 0 else "up"
	else:
		last_dir_str = "side"
	return last_dir_str


func play_monster_animation(anim_name: String) -> void:
	if anim_name == "idle" and _is_ambient_baby_bird():
		_play_ambient_idle_variant()
		return
	super.play_monster_animation(anim_name)


func _play_ambient_idle_variant() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var d := get_dir_string()
	var base := "idle_" + d
	var candidates: Array[StringName] = []
	for aname in anim.sprite_frames.get_animation_names():
		var s := String(aname)
		if s == base or s.begins_with(base + "_"):
			candidates.append(aname)
	if candidates.is_empty():
		super.play_monster_animation("idle")
		return
	candidates.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var n := candidates.size()
	var picked: StringName = candidates[_idle_variant_cycle_idx % n]
	_idle_variant_cycle_idx = (_idle_variant_cycle_idx + 1) % maxi(n, 1)
	_safe_animated_play(anim, picked)
	_apply_ambient_idle_flip_for_animation_name(String(picked))


func _apply_ambient_idle_flip_for_animation_name(anim_name_str: String) -> void:
	if anim == null:
		return
	if "side" in anim_name_str:
		var look_x := velocity.x if velocity.length() > 5.0 else _ambient_motion_ref.x
		if absf(look_x) > 0.1:
			anim.flip_h = (look_x > 0.0)


## 變體 idle（loop=false）播完會 emit；回到該方向基礎 idle（idle_down 等，loop=true），避免卡在最後一幀太久。
func _on_ambient_idle_animation_finished() -> void:
	if Engine.is_editor_hint():
		return
	if not _is_ambient_baby_bird():
		return
	if _amb_state != AmbState.PERCH:
		return
	if anim == null or anim.sprite_frames == null:
		return
	var cur := String(anim.animation)
	if cur.is_empty():
		return
	var d := get_dir_string()
	var base_name := "idle_" + d
	if cur == base_name:
		return
	if not cur.begins_with(base_name + "_"):
		return
	if not anim.sprite_frames.has_animation(StringName(base_name)):
		return
	_safe_animated_play(anim, StringName(base_name))
	_apply_ambient_idle_flip_for_animation_name(base_name)


func _ready() -> void:
	if not Engine.is_editor_hint() and data == null:
		var dres := load(BIRD_MONSTER_DATA)
		if dres is MonsterResource:
			data = dres
	if not Engine.is_editor_hint() and ProgressionManager != null and ProgressionManager.is_lake_ambient_baby_bird_slot_cleared(lake_ambient_save_slot):
		queue_free()
		return
	super._ready()
	if Engine.is_editor_hint():
		return
	_align_shadow_with_pet_baby()
	_deactivate_combat_hurtbox_and_groups()
	_configure_ambient_physics_no_stick_with_player()
	if health_bar:
		health_bar.visible = false
	if not _is_ambient_baby_bird():
		push_warning("AmbientBabyBirdMonster：data 非湖畔寶寶（請指定 baby_bird_monster.tres）；已關閉受擊框，環境 AI 未啟用。")
		return
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	add_to_group("ambient_lake_baby_bird")
	_rng.randomize()
	target_player = get_tree().get_first_node_in_group("player") as PlayerController
	_perch_anchor = global_position
	_wander_target = _perch_anchor
	_wander_timer = _rng.randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	_idle_variant_timer = _rng.randf_range(IDLE_SHUFFLE_MIN, IDLE_SHUFFLE_MAX)
	if anim != null:
		_bb_anim_base_pos = anim.position
		if not anim.animation_finished.is_connected(_on_ambient_idle_animation_finished):
			anim.animation_finished.connect(_on_ambient_idle_animation_finished)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		super._physics_process(delta)
		return
	if is_dead:
		super._physics_process(delta)
		return
	if not _is_ambient_baby_bird():
		super._physics_process(delta)
		return

	_consume_pending_knockback_push()
	_player = get_tree().get_first_node_in_group("player") as PlayerController

	match _amb_state:
		AmbState.PERCH:
			_process_perch(delta)
		AmbState.FLEE:
			_process_flee(delta)
		AmbState.OFFSCREEN:
			_process_offscreen(delta)

	move_and_slide()
	if health_bar:
		health_bar.visible = false
	_apply_ambient_flight_visual()
	_update_accessory_anchor()
	_update_headwear_visual()


func _process_perch(delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist < FLEE_PANIC_RADIUS:
			_flee_grace_timer = 0.0
			_start_flee()
			return
		if dist < FLEE_TRIGGER_RADIUS:
			_flee_grace_timer += delta
			if _flee_grace_timer >= FLEE_GRACE_SEC:
				_flee_grace_timer = 0.0
				_start_flee()
				return
		else:
			_flee_grace_timer = 0.0

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = _rng.randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
		var o := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(10.0, WANDER_RADIUS)
		_wander_target = _perch_anchor + o

	var to_w := _wander_target - global_position
	var moving := to_w.length() > 7.0
	if moving:
		velocity = to_w.normalized() * WANDER_SPEED
		if velocity.length() > 8.0:
			_ambient_motion_ref = velocity
		_was_wandering_moving = true
		_idle_variant_timer = _rng.randf_range(IDLE_SHUFFLE_MIN, IDLE_SHUFFLE_MAX)
		play_monster_animation("run")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, delta * 200.0)
		if _was_wandering_moving:
			_was_wandering_moving = false
			_idle_variant_timer = 0.0
		_idle_variant_timer -= delta
		if _idle_variant_timer <= 0.0:
			_idle_variant_timer = _rng.randf_range(IDLE_SHUFFLE_MIN, IDLE_SHUFFLE_MAX)
			_play_ambient_idle_variant()


func _start_flee() -> void:
	_amb_state = AmbState.FLEE
	_flee_speed_current = FLEE_SPEED_START
	if _player == null:
		_flee_dir = Vector2.RIGHT
	else:
		_flee_dir = global_position - _player.global_position
		if _flee_dir.length_squared() < 0.01:
			_flee_dir = Vector2.RIGHT
		else:
			_flee_dir = _flee_dir.normalized()
		if _flee_dir.length() > 0.5:
			_ambient_motion_ref = _flee_dir
	velocity = _flee_dir * _flee_speed_current
	play_monster_animation("run")


func _process_flee(delta: float) -> void:
	_update_ambient_flee_flight(delta)
	_flee_speed_current = move_toward(_flee_speed_current, FLEE_SPEED_MAX, FLEE_SPEED_RAMP * delta)
	velocity = _flee_dir * _flee_speed_current
	if _flee_dir.length() > 0.5:
		_ambient_motion_ref = _flee_dir
	play_monster_animation("run")
	if _is_outside_camera_view():
		_amb_state = AmbState.OFFSCREEN
		_offscreen_timer = OFFSCREEN_RESPAWN_SEC
		velocity = Vector2.ZERO
		visible = false
		_ambient_flight_y = 0.0
		if anim:
			anim.position = _bb_anim_base_pos


func _process_offscreen(delta: float) -> void:
	_offscreen_timer -= delta
	if _offscreen_timer > 0.0:
		return
	var new_g := _pick_random_perch_global(_perch_anchor)
	global_position = new_g
	_perch_anchor = new_g
	_wander_target = new_g
	visible = true
	_amb_state = AmbState.PERCH
	_flee_grace_timer = 0.0
	velocity = Vector2.ZERO
	_wander_timer = _rng.randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	_idle_variant_timer = 0.0
	_was_wandering_moving = false
	play_monster_animation("idle")


func _pick_random_perch_global(exclude_near: Vector2) -> Vector2:
	var pts: Array[Vector2] = []
	for n in get_tree().get_nodes_in_group(GROUP_PERCH):
		if n is Node2D:
			pts.append((n as Node2D).global_position)
	if pts.is_empty():
		return global_position
	for __i in 24:
		var c: Vector2 = pts[_rng.randi() % pts.size()]
		if c.distance_to(exclude_near) > 40.0:
			return c
	return pts[_rng.randi() % pts.size()]


func _get_camera_world_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(global_position - Vector2(400, 300), Vector2(800, 600))
	var half: Vector2 = get_viewport().get_visible_rect().size / cam.zoom / 2.0
	var c: Vector2 = cam.get_screen_center_position()
	return Rect2(c - half, half * 2.0)


func _is_outside_camera_view() -> bool:
	return not _get_camera_world_rect().has_point(global_position)
