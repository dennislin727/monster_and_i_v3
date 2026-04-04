# res://src腳本/entities/monsters/MonsterBase.gd
@tool
class_name MonsterBase
extends CharacterBody2D

## 頭飾錨點與動畫級偏移在 **Data（MonsterResource）** 裡，不在本節點上。
## 檢視器：點 **Data** 列左側 **▸** 展開子欄位；或檔案系統雙擊該 `.tres`（例：`slime_green.tres`）單獨編輯。
@export var data: MonsterResource:
	set(value):
		data = value
		# 匯出欄位可能在子節點／@onready 就緒前寫入；立刻 update 會找不到 AnimatedSprite2D。
		call_deferred("update_visuals")
@export var equipped_headwear: HeadwearResource

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var state_machine: MonsterStateMachine = $StateMachine
@onready var health_bar: ProgressBar = get_node_or_null("UIAnchor/HealthBar")
@onready var accessory_point: Marker2D = get_node_or_null("AccessoryPoint")
@onready var accessory_sprite: AnimatedSprite2D = get_node_or_null("AccessorySprite")

var target_player: PlayerController = null
var skill_cds: Dictionary = {}
var wander_dir: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var last_dir_str: String = "down"
var is_dead: bool = false
var attack_cd_timer: float = 0.0
# 🔴 新增：霸體護盾開關
var is_casting_protected: bool = false 
var _last_anchor_signature: String = ""
var _last_headwear_signature: String = ""
## 降低斜向移動時 run_side / run_up 邊界抖動造成的「跳幀」感。
var _dir_smooth_ref: Vector2 = Vector2.ZERO
## 受擊擊退：勿 Tween global_position（易穿 StaticBody）；與 PlayerController 同用分段 move_and_collide。
var _pending_knockback_px: float = 0.0
var _pending_knockback_dir: Vector2 = Vector2.ZERO
const _KNOCKBACK_SLIDE_STEP_PX := 12.0
## 關卡內 `Marker2D`（或任何 `Node2D`）加入此群組後，`perform_ghost_dash` 會在「背離主角扇形」內優先挑朝向標記、且不穿牆的終點（適合高地／埋伏點）。
const MONSTER_AMBUSH_POINT_GROUP := "monster_ambush_point"

func _ready() -> void:
	update_visuals()
	if Engine.is_editor_hint():
		# 與 PlayerController 一致：編輯器內保證首幀錨點／頭飾就緒（data 已套用 sprite）
		_update_accessory_anchor(true)
		_update_headwear_visual(true)
		return
	add_to_group("sealable_entity")
	if data == null or data.participates_in_combat:
		add_to_group("monsters")
	if data and health:
		health.max_hp = data.max_hp
		health.current_hp = data.max_hp
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)
		if health_bar: health_bar.setup(health)
	if state_machine and data:
		state_machine.init(self)
	_update_headwear_visual(true)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		# 調整 MonsterResource 的 frame_offsets／anim_offsets 等不會改動畫簽名，需每幀強制刷新錨點才能即時預覽
		_update_accessory_anchor(true)
		_update_headwear_visual()
		return
	if is_dead:
		_update_accessory_anchor()
		_update_headwear_visual()
		return
	_consume_pending_knockback_push()
	for s in skill_cds.keys(): if skill_cds[s] > 0: skill_cds[s] -= delta
	if attack_cd_timer > 0: attack_cd_timer -= delta
	
	move_and_slide()

	if health_bar:
		var should_show = target_player != null or health.current_hp < health.max_hp
		health_bar.modulate.a = move_toward(health_bar.modulate.a, 1.0 if should_show else 0.0, delta * 2.0)
	_update_accessory_anchor()
	_update_headwear_visual()

