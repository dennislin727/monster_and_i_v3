# res://src腳本/entities/PlayerController.gd
@tool
class_name PlayerController
extends CharacterBody2D

const DEFAULT_HEAD_ANCHOR_OFFSET := Vector2.ZERO

@export_group("頭飾錨點")
@export var head_anchor_offset: Vector2 = DEFAULT_HEAD_ANCHOR_OFFSET
## 拖入 `HeadwearResource`（.tres）可在編輯器預覽；遊戲內裝備仍以背包為準，此欄可留空。
@export var equipped_headwear: HeadwearResource
@export_group("頭飾位置 (免鉛筆直覺版)")
@export var anim_offsets: Array[AnimAnchorEntry] = []
@export var frame_offsets: Array[FrameAnchorEntry] = []
@export var debug_head_anchor_trace: bool = false
@export_group("除錯")
## 開啟後於輸出面板列印 InteractionDetector 進出 hurtbox／可互動物，供查近身目標丟失（不改攻擊判定）。
@export var debug_interaction_detector_trace: bool = false
@export var add_anim_offset_row: bool = false:
	set(value):
		add_anim_offset_row = value
		if not value:
			return
		anim_offsets.append(AnimAnchorEntry.new())
		add_anim_offset_row = false
@export var add_frame_offset_row: bool = false:
	set(value):
		add_frame_offset_row = value
		if not value:
			return
		frame_offsets.append(FrameAnchorEntry.new())
		add_frame_offset_row = false

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: Node = $StateMachine
@onready var health: HealthComponent = $HealthComponent
# 🟢 修正：把相機抓出來
@onready var camera: Camera2D = $Camera2D 
@onready var accessory_point: Marker2D = get_node_or_null("AccessoryPoint")
@onready var accessory_sprite: AnimatedSprite2D = get_node_or_null("AccessorySprite")

var last_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var is_hit_stun: bool = false
var is_invincible: bool = false
var is_seal_mode: bool = false
var is_perma_invincible: bool = false
var dialogue_movement_locked: bool = false
var harvest_movement_locked: bool = false
var _last_collect_happy_ms: int = 0
var _last_anchor_signature: String = ""
var _last_headwear_signature: String = ""
var _last_head_anchor_trace_signature: String = ""
var _head_anchor_rows_dumped: bool = false

var current_target: InteractableComponent = null
var current_enemy: HurtboxComponent = null

## 下一幀 _physics_process 開頭以 move_and_collide 分段消耗（避免 Tween 改 global_position 穿牆卡死）
var _pending_knockback_px: float = 0.0
var _pending_knockback_dir: Vector2 = Vector2.ZERO
const KNOCKBACK_SLIDE_STEP_PX := 12.0
## 與舊版 Tween 一致；空曠時約滑過 `PLAYER_DASH_DIST`，撞牆則提前結束。
const DASH_DURATION_SEC := 0.3
## 與 `get_dir_string()` 相同門檻：判斷「純上下／純左右」與斜向。
const DIR_DOMINANCE_RATIO := 1.5

var _dash_time_left: float = 0.0
var _dash_slide_dir: Vector2 = Vector2.DOWN

func _ready() -> void:
	if debug_head_anchor_trace:
		_debug_dump_head_anchor_rows("ready")
	if Engine.is_editor_hint():
		_update_accessory_anchor(true)
		_update_headwear_visual(true)
		return
	add_to_group("player")
	# 初始化狀態機
	for state in state_machine.get_children():
		state.player = self

	if health and not health.died.is_connected(_on_health_empty):
		health.died.connect(_on_health_empty)
	SignalBus.player_health_changed.emit(health.current_hp, health.max_hp)
		
	SignalBus.seal_mode_toggled.connect(func(e): is_seal_mode = e)
	if SignalBus.has_signal("dialogue_blocking_changed"):
		SignalBus.dialogue_blocking_changed.connect(func(blocked: bool) -> void:
			dialogue_movement_locked = blocked
		)
	if SignalBus.has_signal("harvest_mode_changed"):
		SignalBus.harvest_mode_changed.connect(func(active: bool) -> void:
			harvest_movement_locked = active
		)
	if SignalBus.has_signal("item_collected"):
		SignalBus.item_collected.connect(_on_item_collected_happy_feedback)
	if SignalBus.has_signal("dash_requested"):
		SignalBus.dash_requested.connect(perform_dash)
	if not SignalBus.party_damaged_by_monster.is_connected(_on_party_damaged_by_monster):
		SignalBus.party_damaged_by_monster.connect(_on_party_damaged_by_monster)
	_update_accessory_anchor(true)
	_update_headwear_visual(true)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		# 編輯器調參時，Dictionary 值改變不會改動畫簽名，需強制刷新才能即時預覽。
		_update_accessory_anchor(true)
		_update_headwear_visual()
		return
	# 頭飾錨點/視覺必須每幀跟著動畫刷新，不能被 hit_stun / dash 提前 return 擋住。
	_update_accessory_anchor()
	_update_headwear_visual()
	_consume_pending_knockback_push()
	if dialogue_movement_locked or harvest_movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if is_hit_stun:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if is_dashing:
		_process_dash_slide(_delta)
		move_and_slide()
		return
	
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()
		velocity = input_dir * GlobalBalance.PLAYER_SPEED 
	else:
		velocity = velocity.move_toward(Vector2.ZERO, GlobalBalance.PLAYER_FRICTION)
	
	move_and_slide()


