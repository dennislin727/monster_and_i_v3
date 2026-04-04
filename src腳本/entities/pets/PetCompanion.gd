# res://src腳本/entities/pets/PetCompanion.gd
@tool
extends CharacterBody2D

const DEFAULT_HEAD_ANCHOR_OFFSET := Vector2.ZERO

var _data: PetResource
## 出戰三槽索引 0..2，由 Spawner 寫入
var party_slot_index: int = 0
@export var equipped_headwear: HeadwearResource
@export var head_anchor_offset: Vector2 = DEFAULT_HEAD_ANCHOR_OFFSET
@export_group("頭飾位置 (免鉛筆直覺版)")
@export var anim_offsets: Array[AnimAnchorEntry] = []
@export var frame_offsets: Array[FrameAnchorEntry] = []
@export_group("頭飾錨點（相容舊資料）")
@export var animation_anchor_overrides: Dictionary = {}
@export var frame_anchor_overrides: Dictionary = {}
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var health: HealthComponent = $HealthComponent
@onready var health_bar: ProgressBar = $UIAnchor/HealthBar
@onready var shadow_component: AnimatedSprite2D = get_node_or_null("ShadowComponent")
@onready var accessory_point: Marker2D = get_node_or_null("AccessoryPoint")
@onready var accessory_sprite: AnimatedSprite2D = get_node_or_null("AccessorySprite")
@onready var ui_anchor_node: Node = get_node_or_null("UIAnchor")

var _player: PlayerController
var _heal_cd: float = 2.0
var _celebrating: bool = false
var _last_dir: String = "down"
## 與跟隨錨點的距離（每幀更新，供移動與動畫共用，避免用 velocity 閾值造成 run/idle 跳針）
var _dist_to_follow_slot: float = 0.0
## 遲滯：只有距離明顯拉開才切 run，明顯貼近才切 idle（參考 old_pet 以距離分區，非攻擊邏輯）
var _visual_is_running: bool = false
## 麵包屑跟隨（策略 2）：記錄主角軌跡，寵物追「延遲恆」的點，減少抄近路穿過主角
var _trail_clock: float = 0.0
var _trail_times: Array[float] = []
var _trail_positions: Array[Vector2] = []
## 主角站定時：在周遭環形隨機落點，避免麵包屑塌縮到腳底
var _roam_offset: Vector2 = Vector2.ZERO
var _roam_pick_cooldown: float = 0.0
var _idle_roam_dirty: bool = true
var _hyst_player_moving: bool = false
## 主角站定累積；達門檻後閒逛才可撒到「面向」的前方（左前／右前）扇區
var _idle_calm_timer: float = 0.0
## 戰鬥黏著：主角拉打時，寵物仍可持續作戰直到脫戰條件成立
var _combat_target: HurtboxComponent = null
var _combat_sticky: float = 0.0
var _combat_attack_cd: float = 0.0
## 戰鬥用 AOE（如滾石）：非補血、非家園技之第一個 AOE_ATTACK
var _combat_aoe_skill: SkillResource = null
var _combat_skill_cd: float = 0.0
var _pet_aoe_delay_left: float = 0.0
var _pet_aoe_skill_pending: SkillResource = null

## 動畫鎖：attack / spell 播放時不被 run/idle 覆蓋
var _anim_lock: float = 0.0
var _anim_restore: String = ""
var _heal_casting: bool = false
var _spawn_celebrate_pending: bool = true
var _homestead_till_skill: SkillResource = null
var _homestead_till_cd: float = 0.0
var _last_headwear_signature: String = ""
var _last_anchor_signature: String = ""
var _anchor_profile: MonsterResource = null
## 卡牆時仍朝目標給速度但位移極小 → 改播 idle 緩解原地跑步
var _stuck_visual_timer: float = 0.0
var _visual_stuck_play_idle: bool = false
## 本幀「想要」的速度（lerp 前目標），供卡牆判定；勿用 velocity.length()（lerp 很慢時會過低）
var _motion_intent_vel: Vector2 = Vector2.ZERO
## 本幀追向的世界座標（跟隨錨點或戰鬥目標），供「朝目標是否有前進」判定
var _seek_point: Vector2 = Vector2.ZERO

const FOLLOW_LERP_WEIGHT := 0.1
const FOLLOW_ARRIVE_DISTANCE := 35.0
const VISUAL_RUN_ENTER_DIST := 42.0
const VISUAL_RUN_EXIT_DIST := 26.0
const BREADCRUMB_DELAY_SEC := 0.38
const BREADCRUMB_MAX_HISTORY_SEC := 3.0
const PLAYER_SPEED_MOVE_ENTER := 20.0
const PLAYER_SPEED_MOVE_EXIT := 8.0
## 主角站定時重選閒逛點（約 5 秒一次量級）
const ROAM_REPICK_MIN_SEC := 4.2
const ROAM_REPICK_MAX_SEC := 6.2
const IDLE_ROAM_NEAR_PLAYER := 14.0
## 站定多久後，隨機落點才可包含主角「面向」的前方（左前／右前）
const IDLE_FRONT_ALLOW_SEC := 1.15
## 目標相對主角的向量與面向點積大於此，視為在前半球（跟隨中禁止）
const FRONT_HEMI_DOT := 0.14
const FRONT_NUDGE_ALONG := 16.0

const PET_COMBAT_STICKY_SEC := 2.8
const PET_DISENGAGE_DIST := 260.0 # 主角離怪太遠則脫戰
const PET_ATTACK_RANGE := 54.0
const PET_AUTO_ATTACK_CD := 0.95
const PET_ATTACK_LOCK_SEC := 0.22
## 家園內與土格中心的翻土觸發距離
const PET_HOMESTEAD_TILL_RANGE := 58.0

const PET_HEAL_STARTUP_SEC := 0.0
const PET_HEAL_TRIGGER_FALLBACK := 0.25
const STUCK_STEP_EPS_PX := 2.0
## 對齊主角 MoveState run 閾值（約 10）略寬，但以「意圖速度」驅動故不可設太高
const STUCK_INTENT_VEL := 12.0
## 意圖夠大、位移卻幾乎沒往目標前進（貼牆掃給 speed 或沿牆滑但追不到錨點）
const STUCK_TOWARD_TARGET_MAX := 0.45
const STUCK_VISUAL_HOLD_SEC := 0.12
const STUCK_TIMER_DECAY := 4.0

## 僅 pet_id == baby_bird：低空飛行視覺（本體 Y 上移，影子維持地面）、降落 run_*_1、idle 變體隨機（距離／高度見 GlobalBalance.BABY_BIRD_FLIGHT_*）
const BABY_BIRD_LANDING_MIN_Y := 3.5
## 目標飛行高度仍明顯高於目前值時，視覺上播 run（飄升只靠 Y 偏移、水平距離常仍小）
const BABY_BIRD_FLIGHT_ASCEND_RUN_GAP := 2.8
## 降落剛結束後短暫不觸發「飄升 run」，避免翅膀已收卻再閃一幀 run_*（開翅變大很顯眼）
const BABY_BIRD_ASCENT_RUN_SUPPRESS_AFTER_LAND_SEC := 0.52
const BABY_BIRD_IDLE_CHATTER_MIN := 2.2
const BABY_BIRD_IDLE_CHATTER_MAX := 5.2

var _baby_bird_flight_y: float = 0.0
var _baby_bird_landing_active: bool = false
var _baby_bird_landing_time_left: float = 0.0
var _baby_bird_landing_total: float = 0.0
var _baby_bird_landing_start_y: float = 0.0
var _baby_bird_prev_player_moving: bool = true
var _baby_bird_idle_chatter: float = 5.0
var _bb_anim_base_pos: Vector2 = Vector2.ZERO
var _bb_name_label_base_pos: Vector2 = Vector2.ZERO
var _bb_ui_anchor_base_pos: Vector2 = Vector2.ZERO
## 寶寶鳥：平滑後的「與跟隨點距離」，供飛行高度用，減少麵包屑造成的上下抖動
var _bb_smooth_follow_dist: float = 50.0
var _bb_alt_wobble_phase: float = 0.0
var _bb_orbit_phase: float = 0.0
## 本幀是否因「仍在往上飄」而應播 run（供 _update_visual，與水平距離解耦）
var _bb_flight_wants_run_boost: bool = false
var _bb_ascent_run_suppress_left: float = 0.0
## 主角停步後：先長段下降（播 run），近地再播 run_*_1
var _bb_landing_descent_active: bool = false
## 主角起跑後：起飛高度意願漸強（秒）
var _bb_lazy_takeoff_timer: float = 0.0
var _bb_prev_hyst_moving_for_lazy: bool = false