# 根據當前狀態決定轉向邏輯
func play_monster_animation(anim_name: String):
	if anim_name.is_empty():
		return
	if not anim or not anim.sprite_frames:
		return
	var dir = get_dir_string()
	var target = anim_name
	
	if anim.sprite_frames.has_animation(anim_name + "_" + dir):
		target = anim_name + "_" + dir
	elif anim.sprite_frames.has_animation(anim_name):
		target = anim_name
	
	if not anim.sprite_frames.has_animation(target):
		return
	if anim.animation != target:
		_safe_animated_play(anim, StringName(target))
		
	if "side" in target:
		var current_state_name = ""
		if state_machine and state_machine.current_state:
			current_state_name = state_machine.current_state.name
			
		var look_x = 0.0
		
		if current_state_name in ["Flee", "Wander"]:
			look_x = velocity.x
		elif current_state_name in ["Chase", "Attack", "Spell", "Hurt"]:
			if target_player:
				var to_player: Vector2 = target_player.global_position - global_position
				var use_vel_for_flip := false
				# 遠程拉開時位移背離主角，但舊邏輯用「朝向主角」翻轉 → 會與 run 方向相反；與 Flee 一致改看 velocity。
				if current_state_name == "Chase" and data and data.combat_style == MonsterResource.CombatStyle.RANGED_KITER:
					if to_player.length_squared() > 0.0001 and velocity.dot(to_player) < -2.0:
						use_vel_for_flip = true
				if use_vel_for_flip:
					look_x = velocity.x
				else:
					look_x = to_player.x
			else:
				look_x = velocity.x
		else:
			look_x = velocity.x if velocity.length() > 5 else (target_player.global_position.x - global_position.x if target_player else 0.0)
			
		if look_x != 0:
			anim.flip_h = (look_x > 0)

func get_dir_string() -> String:
	var ref := velocity
	if target_player and velocity.length() < 10:
		ref = target_player.global_position - global_position
	if ref.length() < 2:
		return last_dir_str
	_dir_smooth_ref = _dir_smooth_ref.lerp(ref, 0.26) if _dir_smooth_ref.length_squared() > 0.0001 else ref
	var sr := _dir_smooth_ref
	if absf(sr.y) > absf(sr.x) * 1.5:
		last_dir_str = "down" if sr.y > 0 else "up"
	else:
		last_dir_str = "side"
	return last_dir_str