func request_knockback_push(direction: Vector2, distance: float) -> void:
	if Engine.is_editor_hint():
		return
	var d := direction.normalized()
	if d.length_squared() < 0.0001 or distance <= 0.001:
		return
	_pending_knockback_dir = d
	_pending_knockback_px = distance


func _process_dash_slide(delta: float) -> void:
	velocity = Vector2.ZERO
	_dash_time_left -= delta
	var speed: float = GlobalBalance.PLAYER_DASH_DIST / DASH_DURATION_SEC
	var budget: float = speed * delta
	while budget > 0.001:
		var seg: float = minf(budget, KNOCKBACK_SLIDE_STEP_PX)
		var hit: KinematicCollision2D = move_and_collide(_dash_slide_dir * seg)
		budget -= seg
		if hit:
			_dash_time_left = 0.0
			break
	if _dash_time_left <= 0.0:
		is_dashing = false
		is_invincible = false
		_dash_time_left = 0.0


func _consume_pending_knockback_push() -> void:
	if _pending_knockback_px <= 0.001:
		return
	var d := _pending_knockback_dir
	var left := _pending_knockback_px
	while left > 0.001:
		var seg: float = minf(KNOCKBACK_SLIDE_STEP_PX, left)
		var hit: KinematicCollision2D = move_and_collide(d * seg)
		left -= seg
		if hit:
			break
	_pending_knockback_px = 0.0
	_pending_knockback_dir = Vector2.ZERO


func _on_health_empty() -> void:
	is_perma_invincible = true


func _on_party_damaged_by_monster(attacker_hurtbox: HurtboxComponent) -> void:
	if attacker_hurtbox == null or not is_instance_valid(attacker_hurtbox):
		return
	var m := attacker_hurtbox.get_parent()
	if m == null or not m.has_method("is_targetable") or not m.is_targetable():
		return
	current_enemy = attacker_hurtbox


# 🔴 受擊入口
func take_damage(amount: int):
	if is_perma_invincible:
		return
	if is_invincible or is_dashing:
		return
	if amount > 0 and health.current_hp <= 0:
		return
	
	is_hit_stun = true
	is_invincible = true
	
	if amount > 0:
		health.take_damage(amount)
		SignalBus.damage_spawned.emit(global_position, amount, true)
	
	if state_machine and state_machine.has_method("change_state"):
		state_machine.change_state(state_machine.get_node("Hurt"), true)
	
	var t = create_tween().set_loops(2)
	t.tween_property(anim_sprite, "modulate:a", 0.1, 0.05)
	t.tween_property(anim_sprite, "modulate:a", 1.0, 0.05)
	
	await get_tree().create_timer(0.4).timeout
	is_hit_stun = false
	await get_tree().create_timer(0.6).timeout
	is_invincible = false

func update_flip() -> void:
	if last_direction.x != 0:
		anim_sprite.flip_h = (last_direction.x > 0)


## 與 MonsterBase 一致：避免空名／零幀／缺動畫時 C++ `set_animation` 洗版。
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


func update_animation_by_dir(prefix: String) -> void:
	update_flip()
	var anim_name := resolve_directional_animation_name(prefix)
	if anim_name.is_empty():
		return
	if anim_sprite.animation != anim_name:
		_safe_animated_play(anim_sprite, anim_name)