func setup(pet_data: PetResource, slot_idx: int = 0) -> void:
	_data = pet_data
	party_slot_index = slot_idx
	_homestead_till_skill = _resolve_homestead_till_skill(pet_data)
	_combat_aoe_skill = _resolve_combat_aoe_skill(pet_data)
	_reset_breadcrumb_trail()


func get_pet_instance_id() -> String:
	if _data == null:
		return ""
	return _data.instance_id.strip_edges()


func get_party_slot_index() -> int:
	return party_slot_index


func get_headwear_binding_key() -> String:
	if _data == null:
		return ""
	var instance_id := _data.instance_id.strip_edges()
	if instance_id.is_empty():
		return ""
	return "pet:%s" % instance_id


func _party_slot_follow_mult() -> float:
	if GlobalBalance:
		match party_slot_index:
			0:
				return GlobalBalance.PET_PARTY_SLOT0_FOLLOW_MULT
			1:
				return GlobalBalance.PET_PARTY_SLOT1_FOLLOW_MULT
			2:
				return GlobalBalance.PET_PARTY_SLOT2_FOLLOW_MULT
	match party_slot_index:
		0:
			return 1.0
		1:
			return 0.68
		2:
			return 0.76
	return 1.0


func _party_slot_trail_lag_sec() -> float:
	if GlobalBalance:
		match party_slot_index:
			0:
				return GlobalBalance.PET_PARTY_SLOT0_TRAIL_LAG_SEC
			1:
				return GlobalBalance.PET_PARTY_SLOT1_TRAIL_LAG_SEC
			2:
				return GlobalBalance.PET_PARTY_SLOT2_TRAIL_LAG_SEC
	match party_slot_index:
		0:
			return 0.0
		1:
			return 0.55
		2:
			return 0.4
	return 0.0


func _hurtbox_on_monster_with_seal_active(hb: Variant) -> bool:
	if hb == null or not is_instance_valid(hb):
		return false
	if not hb is HurtboxComponent:
		return false
	var parent_node := (hb as Node).get_parent()
	if parent_node is MonsterBase:
		return (parent_node as MonsterBase).is_seal_magic_circle_active()
	return false


func _try_teleport_if_too_far_from_player() -> void:
	if _celebrating or health.current_hp <= 0:
		return
	if _player == null:
		return
	var lim: float = GlobalBalance.PET_TELEPORT_PULL_DIST if GlobalBalance else 420.0
	if global_position.distance_to(_player.global_position) < lim:
		return
	global_position = _player.global_position + _party_follow_anchor_offset()
	velocity = Vector2.ZERO
	_reset_breadcrumb_trail()


func _get_camera_world_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(global_position - Vector2(400, 300), Vector2(800, 600))
	var half: Vector2 = get_viewport().get_visible_rect().size / cam.zoom / 2.0
	var c: Vector2 = cam.get_screen_center_position()
	return Rect2(c - half, half * 2.0)


## 非戰鬥：超出「攝影機＋外擴」軟邊界時溫和加速拉回（外擴讓貼畫面邊時較不易抖）
func _apply_screen_edge_return(delta: float) -> void:
	if GlobalBalance and not GlobalBalance.PET_SCREEN_EDGE_RETURN_ENABLED:
		return
	if _celebrating or health.current_hp <= 0:
		return
	if _combat_active():
		return
	if _player == null:
		return
	var outset: float = GlobalBalance.PET_SCREEN_BOUNDARY_OUTSET_PX if GlobalBalance else 108.0
	var accel: float = GlobalBalance.PET_SCREEN_RETURN_ACCEL if GlobalBalance else 360.0
	var max_push: float = GlobalBalance.PET_SCREEN_RETURN_MAX_PUSH if GlobalBalance else 240.0
	var rect := _get_camera_world_rect()
	var allowed := rect.grow_individual(outset, outset, outset, outset)
	if allowed.has_point(global_position):
		return
	var cp := Vector2(
		clampf(global_position.x, allowed.position.x, allowed.end.x),
		clampf(global_position.y, allowed.position.y, allowed.end.y)
	)
	var to_in := cp - global_position
	var d := to_in.length()
	if d < 0.25:
		return
	var push_strength := accel * delta * (1.0 + d * 0.01)
	push_strength = minf(push_strength, max_push * delta)
	velocity += to_in.normalized() * push_strength


func _baby_bird_follow_anchor_extras(delta: float) -> Vector2:
	if not _is_baby_bird_pet() or _combat_active():
		return Vector2.ZERO
	var head_y := -28.0
	var rx := 22.0
	var ry := 14.0
	var osp := 0.88
	if GlobalBalance:
		head_y = GlobalBalance.BABY_BIRD_FOLLOW_HEAD_Y_OFFSET
		rx = GlobalBalance.BABY_BIRD_ORBIT_RX
		ry = GlobalBalance.BABY_BIRD_ORBIT_RY
		osp = GlobalBalance.BABY_BIRD_ORBIT_SPEED
	_bb_orbit_phase += delta * osp
	var head := Vector2(0.0, head_y)
	var orbit := Vector2(cos(_bb_orbit_phase) * rx, sin(_bb_orbit_phase) * ry)
	return head + orbit


func _update_stuck_visual_after_move(pos_before: Vector2, delta: float) -> void:
	if _celebrating or health.current_hp <= 0:
		_stuck_visual_timer = 0.0
		_visual_stuck_play_idle = false
		return
	var step := global_position.distance_to(pos_before)
	var chasing := false
	if _combat_active():
		chasing = _dist_to_follow_slot > PET_ATTACK_RANGE * 0.72
	else:
		chasing = _dist_to_follow_slot > FOLLOW_ARRIVE_DISTANCE + 6.0
	var intent := _motion_intent_vel.length()
	var intent_chasing := chasing and intent > STUCK_INTENT_VEL
	var toward_dot := 1.0
	# 與目標幾乎重合時不算夾角，維持 1.0（此時通常已不是 chasing）
	if pos_before.distance_squared_to(_seek_point) > 36.0:
		var to_seek := _seek_point - pos_before
		var sl := to_seek.length()
		if sl > 0.001:
			toward_dot = (global_position - pos_before).dot(to_seek / sl)
	## 貼牆「頂」直線向錨點：位移小且幾乎沒沿「朝目標方向」前進 → idle（只認 vel 會漏掉 lerp 低速）
	var jammed_against_wall := intent_chasing and step <= STUCK_STEP_EPS_PX and toward_dot < STUCK_TOWARD_TARGET_MAX
	if jammed_against_wall:
		_stuck_visual_timer += delta
	else:
		_stuck_visual_timer = maxf(0.0, _stuck_visual_timer - delta * STUCK_TIMER_DECAY)
	_visual_stuck_play_idle = _stuck_visual_timer >= STUCK_VISUAL_HOLD_SEC


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_headwear_visual(true)
		return
	add_to_group("deployed_pet")
	# 與怪物同層（受擊／互動語意一致），並偵測世界 StaticBody（地形）
	collision_layer = 2
	collision_mask = 1
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _data:
		_apply_pet_resource(_data)
	if shadow_component != null and GlobalBalance != null:
		if shadow_component.get("base_offset") != null:
			shadow_component.set("base_offset", GlobalBalance.PET_COMPANION_SHADOW_BASE_OFFSET)
		if shadow_component.get("shadow_scale") != null:
			shadow_component.set("shadow_scale", GlobalBalance.PET_COMPANION_SHADOW_SCALE)
	if health and not health.died.is_connected(_on_pet_died):
		health.died.connect(_on_pet_died)
	# 血量改由編隊槽按鈕下方的 HealthBar（與頭頂同款樣式）顯示，頭頂條隱藏。
	if health_bar:
		health_bar.visible = false
		health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not SignalBus.player_melee_hit.is_connected(_on_player_melee_hit):
		SignalBus.player_melee_hit.connect(_on_player_melee_hit)
	if not SignalBus.pet_captured.is_connected(_on_peer_pet_captured):
		SignalBus.pet_captured.connect(_on_peer_pet_captured)
	if not SignalBus.pet_nickname_changed.is_connected(_on_pet_nickname_changed):
		SignalBus.pet_nickname_changed.connect(_on_pet_nickname_changed)
	if not SignalBus.party_damaged_by_monster.is_connected(_on_party_damaged_by_monster):
		SignalBus.party_damaged_by_monster.connect(_on_party_damaged_by_monster)
	_refresh_name_label()
	# 出戰召喚完成後播一次短慶祝（deferred 避免與初始動畫設定同幀互搶）
	call_deferred("_play_spawn_celebrate_once")
	if anim and not anim.animation_finished.is_connected(_on_pet_animation_finished):
		anim.animation_finished.connect(_on_pet_animation_finished)
	_bb_anim_base_pos = anim.position if anim else Vector2.ZERO
	if name_label:
		_bb_name_label_base_pos = name_label.position
	if ui_anchor_node:
		_bb_ui_anchor_base_pos = ui_anchor_node.position
	_baby_bird_idle_chatter = randf_range(BABY_BIRD_IDLE_CHATTER_MIN, BABY_BIRD_IDLE_CHATTER_MAX)