## 追逐／飛撲方向：主角與所有出戰寵物中距離最近者（活著且可受擊）。
func get_nearest_hostile_target_global() -> Vector2:
	if not is_instance_valid(target_player):
		return global_position
	var best: Vector2 = target_player.global_position
	var best_d2: float = global_position.distance_squared_to(best)
	var tree := get_tree()
	if tree == null:
		return best
	for n in tree.get_nodes_in_group("deployed_pet"):
		if not n is Node2D:
			continue
		var n2 := n as Node2D
		if not is_instance_valid(n2):
			continue
		if not n2.has_method("take_damage_from_monster"):
			continue
		var hc: Node = n2.get_node_or_null("HealthComponent")
		if hc is HealthComponent:
			var hcomp := hc as HealthComponent
			if hcomp.current_hp <= 0:
				continue
		var d2 := global_position.distance_squared_to(n2.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n2.global_position
	return best


## 封印儀式中法陣作用中（`SealingComponent.start_struggle` 後至結束）；寵物勿續攻該怪。
func is_seal_magic_circle_active() -> bool:
	var sc: Node = get_node_or_null("SealingComponent")
	if sc == null:
		return false
	return sc.get("is_active") == true


func request_knockback_push(direction: Vector2, distance: float) -> void:
	if Engine.is_editor_hint():
		return
	var d := direction.normalized()
	if d.length_squared() < 0.0001 or distance <= 0.001:
		return
	_pending_knockback_dir = d
	_pending_knockback_px = distance


func _consume_pending_knockback_push() -> void:
	if _pending_knockback_px <= 0.001:
		return
	var d := _pending_knockback_dir
	var left := _pending_knockback_px
	while left > 0.001:
		var seg: float = minf(_KNOCKBACK_SLIDE_STEP_PX, left)
		var hit: KinematicCollision2D = move_and_collide(d * seg)
		left -= seg
		if hit:
			break
	_pending_knockback_px = 0.0
	_pending_knockback_dir = Vector2.ZERO


func play_hit_animation(_is_final: bool):
	if is_dead: return
	
	# 🔴 核心修復：施法護盾判定
	# 如果正在霸體狀態
	if is_casting_protected:
		var p = get_tree().get_first_node_in_group("player")
		if p is Node2D:
			var p2: Node2D = p
			# 1. 彈開：勿 Tween global_position（會穿牆）；改由主角分段 move_and_collide
			var bounce_dir: Vector2 = (p2.global_position - global_position).normalized()
			if p2.has_method("request_knockback_push"):
				p2.request_knockback_push(bounce_dir, 50.0)
			# 2. 觸發主角平常的受擊演繹 (傳入 0 傷害)
			p2.take_damage(0)
			
		return # 史萊姆不進入受傷狀態 

	target_player = get_tree().get_first_node_in_group("player")
	if state_machine == null or state_machine.current_state == null:
		play_monster_animation("hit")
		return
	if state_machine.current_state.name in ["Spell", "Die"]:
		return
	state_machine.change_to("Hurt")

func _on_died():
	if is_dead: return
	is_dead = true
	if health_bar:
		health_bar.hide()
	velocity = Vector2.ZERO
	if state_machine:
		state_machine.change_to("Die")

func get_available_skill() -> SkillResource:
	if not data: return null
	var hp_pct = float(health.current_hp) / health.max_hp
	for s in data.skills:
		if s and skill_cds.get(s, 0) <= 0 and hp_pct <= s.max_hp_pct: return s
	return null

func _body_sprite() -> AnimatedSprite2D:
	if is_instance_valid(anim):
		return anim
	if is_inside_tree():
		return get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	return null


## 僅在圖集內存在且至少一幀時才 play，避免 `set_animation`／空名稱洗版。
func _safe_animated_play(spr: AnimatedSprite2D, anim_name: StringName) -> bool:
	if spr == null:
		return false
	if anim_name.is_empty():
		return false
	var sf: SpriteFrames = spr.sprite_frames
	if sf == null:
		return false
	if not sf.has_animation(anim_name):
		return false
	if sf.get_frame_count(anim_name) <= 0:
		return false
	spr.play(anim_name)
	return true


func _play_body_idle_or_first_valid(spr: AnimatedSprite2D) -> void:
	if spr == null or spr.sprite_frames == null:
		return
	var sf: SpriteFrames = spr.sprite_frames
	const PREFERRED: Array[StringName] = [
		&"idle_down", &"idle_side", &"idle_up",
		&"idle_side_down", &"idle_side_up", &"idle",
	]
	for anim_name in PREFERRED:
		if _safe_animated_play(spr, anim_name):
			return
	for anim_name in sf.get_animation_names():
		if _safe_animated_play(spr, anim_name):
			return
	spr.stop()


func update_visuals():
	var spr := _body_sprite()
	if spr == null:
		return
	if data and data.sprite_frames:
		spr.sprite_frames = data.sprite_frames
	if spr.sprite_frames:
		_play_body_idle_or_first_valid(spr)
	_update_accessory_anchor(true)
	_update_headwear_visual(true)

func get_resolved_head_anchor_offset(global_fallback: Vector2 = Vector2(0, -40)) -> Vector2:
	if not data:
		return global_fallback
	var spr := _body_sprite()
	if spr == null:
		return global_fallback
	# 與 PlayerController 一致：錨點邏輯走靜態解析，只讀 data 的匯出欄位，避免編輯器內 Resource placeholder 無法呼叫實例方法。
	return HeadAnchorResolver.resolve_head_anchor_monster_exports(
		data.frame_offsets,
		data.anim_offsets,
		spr.animation,
		int(spr.frame),
		data.frame_anchor_overrides,
		data.animation_anchor_overrides,
		data.head_anchor_offset,
		data.accessory_offset,
		global_fallback,
		MonsterResource.DEFAULT_HEAD_ANCHOR_OFFSET
	)

func _update_accessory_anchor(force: bool = false) -> void:
	if accessory_point == null or anim == null:
		return
	var signature := "%s|%d|%s" % [String(anim.animation), anim.frame, str(anim.flip_h)]
	if not force and signature == _last_anchor_signature:
		return
	_last_anchor_signature = signature
	var resolved := get_resolved_head_anchor_offset(accessory_point.position)
	if anim.flip_h:
		resolved.x = -resolved.x
	accessory_point.position = resolved
	if accessory_sprite:
		accessory_sprite.position = accessory_point.position

func _resolve_headwear_idle_animation_name(body_animation: StringName) -> StringName:
	var body_name := String(body_animation).to_lower()
	if "up" in body_name:
		return &"idle_up"
	if "down" in body_name:
		return &"idle_down"
	return &"idle_side"


func _pick_headwear_anim_with_frames(frames: SpriteFrames, body_animation: StringName) -> StringName:
	var preferred := _resolve_headwear_idle_animation_name(body_animation)
	var candidates: Array[StringName] = [
		preferred, &"idle_side", &"idle_down", &"idle_up",
	]
	var tried: Dictionary = {}
	for c in candidates:
		if c in tried:
			continue
		tried[c] = true
		if frames.has_animation(c) and frames.get_frame_count(c) > 0:
			return c
	for n in frames.get_animation_names():
		if frames.get_frame_count(n) > 0:
			return n
	return StringName()


func _update_headwear_visual(force: bool = false) -> void:
	if accessory_sprite == null or anim == null:
		return
	var frames: SpriteFrames = equipped_headwear.sprite_frames if equipped_headwear else null
	if frames == null:
		accessory_sprite.hide()
		accessory_sprite.sprite_frames = null
		_last_headwear_signature = ""
		return
	accessory_sprite.show()
	if accessory_sprite.sprite_frames != frames:
		accessory_sprite.sprite_frames = frames
	var target_anim := _pick_headwear_anim_with_frames(frames, anim.animation)
	if target_anim.is_empty():
		accessory_sprite.hide()
		return
	var signature := "%s|%s|%s" % [String(anim.animation), String(target_anim), str(anim.flip_h)]
	if force or signature != _last_headwear_signature:
		_last_headwear_signature = signature
		if accessory_sprite.animation != target_anim or not accessory_sprite.is_playing():
			if not _safe_animated_play(accessory_sprite, target_anim):
				accessory_sprite.hide()
				return
	accessory_sprite.flip_h = anim.flip_h

func _slime_dash_simulate_end(start_g: Vector2, dir: Vector2, max_dist: float, step_px: float) -> Vector2:
	global_position = start_g
	velocity = Vector2.ZERO
	var d := dir.normalized()
	if d.length_squared() < 0.0001:
		return start_g
	var remaining := max_dist
	while remaining > 0.001:
		var seg: float = minf(step_px, remaining)
		var hit := move_and_collide(d * seg)
		if hit:
			break
		remaining -= seg
	return global_position


func _ambush_preferred_dir_from_markers(start_g: Vector2, base_away: Vector2) -> Vector2:
	var tree := get_tree()
	if tree == null:
		return Vector2.ZERO
	var best_dir := Vector2.ZERO
	var best_d2: float = INF
	for n in tree.get_nodes_in_group(MONSTER_AMBUSH_POINT_GROUP):
		if not n is Node2D:
			continue
		var p: Vector2 = (n as Node2D).global_position
		var to_m: Vector2 = p - start_g
		var l2: float = to_m.length_squared()
		if l2 < 16.0:
			continue
		var u: Vector2 = to_m.normalized()
		if u.dot(base_away) < 0.12:
			continue
		if l2 < best_d2:
			best_d2 = l2
			best_dir = u
	return best_dir


func perform_ghost_dash(dist: float):
	if is_dead:
		return
	if not is_instance_valid(target_player):
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(anim, "scale", Vector2(1.8, 0.1), 0.15)
	t.tween_property(anim, "modulate:a", 0.0, 0.15)
	await t.finished
	if is_dead or not is_instance_valid(target_player):
		return
	var start_g := global_position
	var player_g := target_player.global_position
	var base_away := start_g - player_g
	if base_away.length_squared() < 0.01:
		base_away = Vector2.RIGHT
	base_away = base_away.normalized()
	# 在「大致背對主角」的扇形內掃多個方向，選終點：與主角距離盡量遠、不穿牆；若關卡有 ambush 標記則加分偏向標記方向（高地／掩體）。
	const step_px := 14.0
	const dir_count := 13
	const arc_rad := deg_to_rad(130.0)
	const marker_align_weight := 8500.0
	var prefer := _ambush_preferred_dir_from_markers(start_g, base_away)
	var best_pos := start_g
	var best_score := -1.0
	for i in dir_count:
		var u := float(i) / float(maxi(dir_count - 1, 1))
		var dir := base_away.rotated(lerpf(-arc_rad * 0.5, arc_rad * 0.5, u))
		var end_g := _slime_dash_simulate_end(start_g, dir, dist, step_px)
		var d2 := end_g.distance_squared_to(player_g)
		var score: float = d2
		if prefer.length_squared() > 0.0001:
			score += marker_align_weight * maxf(0.0, dir.dot(prefer))
		if best_score < 0.0 or score > best_score:
			best_score = score
			best_pos = end_g
	global_position = best_pos
	velocity = Vector2.ZERO
	var t2 = create_tween().set_parallel(true)
	t2.tween_property(anim, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)
	t2.tween_property(anim, "modulate:a", 1.0, 0.1)
	await t2.finished

func is_targetable() -> bool:
	if is_dead or not is_instance_valid(self):
		return false
	# data 為 null 時視為一般可鎖定怪（編輯器／載入中）；非戰鬥怪務必在 Resource 設 participates_in_combat=false，或改用專用腳本覆寫（如 AmbientBabyBirdMonster）。
	if data != null and not data.participates_in_combat:
		return false
	return true