## 依面向取得動畫後綴：斜向為 `side_down`／`side_up`，否則同 `get_dir_string()` 三向。
func direction_suffix_including_diagonals(direction: Vector2 = Vector2.ZERO) -> String:
	var d := direction
	if d.length_squared() < 0.0001:
		d = last_direction
	if d.length_squared() < 0.0001:
		d = Vector2.DOWN
	d = d.normalized()
	var ax := absf(d.x)
	var ay := absf(d.y)
	if ay > ax * DIR_DOMINANCE_RATIO:
		return "down" if d.y > 0.0 else "up"
	if ax > ay * DIR_DOMINANCE_RATIO:
		return "side"
	return "side_down" if d.y > 0.0 else "side_up"


## 解析 `prefix` + 後綴動畫：優先斜向 → 四向（down/up/side）→ 去掉底線後的裸名（如 `run_` → `run`）。
func resolve_directional_animation_name(prefix: String, direction: Vector2 = Vector2.ZERO) -> StringName:
	var frames := anim_sprite.sprite_frames if anim_sprite else null
	if frames == null:
		return &""
	var rich := direction_suffix_including_diagonals(direction)
	var candidates: Array[String] = []
	candidates.append(prefix + rich)
	for s in ["down", "up", "side"]:
		var full: String = prefix + s
		if not full in candidates:
			candidates.append(full)
	var bare: String = prefix.trim_suffix("_")
	if bare != prefix and not bare in candidates:
		candidates.append(bare)
	for c in candidates:
		if frames.has_animation(StringName(c)) and frames.get_frame_count(StringName(c)) > 0:
			return StringName(c)
	return &""


func apply_dash_body_animation() -> void:
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	var d := resolve_directional_animation_name("dash_", last_direction)
	if not anim_sprite.sprite_frames.has_animation(d):
		return
	update_flip()
	if anim_sprite.animation != d:
		_safe_animated_play(anim_sprite, d)


func get_dir_string() -> String:
	if abs(last_direction.y) > abs(last_direction.x) * DIR_DOMINANCE_RATIO:
		return "down" if last_direction.y > 0 else "up"
	return "side"

func resolve_head_anchor_offset(
	animation_name: StringName,
	frame_index: int,
	fallback_offset: Vector2 = DEFAULT_HEAD_ANCHOR_OFFSET
) -> Vector2:
	var fi := int(frame_index)
	var candidate_keys := HeadAnchorResolver.candidate_animation_keys(animation_name)
	_trace_head_anchor_rows_once()
	var used_source := "fallback"
	var used_entry_anim := ""
	var used_entry_frame := -99999
	var resolved_offset := Vector2.ZERO
	var tab := HeadAnchorResolver.resolve_frame_and_anim_tables(
		frame_offsets,
		anim_offsets,
		animation_name,
		frame_index
	)
	if tab.get(HeadAnchorResolver.KEY_OK, false):
		used_source = str(tab.get(HeadAnchorResolver.KEY_SOURCE, ""))
		used_entry_anim = str(tab.get(HeadAnchorResolver.KEY_ENTRY_ANIM, ""))
		used_entry_frame = int(tab.get(HeadAnchorResolver.KEY_ENTRY_FRAME, -99999))
		resolved_offset = tab.get(HeadAnchorResolver.KEY_OFFSET, Vector2.ZERO)
		_trace_head_anchor_resolution(animation_name, fi, used_source, used_entry_anim, used_entry_frame, resolved_offset, candidate_keys)
		return resolved_offset
	resolved_offset = head_anchor_offset if head_anchor_offset != DEFAULT_HEAD_ANCHOR_OFFSET else fallback_offset
	_trace_head_anchor_resolution(animation_name, fi, used_source, used_entry_anim, used_entry_frame, resolved_offset, candidate_keys)
	return resolved_offset

func _trace_head_anchor_resolution(
	animation_name: StringName,
	frame_index: int,
	source: String,
	entry_anim: String,
	entry_frame: int,
	resolved_offset: Vector2,
	candidate_keys: Array[String]
) -> void:
	if not debug_head_anchor_trace:
		return
	var trace_sig := "%s|%d|%s|%s|%d|%s" % [
		String(animation_name),
		frame_index,
		source,
		entry_anim,
		entry_frame,
		str(resolved_offset)
	]
	if trace_sig == _last_head_anchor_trace_signature:
		return
	_last_head_anchor_trace_signature = trace_sig
	print("[HeadAnchorTrace] anim=%s frame=%d keys=%s source=%s entry=(%s,%d) offset=%s" % [
		String(animation_name),
		frame_index,
		str(candidate_keys),
		source,
		entry_anim,
		entry_frame,
		str(resolved_offset)
	])