func _apply_pet_resource(d: PetResource) -> void:
	var sf: SpriteFrames = _resolve_sprite_frames(d)
	if sf:
		anim.sprite_frames = sf
	var start_anim := _resolve_movement_anim(false)
	if not start_anim.is_empty():
		anim.play(start_anim)
	var mhp: int = d.max_hp if d.max_hp > 0 else GlobalBalance.PET_MAX_HP
	health.max_hp = mhp
	health.current_hp = mhp
	_anchor_profile = _resolve_anchor_profile(d)
	_update_accessory_anchor(true)
	_update_headwear_visual(true)
	_refresh_name_label()
	_homestead_till_skill = _resolve_homestead_till_skill(d)
	_combat_aoe_skill = _resolve_combat_aoe_skill(d)


func _resolve_homestead_till_skill(d: PetResource) -> SkillResource:
	if d == null:
		return null
	for e in d.skills:
		if e == null:
			continue
		var s: SkillResource = e.skill
		if s != null and s.is_homestead_till_skill:
			return s
	return null


func _resolve_combat_aoe_skill(d: PetResource) -> SkillResource:
	if d == null:
		return null
	for e in d.skills:
		if e == null:
			continue
		var s: SkillResource = e.skill
		if s != null and s.type == SkillResource.SkillType.AOE_ATTACK and not s.is_homestead_till_skill:
			return s
	return null


func _refresh_name_label() -> void:
	if name_label == null or _data == null:
		return
	var n := _data.nickname.strip_edges() if _data.nickname.strip_edges() != "" else (_data.pet_name if _data.pet_name != "" else _data.pet_id)
	name_label.text = n


func _on_pet_nickname_changed(pet_data: PetResource) -> void:
	if _data == null or pet_data == null:
		return
	if pet_data.instance_id.strip_edges() != _data.instance_id.strip_edges():
		return
	_refresh_name_label()

func _resolve_anchor_profile(d: PetResource) -> MonsterResource:
	if d == null or d.pet_id.strip_edges().is_empty():
		return null
	var path := "res://resources身分證/monster/%s.tres" % d.pet_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MonsterResource

func _resolve_sprite_frames(d: PetResource) -> SpriteFrames:
	if d.sprite_frames:
		return d.sprite_frames
	# 後備：依 pet_id 嘗試對應怪物 .tres（與專案命名一致時可直接配對）
	if d.pet_id.is_empty():
		return _fallback_slime_sprite_frames()
	# 寶寶鳥怪物檔名為 baby_bird_monster.tres，非 baby_bird.tres；缺此會誤落史萊姆。
	if d.pet_id == "baby_bird":
		const BB_MONSTER := "res://resources身分證/monster/baby_bird_monster.tres"
		if ResourceLoader.exists(BB_MONSTER):
			var bm: MonsterResource = load(BB_MONSTER) as MonsterResource
			if bm != null and bm.sprite_frames != null:
				return bm.sprite_frames
	var path := "res://resources身分證/monster/%s.tres" % d.pet_id
	if ResourceLoader.exists(path):
		var mres := load(path) as MonsterResource
		if mres and mres.sprite_frames:
			return mres.sprite_frames
	return _fallback_slime_sprite_frames()

func _fallback_slime_sprite_frames() -> SpriteFrames:
	var mres := load("res://resources身分證/monster/slime_green.tres") as MonsterResource
	if mres:
		return mres.sprite_frames
	return null

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_accessory_anchor()
		_update_headwear_visual()
		return
	if _celebrating or health.current_hp <= 0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _anim_lock > 0.0:
		_anim_lock -= delta
		if _anim_lock <= 0.0:
			_anim_lock = 0.0
			_safe_resume_animation(_anim_restore)
			_anim_restore = ""
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		move_and_slide()
		return
	var pos_before_slide := global_position
	_try_teleport_if_too_far_from_player()
	if _combat_sticky > 0.0:
		_combat_sticky -= delta
	if _combat_attack_cd > 0.0:
		_combat_attack_cd -= delta
	if _combat_skill_cd > 0.0:
		_combat_skill_cd -= delta
	if _pet_aoe_delay_left > 0.0:
		_pet_aoe_delay_left -= delta
		if _pet_aoe_delay_left <= 0.0:
			_pet_aoe_delay_left = 0.0
			_fire_pet_line_aoe()
	if _homestead_till_cd > 0.0:
		_homestead_till_cd -= delta
	_motion_intent_vel = Vector2.ZERO
	_seek_point = global_position
	_update_combat(delta)
	_update_follow_position(delta)
	_apply_screen_edge_return(delta)
	_try_heal(delta)
	_try_homestead_till()
	move_and_slide()
	_update_stuck_visual_after_move(pos_before_slide, delta)
	_update_baby_bird_flight(delta)
	_update_visual()
	_baby_bird_tick_idle_chatter(delta)
	_apply_baby_bird_visual_offsets()
	_update_accessory_anchor()
	_update_headwear_visual()

## 頭飾錨點解析（與 MonsterResource／PlayerController 同序）：場景上 frame_offsets／anim_offsets／Dictionary
## → head_anchor_offset → **後備** `MonsterResource`（`res://resources身分證/monster/{pet_id}.tres`，由 `_resolve_anchor_profile`）。
## PetResource 本身不含錨點欄位；未在場景覆寫時由對應怪物資源承接（封印轉化不複製錨點到 PetResource）。
func resolve_head_anchor_offset(
	animation_name: StringName,
	frame_index: int,
	fallback_offset: Vector2 = DEFAULT_HEAD_ANCHOR_OFFSET
) -> Vector2:
	var fi := int(frame_index)
	var candidate_keys := HeadAnchorResolver.candidate_animation_keys(animation_name)
	var frame_key := str(fi)
	var tab := HeadAnchorResolver.resolve_frame_and_anim_tables(
		frame_offsets,
		anim_offsets,
		animation_name,
		frame_index
	)
	if tab.get(HeadAnchorResolver.KEY_OK, false):
		return tab.get(HeadAnchorResolver.KEY_OFFSET, Vector2.ZERO)
	var dict_frame: Variant = HeadAnchorResolver.try_resolve_frame_anchor_overrides(
		frame_anchor_overrides,
		candidate_keys,
		fi,
		frame_key
	)
	if dict_frame is Vector2:
		return dict_frame
	var dict_anim: Variant = HeadAnchorResolver.try_resolve_animation_anchor_overrides(
		animation_anchor_overrides,
		candidate_keys
	)
	if dict_anim is Vector2:
		return dict_anim
	if head_anchor_offset != DEFAULT_HEAD_ANCHOR_OFFSET:
		return head_anchor_offset
	if _anchor_profile != null:
		return HeadAnchorResolver.resolve_head_anchor_monster_exports(
			_anchor_profile.frame_offsets,
			_anchor_profile.anim_offsets,
			animation_name,
			frame_index,
			_anchor_profile.frame_anchor_overrides,
			_anchor_profile.animation_anchor_overrides,
			_anchor_profile.head_anchor_offset,
			_anchor_profile.accessory_offset,
			fallback_offset,
			MonsterResource.DEFAULT_HEAD_ANCHOR_OFFSET
		)
	return fallback_offset

