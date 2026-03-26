# res://src腳本/entities/pets/PetCompanion.gd
extends CharacterBody2D

var _data: PetResource
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var health_bar: ProgressBar = $UIAnchor/HealthBar

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

## 動畫鎖：attack / spell 播放時不被 run/idle 覆蓋
var _anim_lock: float = 0.0
var _anim_restore: String = ""
var _heal_casting: bool = false
var _spawn_celebrate_pending: bool = true

const FOLLOW_LERP_WEIGHT := 0.1
const FOLLOW_ARRIVE_DISTANCE := 35.0
const VISUAL_RUN_ENTER_DIST := 42.0
const VISUAL_RUN_EXIT_DIST := 26.0
const BREADCRUMB_DELAY_SEC := 0.38
const BREADCRUMB_MAX_HISTORY_SEC := 3.0
const PLAYER_SPEED_MOVE_ENTER := 20.0
const PLAYER_SPEED_MOVE_EXIT := 8.0
const ROAM_REPICK_MIN_SEC := 6.5
const ROAM_REPICK_MAX_SEC := 11.0
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

const PET_HEAL_STARTUP_SEC := 0.0
const PET_HEAL_TRIGGER_FALLBACK := 0.25

func setup(pet_data: PetResource) -> void:
	_data = pet_data
	_reset_breadcrumb_trail()

func _ready() -> void:
	add_to_group("deployed_pet")
	collision_layer = 0
	collision_mask = 0
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _data:
		_apply_pet_resource(_data)
	if health and not health.died.is_connected(_on_pet_died):
		health.died.connect(_on_pet_died)
	if health_bar and health:
		health_bar.setup(health)
	if not SignalBus.player_melee_hit.is_connected(_on_player_melee_hit):
		SignalBus.player_melee_hit.connect(_on_player_melee_hit)
	if not SignalBus.pet_captured.is_connected(_on_peer_pet_captured):
		SignalBus.pet_captured.connect(_on_peer_pet_captured)
	# 出戰召喚完成後播一次短慶祝（deferred 避免與初始動畫設定同幀互搶）
	call_deferred("_play_spawn_celebrate_once")

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

func _resolve_sprite_frames(d: PetResource) -> SpriteFrames:
	if d.sprite_frames:
		return d.sprite_frames
	# 後備：依 pet_id 嘗試對應怪物 .tres（與專案命名一致時可直接配對）
	if d.pet_id.is_empty():
		return _fallback_slime_sprite_frames()
	var path := "res://src腳本/resources身分證/monster/%s.tres" % d.pet_id
	if ResourceLoader.exists(path):
		var mres := load(path) as MonsterResource
		if mres and mres.sprite_frames:
			return mres.sprite_frames
	return _fallback_slime_sprite_frames()

func _fallback_slime_sprite_frames() -> SpriteFrames:
	var mres := load("res://src腳本/resources身分證/monster/slime_green.tres") as MonsterResource
	if mres:
		return mres.sprite_frames
	return null

func _physics_process(delta: float) -> void:
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
	if _combat_sticky > 0.0:
		_combat_sticky -= delta
	if _combat_attack_cd > 0.0:
		_combat_attack_cd -= delta
	_update_combat(delta)
	_update_follow_position(delta)
	_try_heal(delta)
	move_and_slide()
	_update_visual()

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
	_anim_lock = 0.0
	_anim_restore = ""
	_heal_casting = false

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