func _trace_head_anchor_rows_once() -> void:
	if not debug_head_anchor_trace or _head_anchor_rows_dumped:
		return
	_debug_dump_head_anchor_rows("resolve")

func _debug_dump_head_anchor_rows(stage: String) -> void:
	if _head_anchor_rows_dumped:
		return
	_head_anchor_rows_dumped = true
	print("[HeadAnchorTrace] stage=%s script=%s frame_offsets_count=%d anim_offsets_count=%d" % [
		stage,
		get_script().resource_path,
		frame_offsets.size(),
		anim_offsets.size()
	])
	for i in range(frame_offsets.size()):
		var e: FrameAnchorEntry = frame_offsets[i]
		if e == null:
			print("[HeadAnchorTrace] frame_offsets[%d]=<null>" % i)
			continue
		print("[HeadAnchorTrace] frame_offsets[%d] raw_anim=%s (%s) raw_frame=%s (%s) raw_offset=%s (%s)" % [
			i,
			str(e.anim_name),
			type_string(typeof(e.anim_name)),
			str(e.frame),
			type_string(typeof(e.frame)),
			str(e.offset),
			type_string(typeof(e.offset))
		])

func get_resolved_head_anchor_offset(global_fallback: Vector2 = DEFAULT_HEAD_ANCHOR_OFFSET) -> Vector2:
	if not anim_sprite:
		return global_fallback
	return resolve_head_anchor_offset(anim_sprite.animation, int(anim_sprite.frame), global_fallback)

func _update_accessory_anchor(force: bool = false) -> void:
	if accessory_point == null or anim_sprite == null:
		return
	var signature := "%s|%d|%s" % [String(anim_sprite.animation), anim_sprite.frame, str(anim_sprite.flip_h)]
	if not force and signature == _last_anchor_signature:
		return
	_last_anchor_signature = signature
	var resolved := get_resolved_head_anchor_offset(accessory_point.position)
	if anim_sprite.flip_h:
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


func _resolve_headwear_frames() -> SpriteFrames:
	if equipped_headwear:
		return equipped_headwear.sprite_frames
	return null

func _update_headwear_visual(force: bool = false) -> void:
	if accessory_sprite == null or anim_sprite == null:
		return
	var frames := _resolve_headwear_frames()
	if frames == null:
		accessory_sprite.hide()
		accessory_sprite.sprite_frames = null
		_last_headwear_signature = ""
		return
	accessory_sprite.show()
	if accessory_sprite.sprite_frames != frames:
		accessory_sprite.sprite_frames = frames
	var target_anim := _pick_headwear_anim_with_frames(frames, anim_sprite.animation)
	if target_anim.is_empty():
		accessory_sprite.hide()
		return
	var signature := "%s|%s|%s" % [String(anim_sprite.animation), String(target_anim), str(anim_sprite.flip_h)]
	if force or signature != _last_headwear_signature:
		_last_headwear_signature = signature
		if accessory_sprite.animation != target_anim or not accessory_sprite.is_playing():
			if not _safe_animated_play(accessory_sprite, target_anim):
				accessory_sprite.hide()
				return
	accessory_sprite.flip_h = anim_sprite.flip_h

## override：揮刀當下快照的 Hurtbox（結算在 ~0.15s 後，期間若離開偵測區 current_enemy 可能已清空）
func hit_current_target(melee_hurtbox_override: HurtboxComponent = null) -> void:
	var melee_hurtbox: HurtboxComponent = melee_hurtbox_override
	if melee_hurtbox == null or not is_instance_valid(melee_hurtbox):
		melee_hurtbox = current_enemy
	if melee_hurtbox and is_instance_valid(melee_hurtbox):
		var m = melee_hurtbox.get_parent()
		if m != null and m.has_method("is_targetable") and not m.is_targetable():
			pass
		else:
			melee_hurtbox.take_damage(GlobalBalance.PLAYER_BASE_DAMAGE)
	elif current_target:
		current_target.start_harvest()
		melee_hurtbox = null
	if SignalBus.has_signal("player_melee_hit"):
		SignalBus.player_melee_hit.emit(melee_hurtbox)