func _update_accessory_anchor(force: bool = false) -> void:
	if accessory_point == null or anim == null:
		return
	var signature := "%s|%d|%s" % [String(anim.animation), anim.frame, str(anim.flip_h)]
	if _is_baby_bird_pet():
		signature += "|%.2f" % _baby_bird_flight_y
	if not force and signature == _last_anchor_signature:
		return
	_last_anchor_signature = signature
	var resolved := resolve_head_anchor_offset(anim.animation, int(anim.frame), accessory_point.position)
	if anim.flip_h:
		resolved.x = -resolved.x
	if _is_baby_bird_pet():
		resolved.y += -_baby_bird_flight_y
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

func _update_headwear_visual(force: bool = false) -> void:
	if accessory_point == null or accessory_sprite == null or anim == null:
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
	var target_anim := _resolve_headwear_idle_animation_name(anim.animation)
	if not frames.has_animation(target_anim):
		if frames.has_animation(&"idle_side"):
			target_anim = &"idle_side"
		elif frames.has_animation(&"idle_down"):
			target_anim = &"idle_down"
		elif frames.has_animation(&"idle_up"):
			target_anim = &"idle_up"
		else:
			accessory_sprite.hide()
			return
	var signature := "%s|%s|%s" % [String(anim.animation), String(target_anim), str(anim.flip_h)]
	if force or signature != _last_headwear_signature:
		_last_headwear_signature = signature
		if accessory_sprite.animation != target_anim or not accessory_sprite.is_playing():
			accessory_sprite.play(target_anim)
	accessory_sprite.flip_h = anim.flip_h

func _reset_breadcrumb_trail() -> void:
	_trail_clock = 0.0
	_trail_times.clear()
	_trail_positions.clear()
	_roam_offset = Vector2.ZERO
	_roam_pick_cooldown = 0.0
	_idle_roam_dirty = true
	_idle_calm_timer = 0.0
	_combat_target = null
	_combat_sticky = 0.0
	_combat_attack_cd = 0.0
	_combat_skill_cd = 0.0
	_pet_aoe_delay_left = 0.0
	_pet_aoe_skill_pending = null
	_anim_lock = 0.0
	_anim_restore = ""
	_heal_casting = false
	_stuck_visual_timer = 0.0
	_visual_stuck_play_idle = false
	_baby_bird_flight_y = 0.0
	_baby_bird_landing_active = false
	_bb_smooth_follow_dist = 50.0
	_bb_ascent_run_suppress_left = 0.0
	_bb_landing_descent_active = false
	_bb_lazy_takeoff_timer = 0.0
	_bb_prev_hyst_moving_for_lazy = false
	_baby_bird_reset_anim_speed_default()

func _combat_active() -> bool:
	return _combat_target != null and is_instance_valid(_combat_target) and _combat_sticky > 0.0

func _combat_disengage() -> void:
	_combat_target = null
	_combat_sticky = 0.0
	_combat_attack_cd = 0.0

func _combat_target_pos() -> Vector2:
	if _combat_target == null:
		return global_position
	var parent := _combat_target.get_parent()
	if parent is Node2D:
		return (parent as Node2D).global_position
	return _combat_target.global_position

func _get_dir_string_from_vec(v: Vector2) -> String:
	if v.length() < 2.0:
		return _last_dir
	if abs(v.y) > abs(v.x) * 1.3:
		return "down" if v.y > 0 else "up"
	return "side"


func _is_baby_bird_pet() -> bool:
	return _data != null and _data.pet_id == "baby_bird"


func _baby_bird_strip_idle_variant_suffix(full: String) -> String:
	var parts := full.split("_")
	if parts.size() < 2:
		return ""
	var last := parts[parts.size() - 1]
	if not last.is_valid_int():
		return ""
	var acc := parts[0]
	for i in range(1, parts.size() - 1):
		acc += "_" + parts[i]
	return acc


func _baby_bird_should_skip_movement_visual() -> bool:
	if not _is_baby_bird_pet():
		return false
	if anim == null or anim.sprite_frames == null:
		return false
	var n := String(anim.animation)
	if not n.begins_with("idle_"):
		return false
	if anim.sprite_frames.get_animation_loop(n):
		return false
	return anim.is_playing()


func _baby_bird_movement_suffix_for_landing(ref_vec: Vector2) -> String:
	if _player != null:
		var pc := _player as PlayerController
		if pc != null:
			return pc.direction_suffix_including_diagonals(ref_vec)
	return _get_dir_string_from_vec(ref_vec)


func _baby_bird_reset_anim_speed_default() -> void:
	if anim:
		anim.speed_scale = 1.0


func _baby_bird_resolve_landing_anim(ref_vec: Vector2) -> StringName:
	if anim == null or anim.sprite_frames == null:
		return &""
	var suffix := _baby_bird_movement_suffix_for_landing(ref_vec)
	var cand: String = "run_%s_1" % suffix
	if anim.sprite_frames.has_animation(cand):
		return StringName(cand)
	for fb in ["run_up_1", "run_side_1", "run_down_1", "run_side_down_1"]:
		if anim.sprite_frames.has_animation(fb):
			return StringName(fb)
	return &""


func _start_baby_bird_landing(ref_vec: Vector2) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var land_name := _baby_bird_resolve_landing_anim(ref_vec)
	if land_name.is_empty():
		_baby_bird_flight_y = 0.0
		return
	var dur := _get_anim_duration_sec(land_name)
	if dur <= 0.08:
		dur = 0.5
	_baby_bird_landing_active = true
	_baby_bird_landing_total = dur
	_baby_bird_landing_time_left = dur
	_baby_bird_landing_start_y = _baby_bird_flight_y
	_baby_bird_reset_anim_speed_default()
	anim.play(land_name)
	var ls := String(land_name)
	if "side" in ls and ref_vec.length_squared() > 0.25:
		var lx := ref_vec.x
		if absf(lx) > 0.5:
			anim.flip_h = (lx > 0.0)
	_lock_anim_for(dur + 0.02)
	var resume := _resolve_movement_anim(false)
	_anim_restore = resume