func _update_combat(_delta: float) -> void:
	if _combat_target != null and not is_instance_valid(_combat_target):
		_combat_disengage()
		return
	if not _combat_active():
		return
	var tp := _combat_target_pos()
	if _player:
		var d_player := _player.global_position.distance_to(tp)
		if d_player > PET_DISENGAGE_DIST:
			_combat_disengage()
			return
	# 追到怪身邊一點點（可日後做 orbit/坦克站位）
	var dist := global_position.distance_to(tp)
	if dist > PET_ATTACK_RANGE:
		var dir := (tp - global_position).normalized()
		var spd: float = GlobalBalance.PET_FOLLOW_SPEED * (_data.follow_speed_mult if _data else 1.1)
		velocity = velocity.lerp(dir * spd, FOLLOW_LERP_WEIGHT)
		return
	# 已在攻擊距離內：嘗試普攻
	if _combat_attack_cd > 0.0:
		return
	_lock_anim_for(PET_ATTACK_LOCK_SEC)
	_play_pet_animation("attack", tp - global_position)
	_combat_attack_cd = PET_AUTO_ATTACK_CD
	_combat_target.take_damage(GlobalBalance.PET_MELEE_DAMAGE)

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
		# 戰鬥中移動交由 _update_combat；這裡只維持距離數值與視覺參考
		_dist_to_follow_slot = 999.0
		return
	_trail_clock += delta
	_trail_push_sample(_player.global_position, _trail_clock)
	var trail_target: Vector2 = _trail_sample_at_time(_trail_clock - BREADCRUMB_DELAY_SEC)
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
		target = trail_target
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
		target = _player.global_position + _roam_offset
	_dist_to_follow_slot = global_position.distance_to(target)
	var spd: float = GlobalBalance.PET_FOLLOW_SPEED * (_data.follow_speed_mult if _data else 1.1)
	if _dist_to_follow_slot > FOLLOW_ARRIVE_DISTANCE:
		var dir_v := (target - global_position).normalized()
		var target_vel := dir_v * spd
		velocity = velocity.lerp(target_vel, FOLLOW_LERP_WEIGHT)
	else:
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
	if _anim_lock > 0.0:
		return
	_last_dir = _player.get_dir_string() if _player else _last_dir
	if _dist_to_follow_slot > VISUAL_RUN_ENTER_DIST:
		_visual_is_running = true
	elif _dist_to_follow_slot < VISUAL_RUN_EXIT_DIST:
		_visual_is_running = false
	var anim_name := _resolve_movement_anim(_visual_is_running)
	if anim_name.is_empty():
		return
	if anim.animation != anim_name:
		anim.play(anim_name)
	if anim_name.ends_with("side") and _player:
		anim.flip_h = (_player.last_direction.x > 0)

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
	# 進入/刷新戰鬥：主角拉打時仍持續作戰，直到脫戰距離或計時歸零
	_combat_target = hb
	_combat_sticky = PET_COMBAT_STICKY_SEC
	hb.take_damage(GlobalBalance.PET_MELEE_DAMAGE)

func _try_heal(delta: float) -> void:
	if _celebrating:
		return
	if _heal_casting:
		return
	_heal_cd -= delta
	if _heal_cd > 0.0:
		return
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null or _player.health == null:
		return
	if _player.health.current_hp >= _player.health.max_hp:
		return
	var amt: int = _data.heal_amount if _data and _data.heal_amount > 0 else GlobalBalance.PET_HEAL_AMOUNT
	var cd: float = _data.heal_cooldown if _data and _data.heal_cooldown > 0.0 else GlobalBalance.PET_HEAL_COOLDOWN
	_heal_cd = cd
	_cast_heal_spell(amt)

func _resolve_heal_trigger_delay() -> float:
	# 對齊史萊姆怪物技能：res://src腳本/resources身分證/skill/skill_slime_heal.tres (trigger_delay=1.06)
	if _data and _data.pet_id == "slime_green":
		var s := load("res://src腳本/resources身分證/skill/skill_slime_heal.tres") as SkillResource
		if s:
			return s.trigger_delay
	return PET_HEAL_TRIGGER_FALLBACK

func _cast_heal_spell(amount: int) -> void:
	if _heal_casting:
		return
	if _player == null or _player.health == null:
		return
	_heal_casting = true
	var prev: StringName = &""
	if anim:
		prev = anim.animation
	if anim and anim.sprite_frames:
		if prev.is_empty() or not anim.sprite_frames.has_animation(prev):
			prev = StringName(_resolve_movement_anim(_visual_is_running))
	var dur := _get_anim_duration_sec(&"spell")
	if dur <= 0.0:
		dur = 0.55
	var trigger_delay := _resolve_heal_trigger_delay()
	_lock_anim_for(dur + 0.06)
	_anim_restore = String(prev)
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("spell"):
		anim.play("spell")
	if PET_HEAL_STARTUP_SEC > 0.0:
		await get_tree().create_timer(PET_HEAL_STARTUP_SEC).timeout
	await get_tree().create_timer(trigger_delay).timeout
	if not is_instance_valid(self) or _player == null or _player.health == null:
		_heal_casting = false
		return
	_player.health.heal(amount)
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
	SignalBus.pet_recall_requested.emit()

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

func _play_celebrate() -> void:
	if _celebrating or anim == null or anim.sprite_frames == null:
		return
	_celebrating = true
	velocity = Vector2.ZERO
	var play_name := ""
	if anim.sprite_frames.has_animation("happy") and anim.sprite_frames.get_frame_count("happy") > 0:
		play_name = "happy"
	elif anim.sprite_frames.has_animation("spell") and anim.sprite_frames.get_frame_count("spell") > 0:
		play_name = "spell"
	else:
		play_name = _resolve_movement_anim(false)
	if play_name.is_empty():
		var names := anim.sprite_frames.get_animation_names()
		if names.size() > 0:
			play_name = names[0]
	if play_name.is_empty():
		_celebrating = false
		return
	anim.play(play_name)
	await get_tree().create_timer(1.05).timeout
	_celebrating = false
	if is_instance_valid(self) and anim:
		_update_visual()