func _on_item_collected_happy_feedback(_item: Resource) -> void:
	if Engine.is_editor_hint():
		return
	var now := Time.get_ticks_msec()
	if now - _last_collect_happy_ms < GlobalBalance.PLAYER_COLLECT_HAPPY_COOLDOWN_MS:
		return
	_last_collect_happy_ms = now
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	if anim_sprite.animation in [&"happy", &"sad"] and anim_sprite.is_playing():
		return
	_safe_animated_play(anim_sprite, &"happy")


## 對話選項專用 happy（採集／採收仍走 `item_collected` 路徑）。`with_camera_punch` 僅在資料明確要「大演出」時傳 true（如對話發道具＋instant 提示）
func play_dialogue_reward_happy(with_camera_punch: bool = false) -> void:
	if Engine.is_editor_hint():
		return
	if with_camera_punch and camera:
		_camera_impact_zoom()
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	_safe_animated_play(anim_sprite, &"happy")


func perform_dash():
	if harvest_movement_locked or dialogue_movement_locked:
		return
	if is_dashing or is_hit_stun: return
	var dir := last_direction
	if dir.length_squared() < 0.0001:
		dir = Vector2.DOWN
	_dash_slide_dir = dir.normalized()
	_dash_time_left = DASH_DURATION_SEC
	is_dashing = true
	is_invincible = true
	apply_dash_body_animation()

func _on_interaction_detector_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var owner_m = area.get_parent()
		if owner_m != null and owner_m.has_method("is_targetable") and not owner_m.is_targetable():
			return
		current_enemy = area
		_debug_trace_interaction_detector("entered", area)
	elif area is InteractableComponent:
		current_target = area
		_debug_trace_interaction_detector("entered", area)

func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if area == current_enemy:
		_debug_trace_interaction_detector("exited_clear_enemy", area)
		current_enemy = null
	elif area == current_target:
		_debug_trace_interaction_detector("exited_clear_target", area)
		current_target = null

func _debug_trace_interaction_detector(event: String, area: Area2D) -> void:
	if not debug_interaction_detector_trace or area == null:
		return
	var dist := global_position.distance_to(area.global_position)
	var kind := "area"
	var owner_name := "?"
	if area is HurtboxComponent:
		kind = "hurtbox"
		var p: Node = area.get_parent()
		if p:
			owner_name = p.name
	elif area is InteractableComponent:
		kind = "interactable"
		var p2: Node = area.get_parent()
		if p2:
			owner_name = p2.name
	print(
		"[InteractionDetector] %s %s node=%s owner=%s dist=%.1f"
		% [event, kind, area.name, owner_name, dist]
	)

# 🎨 結算動畫演出 (加上相機縮放)
func play_finish_animation(is_success: bool):
	is_seal_mode = false 
	var text_msg = "Gotcha!!" if is_success else "Fail..."
	
	# 🟢 成功時觸發相機縮放
	if is_success:
		_camera_impact_zoom()
	
	SignalBus.popup_text.emit(self, text_msg, Color.WHITE) 
	
	var anim_name = "happy" if is_success else "sad"
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		if not _safe_animated_play(anim_sprite, StringName(anim_name)):
			update_animation_by_dir("idle_")
	else:
		update_animation_by_dir("idle_")
	velocity = Vector2.ZERO
	
	print("[Player] 執行結算動畫: ", anim_name)
	
	# 等待動畫撥完
	await get_tree().create_timer(1.2).timeout
	
	if anim_sprite.animation == anim_name:
		update_animation_by_dir("idle_")

# 🟢 內部私有函數：優雅的相機拉近演出
func _camera_impact_zoom():
	# 基礎 Zoom 是 1.4，我們拉到約 1.6
	var base_zoom = camera.zoom
	var target_zoom = base_zoom * 1.1
	
	var t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 1. 快速拉近 (0.2s)
	t.tween_property(camera, "zoom", target_zoom, 0.1)
	# 2. 停一秒讓冠冠的動畫被看清楚
	t.tween_interval(0.2)
	# 3. 慢慢恢復 (0.6s)
	t.chain().tween_property(camera, "zoom", base_zoom, 0.2)