func _update_baby_bird_flight(delta: float) -> void:
	_bb_flight_wants_run_boost = false
	if not _is_baby_bird_pet():
		_baby_bird_flight_y = 0.0
		_baby_bird_landing_active = false
		return
	var pm := _hyst_player_moving
	if _bb_ascent_run_suppress_left > 0.0:
		_bb_ascent_run_suppress_left = maxf(0.0, _bb_ascent_run_suppress_left - delta)
	var lazy_sec := GlobalBalance.BABY_BIRD_LAZY_TAKEOFF_SEC if GlobalBalance else 0.72
	if pm:
		if not _bb_prev_hyst_moving_for_lazy:
			_bb_lazy_takeoff_timer = lazy_sec
		if lazy_sec > 0.001:
			_bb_lazy_takeoff_timer = maxf(0.0, _bb_lazy_takeoff_timer - delta)
		else:
			_bb_lazy_takeoff_timer = 0.0
	else:
		_bb_lazy_takeoff_timer = 0.0
	if _celebrating or health.current_hp <= 0:
		_baby_bird_flight_y = lerpf(_baby_bird_flight_y, 0.0, 10.0 * delta)
		if _baby_bird_landing_active:
			_baby_bird_reset_anim_speed_default()
		_baby_bird_landing_active = false
		_bb_landing_descent_active = false
		_bb_prev_hyst_moving_for_lazy = pm
		return
	if _combat_active():
		_baby_bird_flight_y = lerpf(_baby_bird_flight_y, 0.0, 12.0 * delta)
		if _baby_bird_landing_active:
			_baby_bird_landing_active = false
			_baby_bird_reset_anim_speed_default()
			_anim_lock = 0.0
		_bb_landing_descent_active = false
		_bb_prev_hyst_moving_for_lazy = pm
		return
	var move_ref := _seek_point - global_position
	if move_ref.length_squared() < 4.0:
		move_ref = Vector2(0, 1)

	if _baby_bird_landing_active and pm:
		_baby_bird_landing_active = false
		_baby_bird_landing_time_left = 0.0
		_anim_lock = 0.0
		_baby_bird_reset_anim_speed_default()
		_bb_landing_descent_active = false
		_bb_ascent_run_suppress_left = maxf(_bb_ascent_run_suppress_left, BABY_BIRD_ASCENT_RUN_SUPPRESS_AFTER_LAND_SEC * 0.82)
		_safe_resume_animation(_resolve_movement_anim(_visual_is_running))

	if pm:
		_bb_landing_descent_active = false

	if _baby_bird_landing_active:
		_baby_bird_landing_time_left -= delta
		var u := 1.0 - clampf(_baby_bird_landing_time_left / maxf(_baby_bird_landing_total, 0.001), 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		_baby_bird_flight_y = lerpf(_baby_bird_landing_start_y, 0.0, e)
		if _baby_bird_landing_time_left <= 0.0:
			_baby_bird_landing_active = false
			_baby_bird_flight_y = 0.0
			_baby_bird_reset_anim_speed_default()
			_bb_ascent_run_suppress_left = maxf(_bb_ascent_run_suppress_left, BABY_BIRD_ASCENT_RUN_SUPPRESS_AFTER_LAND_SEC)
		_baby_bird_prev_player_moving = pm
		_bb_prev_hyst_moving_for_lazy = pm
		return

	if _anim_lock > 0.0:
		_baby_bird_prev_player_moving = pm
		_bb_prev_hyst_moving_for_lazy = pm
		return

	var edge_stop := _baby_bird_prev_player_moving and not pm
	if edge_stop and _baby_bird_flight_y >= BABY_BIRD_LANDING_MIN_Y:
		_bb_landing_descent_active = true

	if _bb_landing_descent_active and not _baby_bird_landing_active:
		var fin_h: float = 7.0
		var dlerp: float = 0.92
		if GlobalBalance:
			fin_h = GlobalBalance.BABY_BIRD_LANDING_FINAL_HEIGHT
			dlerp = GlobalBalance.BABY_BIRD_DESCENT_LERP
		_baby_bird_flight_y = lerpf(_baby_bird_flight_y, 0.0, dlerp * delta)
		_bb_flight_wants_run_boost = true
		if _baby_bird_flight_y <= fin_h:
			_bb_landing_descent_active = false
			_start_baby_bird_landing(move_ref)
		_baby_bird_prev_player_moving = pm
		_bb_prev_hyst_moving_for_lazy = pm
		return

	var dmin := 30.0
	var dmax := 138.0
	var y_max := 150.0
	var lerp_up := 2.65
	var lerp_down := 6.0
	var smooth_sp := 6.0
	var floor_alt := 0.38
	var w_amp := 7.0
	var w_sp := 1.85
	if GlobalBalance:
		dmin = GlobalBalance.BABY_BIRD_FLIGHT_DIST_MIN
		dmax = GlobalBalance.BABY_BIRD_FLIGHT_DIST_MAX
		y_max = GlobalBalance.BABY_BIRD_FLIGHT_Y_MAX
		lerp_up = GlobalBalance.BABY_BIRD_FLIGHT_LERP_UP
		lerp_down = GlobalBalance.BABY_BIRD_FLIGHT_LERP_DOWN
		smooth_sp = GlobalBalance.BABY_BIRD_FLIGHT_DIST_SMOOTH_SPEED
		floor_alt = GlobalBalance.BABY_BIRD_FLIGHT_MOVE_ALT_FLOOR
		w_amp = GlobalBalance.BABY_BIRD_ALT_WOBBLE_AMP
		w_sp = GlobalBalance.BABY_BIRD_ALT_WOBBLE_SPEED

	# 主角站定時：距離平滑放慢（頭頂盤旋仍會改變跟隨點，避免 t01 抖動變成上下漂）
	var dist_smooth := smooth_sp * (0.42 if not pm else 1.0)
	_bb_smooth_follow_dist = lerpf(_bb_smooth_follow_dist, _dist_to_follow_slot, dist_smooth * delta)
	var t01 := inverse_lerp(dmin, dmax, _bb_smooth_follow_dist)
	t01 = clampf(t01, 0.0, 1.0)
	_bb_alt_wobble_phase += delta * w_sp
	# 微擺僅在主角移動中；原地 idle 時關閉，否則目標高度會週期變化 → 精靈看起來一直浮動
	var wobble := (sin(_bb_alt_wobble_phase) * w_amp) if pm else 0.0

	var lazy_start_mult := GlobalBalance.BABY_BIRD_LAZY_ALT_START_MULT if GlobalBalance else 0.22
	var air_eager := 1.0
	if pm and lazy_sec > 0.001:
		var t_lazy := 1.0 - clampf(_bb_lazy_takeoff_timer / lazy_sec, 0.0, 1.0)
		air_eager = t_lazy * t_lazy * (3.0 - 2.0 * t_lazy)

	var target_y := 0.0
	if pm or _visual_is_running:
		var span := 1.0 - floor_alt
		var base_y := (floor_alt + t01 * span) * y_max + wobble
		var lazm := lerpf(lazy_start_mult, 1.0, air_eager) if pm else 1.0
		target_y = base_y * lazm
	else:
		target_y = t01 * y_max * 0.38 + wobble * 0.45

	if edge_stop and _baby_bird_flight_y < BABY_BIRD_LANDING_MIN_Y:
		_baby_bird_flight_y = lerpf(_baby_bird_flight_y, 0.0, 14.0 * delta)
	elif not edge_stop:
		if _bb_ascent_run_suppress_left <= 0.0 and target_y > _baby_bird_flight_y + BABY_BIRD_FLIGHT_ASCEND_RUN_GAP:
			_bb_flight_wants_run_boost = true
		var rate := lerp_up if target_y > _baby_bird_flight_y else lerp_down
		_baby_bird_flight_y = lerpf(_baby_bird_flight_y, target_y, rate * delta)

	_baby_bird_prev_player_moving = pm
	_bb_prev_hyst_moving_for_lazy = pm


func _apply_baby_bird_visual_offsets() -> void:
	if Engine.is_editor_hint():
		return
	if not _is_baby_bird_pet():
		if anim:
			anim.position = _bb_anim_base_pos
		if name_label:
			name_label.position = _bb_name_label_base_pos
		if ui_anchor_node:
			ui_anchor_node.position = _bb_ui_anchor_base_pos
		return
	var lift := -_baby_bird_flight_y
	if anim:
		anim.position = Vector2(_bb_anim_base_pos.x, _bb_anim_base_pos.y + lift)
	if name_label:
		name_label.position = Vector2(_bb_name_label_base_pos.x, _bb_name_label_base_pos.y + lift)
	if ui_anchor_node:
		ui_anchor_node.position = Vector2(_bb_ui_anchor_base_pos.x, _bb_ui_anchor_base_pos.y + lift)


func _baby_bird_tick_idle_chatter(delta: float) -> void:
	if not _is_baby_bird_pet():
		return
	if _celebrating or health.current_hp <= 0 or _combat_active():
		return
	if _anim_lock > 0.0 or _baby_bird_landing_active:
		return
	if _visual_is_running or _baby_bird_flight_y > 6.0:
		return
	if anim == null or anim.sprite_frames == null:
		return
	var cur := String(anim.animation)
	if cur.begins_with("idle_") and not anim.sprite_frames.get_animation_loop(cur):
		return
	_baby_bird_idle_chatter -= delta
	if _baby_bird_idle_chatter > 0.0:
		return
	_baby_bird_idle_chatter = randf_range(BABY_BIRD_IDLE_CHATTER_MIN, BABY_BIRD_IDLE_CHATTER_MAX)
	if randf() > 0.78:
		return
	var base := _resolve_movement_anim(false)
	if not base.begins_with("idle_"):
		return
	var pool: Array[String] = []
	for i in range(1, 8):
		var cand: String = "%s_%d" % [base, i]
		if anim.sprite_frames.has_animation(cand):
			pool.append(cand)
	if pool.is_empty():
		return
	var weighted: Array[String] = []
	for s in pool:
		var fc: int = anim.sprite_frames.get_frame_count(s)
		var w := 3
		if fc > 10:
			w = 1
		elif fc > 6:
			w = 2
		for __j in w:
			weighted.append(s)
	var pick: String = weighted[randi() % weighted.size()]
	anim.play(pick)


func _on_pet_animation_finished() -> void:
	if not _is_baby_bird_pet():
		return
	if anim == null or anim.sprite_frames == null:
		return
	var n := String(anim.animation)
	if not n.begins_with("idle_"):
		return
	var parts := n.split("_")
	if parts.is_empty():
		return
	var last := parts[parts.size() - 1]
	if not last.is_valid_int():
		return
	var base := _baby_bird_strip_idle_variant_suffix(n)
	if not base.is_empty() and anim.sprite_frames.has_animation(base):
		anim.play(base)


func _play_pet_animation(base: String, ref_vec: Vector2) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	_last_dir = _get_dir_string_from_vec(ref_vec)
	var target := base
	var candidate := base + "_" + _last_dir
	if anim.sprite_frames.has_animation(candidate):
		target = candidate
	elif anim.sprite_frames.has_animation(base):
		target = base
	else:
		# fallback：交給既有 movement resolver，至少不會 play("")
		target = _resolve_movement_anim(_visual_is_running)
	if target.is_empty():
		return
	if "side" in target:
		var look_x := ref_vec.x
		if look_x != 0.0:
			anim.flip_h = (look_x > 0)
	anim.play(target)

func _lock_anim_for(seconds: float) -> void:
	if seconds <= 0.0:
		return
	if anim and anim.sprite_frames:
		_anim_restore = anim.animation
	_anim_lock = maxf(_anim_lock, seconds)

func _get_anim_duration_sec(anim_name: StringName) -> float:
	if anim == null or anim.sprite_frames == null:
		return 0.0
	if anim_name.is_empty() or not anim.sprite_frames.has_animation(anim_name):
		return 0.0
	var sf := anim.sprite_frames
	var count := sf.get_frame_count(anim_name)
	if count <= 0:
		return 0.0
	var sum := 0.0
	for i in count:
		sum += sf.get_frame_duration(anim_name, i)
	var speed := sf.get_animation_speed(anim_name)
	if speed > 0.0:
		sum /= speed
	return sum


func _begin_pet_line_aoe(tp: Vector2) -> void:
	var sk := _combat_aoe_skill
	if sk == null:
		return
	_combat_skill_cd = sk.cooldown
	_pet_aoe_skill_pending = sk
	_pet_aoe_delay_left = sk.trigger_delay
	var an := sk.animation_name.strip_edges()
	if an.is_empty():
		an = "spell"
	_play_pet_animation(an, tp - global_position)
	var dur := _get_anim_duration_sec(StringName(an))
	if dur <= 0.0:
		dur = 0.55
	_lock_anim_for(maxf(dur, sk.trigger_delay) + 0.2)


func _fire_pet_line_aoe() -> void:
	var sk := _pet_aoe_skill_pending
	_pet_aoe_skill_pending = null
	if sk == null or not is_instance_valid(self):
		return
	var em := get_tree().get_first_node_in_group("effect_manager") if get_tree() else null
	if em == null:
		return
	if sk.aoe_use_ground_target and em.has_method("play_ground_slam_aoe_from_skill"):
		var impact := _combat_target_pos()
		em.play_ground_slam_aoe_from_skill(sk, self, false, impact)
	elif em.has_method("play_line_sweep_aoe_from_skill"):
		em.play_line_sweep_aoe_from_skill(sk, self, false)


func _update_combat(_delta: float) -> void:
	if _combat_target != null and not is_instance_valid(_combat_target):
		_combat_disengage()
		return
	if _combat_target != null and _hurtbox_on_monster_with_seal_active(_combat_target):
		_combat_disengage()
		return
	if not _combat_active():
		return
	var tp := _combat_target_pos()
	_seek_point = tp
	if _player:
		var d_player := _player.global_position.distance_to(tp)
		if d_player > PET_DISENGAGE_DIST:
			_combat_disengage()
			return
	# 追到怪身邊一點點（可日後做 orbit/坦克站位）
	var dist := global_position.distance_to(tp)
	if _pet_aoe_delay_left > 0.0:
		return
	if _combat_aoe_skill != null and _combat_skill_cd <= 0.0 and _anim_lock <= 0.0 and not _heal_casting:
		if dist <= PET_ATTACK_RANGE * 4.2:
			_begin_pet_line_aoe(tp)
			return
	if dist > PET_ATTACK_RANGE:
		var dir := (tp - global_position).normalized()
		var spd: float = GlobalBalance.PET_FOLLOW_SPEED * (_data.follow_speed_mult if _data else 1.1) * _party_slot_follow_mult()
		var target_vel := dir * spd
		_motion_intent_vel = target_vel
		velocity = velocity.lerp(target_vel, FOLLOW_LERP_WEIGHT)
		return
	# 已在攻擊距離內：嘗試普攻
	if _combat_attack_cd > 0.0:
		return
	var owner_m := _combat_target.get_parent()
	if owner_m != null and owner_m.has_method("is_targetable") and not owner_m.is_targetable():
		_combat_disengage()
		return
	_lock_anim_for(PET_ATTACK_LOCK_SEC)
	_play_pet_animation("attack", tp - global_position)
	_combat_attack_cd = PET_AUTO_ATTACK_CD
	_combat_target.take_damage(GlobalBalance.PET_MELEE_DAMAGE)

func _party_follow_anchor_offset() -> Vector2:
	match party_slot_index:
		0:
			return Vector2(-56, 10)
		1:
			return Vector2(56, 10)
		2:
			return Vector2(0, 64)
		_:
			return Vector2.ZERO


func _player_forward() -> Vector2:
	if _player == null:
		return Vector2.DOWN
	var f := _player.last_direction
	if f.length_squared() < 0.0001:
		return Vector2.DOWN
	return f.normalized()

func _is_in_front_hemisphere(rel: Vector2) -> bool:
	if rel.length_squared() < 9.0:
		return false
	return rel.normalized().dot(_player_forward()) > FRONT_HEMI_DOT

func _nudge_rel_out_of_front(rel: Vector2) -> Vector2:
	var fwd := _player_forward()
	var along := rel.dot(fwd)
	if along <= 0.0:
		return rel
	return rel - fwd * (along + FRONT_NUDGE_ALONG)

func _random_offset_not_in_front(dist: float) -> Vector2:
	var fwd := _player_forward()
	var back := (-fwd).angle()
	var spread := PI * 0.92
	return Vector2.from_angle(back + randf_range(-spread * 0.5, spread * 0.5)) * dist

func _pick_idle_roam_offset() -> void:
	var base: float = _data.follow_distance if _data else 60.0
	# 最小離主角稍遠、最大不要甩太外（較窄的環）
	var dmin := maxf(base * 0.72, 52.0)
	var dmax := minf(base * 0.98, 88.0)
	if dmax < dmin:
		dmax = dmin + 8.0
	var dist := randf_range(dmin, dmax)
	var allow_front := _idle_calm_timer >= IDLE_FRONT_ALLOW_SEC
	if allow_front:
		var ang := randf() * TAU
		_roam_offset = Vector2.from_angle(ang) * dist
		return
	for __i in 40:
		var ang2 := randf() * TAU
		var off := Vector2.from_angle(ang2) * dist
		if not _is_in_front_hemisphere(off):
			_roam_offset = off
			return
	_roam_offset = _random_offset_not_in_front(dist)

func _trail_push_sample(pos: Vector2, t: float) -> void:
	_trail_positions.append(pos)
	_trail_times.append(t)
	while not _trail_times.is_empty() and t - _trail_times[0] > BREADCRUMB_MAX_HISTORY_SEC:
		_trail_times.remove_at(0)
		_trail_positions.remove_at(0)

func _trail_sample_at_time(want_t: float) -> Vector2:
	if _trail_times.is_empty() or _trail_positions.is_empty():
		return _player.global_position if _player else global_position
	var n := _trail_times.size()
	if want_t <= _trail_times[0]:
		return _trail_positions[0]
	if want_t >= _trail_times[n - 1]:
		return _trail_positions[n - 1]
	for i in n - 1:
		var t0 := _trail_times[i]
		var t1 := _trail_times[i + 1]
		if want_t >= t0 and want_t <= t1:
			var span := t1 - t0
			var u := (want_t - t0) / span if span > 0.0001 else 0.0
			return _trail_positions[i].lerp(_trail_positions[i + 1], u)
	return _trail_positions[n - 1]

func _update_follow_position(delta: float) -> void:
	if _combat_active():
		# 戰鬥中跟隨錨點未更新；改以與目標的距離驅動 run/idle 遲滯，避免黏怪時 _dist 假 999 全程播 run
		_dist_to_follow_slot = global_position.distance_to(_combat_target_pos())
		return
	_trail_clock += delta
	_trail_push_sample(_player.global_position, _trail_clock)
	var trail_delay: float = BREADCRUMB_DELAY_SEC + _party_slot_trail_lag_sec()
	var trail_target: Vector2 = _trail_sample_at_time(_trail_clock - trail_delay)
	var psp: float = _player.velocity.length()
	if psp > PLAYER_SPEED_MOVE_ENTER:
		_hyst_player_moving = true
	elif psp < PLAYER_SPEED_MOVE_EXIT:
		_hyst_player_moving = false
	if _hyst_player_moving:
		_idle_calm_timer = 0.0
	else:
		_idle_calm_timer += delta
	var allow_front_roam := _idle_calm_timer >= IDLE_FRONT_ALLOW_SEC
	var target: Vector2
	if _hyst_player_moving:
		var rel_tt := trail_target - _player.global_position
		if not allow_front_roam and _is_in_front_hemisphere(rel_tt):
			trail_target = _player.global_position + _nudge_rel_out_of_front(rel_tt)
		target = trail_target + _party_follow_anchor_offset()
		_idle_roam_dirty = true
	else:
		if _idle_roam_dirty:
			_roam_offset = Vector2.ZERO
			_roam_pick_cooldown = 0.0
			_idle_roam_dirty = false
		_roam_pick_cooldown -= delta
		var need_pick := _roam_offset.length_squared() < 4.0
		var anchor := _player.global_position + _roam_offset
		var reached := global_position.distance_to(anchor) < FOLLOW_ARRIVE_DISTANCE + IDLE_ROAM_NEAR_PLAYER
		if need_pick:
			_pick_idle_roam_offset()
			_roam_pick_cooldown = randf_range(ROAM_REPICK_MIN_SEC, ROAM_REPICK_MAX_SEC)
		elif reached and _roam_pick_cooldown <= 0.0:
			_pick_idle_roam_offset()
			_roam_pick_cooldown = randf_range(ROAM_REPICK_MIN_SEC, ROAM_REPICK_MAX_SEC)
		target = _player.global_position + _roam_offset + _party_follow_anchor_offset()
	if _is_baby_bird_pet() and not _combat_active():
		target += _baby_bird_follow_anchor_extras(delta)
	_dist_to_follow_slot = global_position.distance_to(target)
	_seek_point = target
	var spd: float = GlobalBalance.PET_FOLLOW_SPEED * (_data.follow_speed_mult if _data else 1.1) * _party_slot_follow_mult()
	if _is_baby_bird_pet() and not _combat_active() and _hyst_player_moving:
		var cd: float = GlobalBalance.BABY_BIRD_CHASE_SPEED_DIST if GlobalBalance else 54.0
		var cm: float = GlobalBalance.BABY_BIRD_CHASE_SPEED_MULT if GlobalBalance else 1.48
		if _dist_to_follow_slot > cd:
			spd *= cm
	if _dist_to_follow_slot > FOLLOW_ARRIVE_DISTANCE:
		var dir_v := (target - global_position).normalized()
		var target_vel := dir_v * spd
		_motion_intent_vel = target_vel
		velocity = velocity.lerp(target_vel, FOLLOW_LERP_WEIGHT)
	else:
		_motion_intent_vel = Vector2.ZERO
		velocity = velocity.lerp(Vector2.ZERO, FOLLOW_LERP_WEIGHT)

## 對齊史萊姆等資源的 idle_/run_ + down/side/up；绝不回傳不存在的名字，避免 play("")
func _resolve_movement_anim(want_run: bool) -> String:
	if anim == null or anim.sprite_frames == null:
		return ""
	var primary := "run_" if want_run else "idle_"
	var secondary := "idle_" if want_run else "run_"
	var dirs: PackedStringArray = [_last_dir, "down", "side", "up"]
	for d in dirs:
		var n := primary + d
		if anim.sprite_frames.has_animation(n):
			return n
	for d in dirs:
		var n := secondary + d
		if anim.sprite_frames.has_animation(n):
			return n
	var names := anim.sprite_frames.get_animation_names()
	return names[0] if names.size() > 0 else ""

func _safe_resume_animation(previous: String) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var p := previous
	if p.is_empty() or not anim.sprite_frames.has_animation(p):
		p = _resolve_movement_anim(_visual_is_running)
	if p.is_empty():
		return
	if anim.animation != p:
		anim.play(p)

func _update_visual() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if _is_baby_bird_pet() and _baby_bird_should_skip_movement_visual():
		var n := String(anim.animation)
		if "side" in n and _player:
			anim.flip_h = (_player.last_direction.x > 0.0)
		return
	if _anim_lock > 0.0:
		return
	var use_player_facing := false
	var ref_vec := Vector2.ZERO
	if _combat_active():
		ref_vec = _combat_target_pos() - global_position
	elif _dist_to_follow_slot > FOLLOW_ARRIVE_DISTANCE + 2.0:
		ref_vec = _seek_point - global_position
	else:
		var v := _motion_intent_vel
		if v.length_squared() < 4.0:
			v = velocity
		if v.length_squared() > 16.0:
			ref_vec = v
		else:
			use_player_facing = true
	if use_player_facing and _player:
		_last_dir = _player.get_dir_string()
	elif ref_vec.length_squared() > 0.0004:
		_last_dir = _get_dir_string_from_vec(ref_vec)
	if _dist_to_follow_slot > VISUAL_RUN_ENTER_DIST:
		_visual_is_running = true
	elif _dist_to_follow_slot < VISUAL_RUN_EXIT_DIST:
		_visual_is_running = false
	var want_run := _visual_is_running
	if _is_baby_bird_pet() and _bb_flight_wants_run_boost:
		want_run = true
	if _visual_stuck_play_idle:
		want_run = false
	var anim_name := _resolve_movement_anim(want_run)
	if anim_name.is_empty():
		return
	if anim.animation != anim_name:
		anim.play(anim_name)
	if anim_name.ends_with("side"):
		if use_player_facing and _player:
			anim.flip_h = (_player.last_direction.x > 0)
		elif ref_vec.length_squared() > 0.0004:
			var lx := ref_vec.x
			if absf(lx) > 0.5:
				anim.flip_h = (lx > 0)
			elif _player:
				anim.flip_h = (_player.last_direction.x > 0)
		elif _player:
			anim.flip_h = (_player.last_direction.x > 0)

func _on_party_damaged_by_monster(attacker_hurtbox: HurtboxComponent) -> void:
	if _celebrating or health.current_hp <= 0:
		return
	if attacker_hurtbox == null or not is_instance_valid(attacker_hurtbox):
		return
	if _hurtbox_on_monster_with_seal_active(attacker_hurtbox):
		return
	var m := attacker_hurtbox.get_parent()
	if m == null or not m.has_method("is_targetable") or not m.is_targetable():
		return
	_combat_target = attacker_hurtbox
	_combat_sticky = PET_COMBAT_STICKY_SEC


func _on_player_melee_hit(melee_target: Variant) -> void:
	if _celebrating or health.current_hp <= 0:
		return
	var hb: HurtboxComponent = null
	if melee_target is HurtboxComponent:
		hb = melee_target as HurtboxComponent
	if hb == null or not is_instance_valid(hb):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		hb = _player.current_enemy if _player else null
	if hb == null or not is_instance_valid(hb):
		return
	var m_hit := hb.get_parent()
	if m_hit != null and m_hit.has_method("is_targetable") and not m_hit.is_targetable():
		return
	if _hurtbox_on_monster_with_seal_active(hb):
		return
	# 進入/刷新戰鬥：主角拉打時仍持續作戰，直到脫戰距離或計時歸零
	_combat_target = hb
	_combat_sticky = PET_COMBAT_STICKY_SEC
	hb.take_damage(GlobalBalance.PET_MELEE_DAMAGE)

func _pick_party_heal_target(heal_amount: int) -> HealthComponent:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	var candidates: Array[HealthComponent] = []
	if _player and _player.health and _player.health.current_hp > 0:
		candidates.append(_player.health)
	for n in get_tree().get_nodes_in_group("deployed_pet"):
		if n == null or not is_instance_valid(n):
			continue
		var ph: HealthComponent = n.health if n.get("health") else null
		if ph and ph.current_hp > 0:
			candidates.append(ph)
	var amt := maxi(1, heal_amount)
	var primary_best: HealthComponent = null
	var primary_ratio := 2.0
	var fall_best: HealthComponent = null
	var fall_room := -1
	var fall_ratio := 2.0
	for h in candidates:
		if h.current_hp >= h.max_hp:
			continue
		var pend := PetManager.party_heal_pending_for(h) if PetManager else 0
		var projected := mini(h.max_hp, h.current_hp + pend)
		var room: int = h.max_hp - projected
		if room <= 0:
			continue
		var denom := float(maxi(1, h.max_hp))
		var r := float(projected) / denom
		if room >= amt:
			if primary_best == null or r < primary_ratio - 0.0001 or (
				absf(r - primary_ratio) <= 0.0001 and h.current_hp < primary_best.current_hp
			):
				primary_best = h
				primary_ratio = r
		else:
			if fall_best == null or room > fall_room or (room == fall_room and r < fall_ratio - 0.0001):
				fall_best = h
				fall_room = room
				fall_ratio = r
	if primary_best != null:
		return primary_best
	return fall_best


func _health_target_world_pos(hc: HealthComponent) -> Vector2:
	if hc == null:
		return global_position
	var p := hc.get_parent()
	if p is Node2D:
		return (p as Node2D).global_position
	return global_position


func _try_heal(delta: float) -> void:
	if _celebrating:
		return
	if _heal_casting:
		return
	_heal_cd -= delta
	if _heal_cd > 0.0:
		return
	var amt: int = _data.heal_amount if _data and _data.heal_amount > 0 else GlobalBalance.PET_HEAL_AMOUNT
	var target_h := _pick_party_heal_target(amt)
	if target_h == null:
		return
	var cd: float = _data.heal_cooldown if _data and _data.heal_cooldown > 0.0 else GlobalBalance.PET_HEAL_COOLDOWN
	_heal_cd = cd
	_cast_heal_spell(amt, target_h)


func _try_homestead_till() -> void:
	if HomeManager == null or not HomeManager.in_homestead:
		return
	if _homestead_till_skill == null:
		return
	if _celebrating or health.current_hp <= 0:
		return
	if _anim_lock > 0.0 or _heal_casting:
		return
	if _combat_active():
		return
	if _homestead_till_cd > 0.0:
		return
	var plot := _find_nearest_untilled_plot()
	if plot == null:
		return
	var p2 := plot as Node2D
	if p2 == null:
		return
	if global_position.distance_to(p2.global_position) > PET_HOMESTEAD_TILL_RANGE:
		return
	if not plot.has_method("till_from_pet"):
		return
	if not bool(plot.call("till_from_pet", self)):
		return
	_homestead_till_cd = maxf(_homestead_till_skill.cooldown, 1.2)
	var anim_name := _homestead_till_skill.animation_name.strip_edges()
	var ref_vec := p2.global_position - global_position
	if anim_name.is_empty():
		_play_pet_animation("spell", ref_vec)
		anim_name = "spell"
	else:
		_play_pet_animation(anim_name, ref_vec)
	var dur := _get_anim_duration_sec(StringName(anim_name))
	if dur <= 0.0:
		dur = 0.55
	_lock_anim_for(dur + 0.08)


func _find_nearest_untilled_plot() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node = null
	var best_d := INF
	for n in tree.get_nodes_in_group("homestead_soil_plot"):
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method("can_pet_till"):
			continue
		if not bool(n.call("can_pet_till")):
			continue
		if n is Node2D:
			var d := global_position.distance_to((n as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = n
	return best


func _resolve_heal_trigger_delay() -> float:
	# 對齊史萊姆怪物技能：res://resources身分證/skill/skill_slime_heal.tres (trigger_delay=1.06)
	if _data and _data.pet_id == "slime_green":
		var s := load("res://resources身分證/skill/skill_slime_heal.tres") as SkillResource
		if s:
			return s.trigger_delay
	return PET_HEAL_TRIGGER_FALLBACK

func _cast_heal_spell(amount: int, target_hc: HealthComponent) -> void:
	if _heal_casting:
		return
	if target_hc == null or not is_instance_valid(target_hc) or not is_instance_valid(target_hc.get_parent()):
		return
	var reserve_id := target_hc.get_instance_id()
	if PetManager:
		PetManager.party_heal_pending_add(target_hc, amount)
	_heal_casting = true
	var prev: StringName = &""
	if anim:
		prev = anim.animation
	if anim and anim.sprite_frames:
		if prev.is_empty() or not anim.sprite_frames.has_animation(prev):
			prev = StringName(_resolve_movement_anim(_visual_is_running))
	var ref_vec := _health_target_world_pos(target_hc) - global_position
	var dur := _get_anim_duration_sec(&"spell")
	if dur <= 0.0:
		dur = 0.55
	var trigger_delay := _resolve_heal_trigger_delay()
	_lock_anim_for(dur + 0.06)
	_anim_restore = String(prev)
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("spell"):
		_play_pet_animation("spell", ref_vec)
	if PET_HEAL_STARTUP_SEC > 0.0:
		await get_tree().create_timer(PET_HEAL_STARTUP_SEC).timeout
	await get_tree().create_timer(trigger_delay).timeout
	if not is_instance_valid(self):
		if PetManager:
			PetManager.party_heal_pending_remove_by_id(reserve_id, amount)
		_heal_casting = false
		return
	if target_hc == null or not is_instance_valid(target_hc) or not is_instance_valid(target_hc.get_parent()):
		if PetManager:
			PetManager.party_heal_pending_remove_by_id(reserve_id, amount)
		_heal_casting = false
		return
	if target_hc.current_hp <= 0:
		if PetManager:
			PetManager.party_heal_pending_remove_by_id(reserve_id, amount)
		_heal_casting = false
		return
	target_hc.heal(amount)
	if PetManager:
		PetManager.party_heal_pending_remove_by_id(reserve_id, amount)
	# 等到 spell 播完再解鎖/回復由 _anim_lock 負責；這裡只結束 casting
	_heal_casting = false

func _play_spell_flash() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if anim.sprite_frames.has_animation("spell"):
		var prev := anim.animation
		if prev.is_empty() or not anim.sprite_frames.has_animation(prev):
			prev = _resolve_movement_anim(_visual_is_running)
		var dur := _get_anim_duration_sec(&"spell")
		if dur <= 0.0:
			dur = 0.55
		_lock_anim_for(dur + 0.06)
		_anim_restore = prev
		anim.play("spell")
		await get_tree().create_timer(dur).timeout
		if is_instance_valid(self) and anim and not _celebrating:
			_safe_resume_animation(prev)

func take_damage_from_monster(amount: int) -> void:
	if health.current_hp <= 0:
		return
	health.take_damage(amount)
	SignalBus.damage_spawned.emit(global_position, amount, false)

func play_hit_animation(is_final: bool) -> void:
	var t := create_tween()
	modulate = Color.RED
	t.tween_property(self, "modulate", Color.WHITE, 0.2)
	if is_final:
		scale = Vector2(0.85, 0.85)

func _on_pet_died() -> void:
	if SignalBus:
		SignalBus.pet_party_slot_recall_requested.emit(party_slot_index)

func _on_peer_pet_captured(_new_pet: PetResource) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if not PetManager.is_deployed:
		return
	_play_celebrate()

func _play_spawn_celebrate_once() -> void:
	if not _spawn_celebrate_pending:
		return
	_spawn_celebrate_pending = false
	_play_celebrate()

func _pet_sprite_has_playable_anim(an: StringName) -> bool:
	if anim == null or anim.sprite_frames == null:
		return false
	if not anim.sprite_frames.has_animation(an):
		return false
	return anim.sprite_frames.get_frame_count(an) > 0


func _play_celebrate() -> void:
	if _celebrating or anim == null or anim.sprite_frames == null:
		return
	_celebrating = true
	velocity = Vector2.ZERO
	var play_name := ""
	if _pet_sprite_has_playable_anim(&"happy"):
		play_name = "happy"
	elif _pet_sprite_has_playable_anim(&"spell"):
		play_name = "spell"
	else:
		play_name = _resolve_movement_anim(false)
	if play_name.is_empty():
		var names := anim.sprite_frames.get_animation_names()
		if names.size() > 0:
			play_name = names[0]
	if play_name.is_empty() or not _pet_sprite_has_playable_anim(StringName(play_name)):
		_celebrating = false
		return
	anim.play(StringName(play_name))
	await get_tree().create_timer(1.05).timeout
	_celebrating = false
	if is_instance_valid(self) and anim:
		_update_visual()
