# res://src腳本/entities/monsters/MonsterBase.gd
@tool
class_name MonsterBase
extends CharacterBody2D

<<<<<<< HEAD
enum State { IDLE, WANDER, CHASE, ATTACK, SPELL, HURT, DIE, FLEE }
var current_state: int = State.IDLE

@export var data: MonsterResource:
	set(value):
		data = value
		update_visuals()

@export_group("工具")
@export var force_refresh: bool = false:
	set(_v): update_visuals()
=======
# --- 1. 狀態定義 ---
enum State { IDLE, WANDER, CHASE, ATTACK, SPELL, HURT, DIE, SEALED }
var current_state: int = State.IDLE
>>>>>>> 7b075d86e301c5e59bc262ee2693a51f1efe938d

# --- 2. 數據驅動中心 ---
@export var data: MonsterResource:
	set(value):
		data = value
		update_visuals()

@export_group("工具")
@export var force_refresh: bool = false:
	set(_v): update_visuals()

# --- 3. 組件引用 ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
<<<<<<< HEAD
@onready var health_bar: TextureProgressBar = get_node_or_null("UIAnchor/HealthBar")

=======
@onready var health_bar: TextureProgressBar = get_node_or_null("UIAnchor/TextureProgressBar")
@onready var accessory_point: Marker2D = get_node_or_null("AccessoryPoint")

# --- 4. AI 與 戰鬥變數 ---
>>>>>>> 7b075d86e301c5e59bc262ee2693a51f1efe938d
var target_player: PlayerController = null
var skill_cds: Dictionary = {} 
var state_timer: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
<<<<<<< HEAD
var last_dir_str: String = "down"
var is_dead: bool = false

# 戰鬥計時器
var combat_timer: float = 0.0
const COMBAT_TIMEOUT: float = 5.0

func _ready() -> void:
	update_visuals()
	if Engine.is_editor_hint(): return 
	add_to_group("monsters")
	if data and health:
		health.max_hp = data.max_hp
		health.current_hp = data.max_hp
		health.died.connect(_on_died)
		if health_bar: health_bar.setup(health)
	_start_idle()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_dead: return
	if not data: return
	
	# 更新 CD
	for s in skill_cds.keys():
		if skill_cds[s] > 0: skill_cds[s] -= delta
		
	# 血條顯示邏輯
	if combat_timer > 0:
		combat_timer -= delta
		if health_bar: health_bar.modulate.a = move_toward(health_bar.modulate.a, 1.0, delta * 2.0)
	else:
		if health_bar: health_bar.modulate.a = move_toward(health_bar.modulate.a, 0.0, delta * 1.0)
	
	# 🔴 核心修正：如果正在施法或受傷，不執行 AI 決策與移動
	if current_state in [State.SPELL, State.HURT, State.ATTACK]:
		move_and_slide() # 僅處理剩餘慣性，不獲取新速度
		return 

	_update_ai_logic(delta)
	_ensure_animation_logic()
	move_and_slide()


func _update_ai_logic(delta: float) -> void:
	# 1. 偵測玩家 (維持被動/主動邏輯)
	var p = get_tree().get_first_node_in_group("player")
	if p:
		var dist = global_position.distance_to(p.global_position)
		if dist < data.detection_range:
			# 只有主動怪或被打過的怪會鎖定
			if data.aggro_type == MonsterResource.AggroType.AGGRESSIVE or target_player != null:
				target_player = p
				combat_timer = COMBAT_TIMEOUT # 🔴 只要玩家在附近，就維持血條顯示
		elif dist > data.detection_range * 2.5:
			target_player = null

	var hp_pct = float(health.current_hp) / health.max_hp

	# 2. 狀態機
	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 10.0)
			state_timer -= delta
			if state_timer <= 0: _start_wander()
			if target_player: current_state = State.CHASE
			
		State.WANDER:
			velocity = wander_dir * data.move_speed
			state_timer -= delta
			if state_timer <= 0: _start_idle()
			if target_player: current_state = State.CHASE

		State.CHASE:
			if not target_player: 
				_start_idle()
				return
			
			# 檢查技能
			var skill = _get_available_skill()
			if skill and hp_pct < skill.max_hp_pct:
				_execute_skill_sequence(skill)
				return

			if hp_pct < 0.2:
				current_state = State.FLEE
				return

			var dist = global_position.distance_to(target_player.global_position)
			if dist <= data.attack_range:
				_perform_attack() # 🔴 進入攻擊
			else:
				velocity = (target_player.global_position - global_position).normalized() * data.chase_speed

		State.FLEE:
			if not target_player: 
				_start_idle()
				return
			var skill = _get_available_skill()
			if skill: 
				_execute_skill_sequence(skill)
				return
			velocity = (global_position - target_player.global_position).normalized() * data.chase_speed * 1.1

		State.SPELL, State.ATTACK, State.HURT:
			velocity = Vector2.ZERO

func _perform_attack():
	if current_state == State.ATTACK: return
	current_state = State.ATTACK # 🔴 鎖定狀態
	
	var dir = _get_current_dir_string()
	play_monster_animation("attack_" + dir)
	
	# 傷害判定
	await get_tree().create_timer(0.3).timeout
	if target_player and global_position.distance_to(target_player.global_position) < data.attack_range + 25:
		target_player.take_damage(10)
	
	# 🔴 等待動畫播完才切換回追擊
	if anim.is_playing():
		await anim.animation_finished
	
	current_state = State.CHASE

# 🔴 終極奧義序列：確保每個階段都有對應動畫與等待
func _execute_skill_sequence(skill: SkillResource):
	current_state = State.SPELL
	velocity = Vector2.ZERO # 🔴 施法開始，立刻停下
	skill_cds[skill] = skill.cooldown
	
	var dir = _get_current_dir_string()
	
	# 1. 瞬移
	if skill.dash_before_skill and target_player:
		await _perform_ghost_dash(skill.dash_distance)
	
	# 2. 蓄力階段 (Idle 喘氣)
	# 🔴 修正：瞬移後「必須」先播 idle，並等待資源設定的 startup_time
	play_monster_animation("idle_" + dir)
	print("[Monster] 奧義蓄力中，時長: ", skill.startup_time)
	await get_tree().create_timer(skill.startup_time).timeout
	
	# 3. 真正施法動畫
	play_monster_animation(skill.animation_name)
	
	# 4. 觸發效果 (等待資源設定的 trigger_delay)
	await get_tree().create_timer(skill.trigger_delay).timeout
	_apply_skill_effect(skill)
	
	# 5. 等待動畫播完
	if anim.is_playing():
		await anim.animation_finished
		
	# 6. 收招階段 (Idle 喘氣)
	play_monster_animation("idle_" + dir)
	print("[Monster] 奧義收招中，時長: ", skill.recovery_time)
	await get_tree().create_timer(skill.recovery_time).timeout
	
	# 🔴 結束後才回到追擊
	current_state = State.CHASE

func _perform_ghost_dash(dist: float):
	var dash_dir = (global_position - target_player.global_position).normalized().rotated(randf_range(-0.5, 0.5))
	var target_pos = global_position + dash_dir * dist
	var t = create_tween().set_parallel(true)
	t.tween_property(anim, "scale", Vector2(1.8, 0.1), 0.15)
	t.tween_property(anim, "modulate:a", 0.0, 0.15)
	await t.finished
	global_position = target_pos
	var t2 = create_tween().set_parallel(true)
	t2.tween_property(anim, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)
	t2.tween_property(anim, "modulate:a", 1.0, 0.1)
	await t2.finished

func _apply_skill_effect(skill: SkillResource):
	if skill.type == SkillResource.SkillType.HEAL:
		health.current_hp += skill.power

func play_hit_animation(is_final: bool):
	if is_final or is_dead: return
	current_state = State.HURT
	combat_timer = COMBAT_TIMEOUT # 🔴 被打時重置血條計時
	target_player = get_tree().get_first_node_in_group("player")
	play_monster_animation("hit_" + _get_current_dir_string())
	modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.2).timeout
	modulate = Color.WHITE
	current_state = State.CHASE

func _ensure_animation_logic():
	# 🔴 如果正在攻擊或施法，不准動動畫
	if current_state in [State.ATTACK, State.SPELL, State.HURT, State.DIE]: return
	
	var dir = _get_current_dir_string()
	var prefix = "idle_" if (current_state == State.IDLE or velocity.length() < 5) else "run_"
	play_monster_animation(prefix + dir)
	if dir == "side":
		if velocity.x != 0: anim.flip_h = (velocity.x > 0)
		elif target_player: anim.flip_h = (target_player.global_position.x > global_position.x)

func play_monster_animation(anim_name: String):
	if not anim or not anim.sprite_frames: return
	var target = anim_name
	if not anim.sprite_frames.has_animation(target):
		var base = anim_name.split("_")[0]
		if anim.sprite_frames.has_animation(base): target = base
		else: target = "idle_down"
	if anim.animation != target or not anim.is_playing():
		anim.play(target)

func _get_current_dir_string() -> String:
	var ref = velocity
	if target_player and current_state == State.CHASE: ref = target_player.global_position - global_position
	if ref.length() < 2: return last_dir_str
	var x = abs(ref.x); var y = abs(ref.y)
	last_dir_str = ("down" if ref.y > 0 else "up") if y > x * 1.3 else "side"
	return last_dir_str

func update_visuals():
	var s = get_node_or_null("AnimatedSprite2D")
	if s and data and data.sprite_frames:
		s.sprite_frames = data.sprite_frames
		s.play("idle_down")

func _on_died():
	is_dead = true
	anim.play("die")
	await anim.animation_finished
	queue_free()
=======
var is_dead: bool = false

# --- 5. 初始化 ---

func _ready() -> void:
	update_visuals()
	
	if Engine.is_editor_hint(): return 
	
	add_to_group("monsters")
	
	if data and health:
		health.max_hp = data.max_hp
		health.current_hp = data.max_hp
		health.died.connect(_on_died)
		if health_bar and health_bar.has_method("setup"):
			health_bar.setup(health)
	
	_start_idle()

# --- 6. 物理與邏輯循環 ---

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_dead: return
	if not data: return
	
	# 更新技能冷卻
	for s in skill_cds.keys():
		if skill_cds[s] > 0: skill_cds[s] -= delta
	
	_update_ai_logic(delta)
	move_and_slide()

func _update_ai_logic(delta: float) -> void:
	if not target_player:
		var p = get_tree().get_first_node_in_group("player")
		if p and global_position.distance_to(p.global_position) < data.detection_range:
			if data.aggro_type == MonsterResource.AggroType.AGGRESSIVE:
				target_player = p

	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 10.0)
			play_monster_animation("idle")
			state_timer -= delta
			if state_timer <= 0: _start_wander()
			if target_player: current_state = State.CHASE
			
		State.WANDER:
			velocity = wander_dir * data.move_speed
			play_monster_animation("run")
			if velocity.x != 0: anim.flip_h = velocity.x > 0
			state_timer -= delta
			if state_timer <= 0: _start_idle()
			if target_player: current_state = State.CHASE

		State.CHASE:
			if not target_player: 
				_start_idle()
				return
				
			var dist = global_position.distance_to(target_player.global_position)
			
			var skill = _get_available_skill()
			if skill:
				_perform_skill(skill)
				return

			if dist <= data.attack_range:
				_perform_attack()
			else:
				velocity = (target_player.global_position - global_position).normalized() * data.chase_speed
				play_monster_animation("run")
				if velocity.x != 0: anim.flip_h = velocity.x > 0

		State.SEALED:
			velocity = Vector2.ZERO
			anim.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))

# --- 7. AI 動作控制 ---

func _start_idle() -> void:
	current_state = State.IDLE
	state_timer = randf_range(2.0, 4.0)

func _start_wander() -> void:
	current_state = State.WANDER
	state_timer = randf_range(0.8, 1.8)
	wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
>>>>>>> 7b075d86e301c5e59bc262ee2693a51f1efe938d

func _get_available_skill() -> SkillResource:
	if not data or data.skills.is_empty(): return null
	var hp_pct = float(health.current_hp) / health.max_hp
	for s in data.skills:
<<<<<<< HEAD
		if s and skill_cds.get(s, 0) <= 0 and hp_pct <= s.max_hp_pct:
			return s
	return null

func _start_idle():
	current_state = State.IDLE
	state_timer = randf_range(2.0, 4.0)

func _start_wander():
	current_state = State.WANDER
	state_timer = randf_range(0.8, 1.8)
	wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
=======
		if skill_cds.get(s, 0) <= 0 and hp_pct >= s.min_hp_pct and hp_pct <= s.max_hp_pct:
			return s
	return null

# 🔴 核心修復：補齊遺失的技能執行邏輯
func _perform_skill(skill: SkillResource) -> void:
	current_state = State.SPELL
	velocity = Vector2.ZERO
	skill_cds[skill] = skill.cooldown
	
	play_monster_animation(skill.animation_name)
	print("[Monster] 施放技能: ", skill.skill_name)
	
	# 等待動畫播完 (例如你畫的 spell 動畫)
	await anim.animation_finished
	
	if skill.type == SkillResource.SkillType.HEAL:
		health.current_hp += skill.power
		print("[Monster] 治癒成功，恢復 HP 至: ", health.current_hp)
		
	current_state = State.CHASE

# 🔴 核心修復：補齊遺失的攻擊邏輯
func _perform_attack() -> void:
	current_state = State.ATTACK
	velocity = Vector2.ZERO
	
	var dir_str = _get_dir_to_target(target_player.global_position)
	play_monster_animation("attack_" + dir_str)
	
	# 這裡可以加入一個 Timer 在特定影格對玩家造成傷害
	await anim.animation_finished
	current_state = State.CHASE

# --- 8. 視覺與動畫系統 ---

func update_visuals() -> void:
	var s = get_node_or_null("AnimatedSprite2D")
	var m = get_node_or_null("AccessoryPoint")
	if s and data and data.sprite_frames:
		s.sprite_frames = data.sprite_frames
		if s.sprite_frames.has_animation("idle"):
			s.play("idle")
	if m and data:
		m.position = data.accessory_offset

func play_monster_animation(anim_name: String) -> void:
	if not anim or not anim.sprite_frames: return
	
	var target_anim = anim_name
	# 動畫退路：如果找不到方向性動畫，找通用動畫
	if not anim.sprite_frames.has_animation(target_anim):
		var base_name = anim_name.split("_")[0]
		if anim.sprite_frames.has_animation(base_name):
			target_anim = base_name
		else:
			return 

	if anim.animation != target_anim:
		anim.play(target_anim)

func _get_dir_to_target(target_pos: Vector2) -> String:
	var diff = target_pos - global_position
	if abs(diff.y) > abs(diff.x) * 1.5:
		return "down" if diff.y > 0 else "up"
	return "side"

# --- 9. 外部事件與受擊 ---

func play_hit_animation(is_final: bool) -> void:
	if is_final or is_dead: return
	
	current_state = State.HURT
	# 記仇邏輯
	target_player = get_tree().get_first_node_in_group("player")
	
	var dir_str = _get_dir_to_target(target_player.global_position)
	play_monster_animation("hit_" + dir_str)
	
	var t = create_tween()
	modulate = Color(10, 10, 10)
	t.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	await t.finished
	if current_state == State.HURT:
		current_state = State.CHASE

func on_sealed_start() -> void:
	current_state = State.SEALED
	modulate = Color(0, 1, 1)

func on_sealed_cancel() -> void:
	current_state = State.IDLE
	modulate = Color.WHITE
	anim.offset = Vector2.ZERO

# 🔴 核心修復：補齊遺失的死亡與掉落邏輯
func _on_died() -> void:
	if is_dead: return
	is_dead = true
	current_state = State.DIE
	velocity = Vector2.ZERO
	
	play_monster_animation("die")
	print("[Monster] 我掛了...")
	
	# 處理掉落物
	if data and data.drop_item:
		if randf() <= data.drop_chance:
			SignalBus.request_effect_collect.emit(global_position, data.drop_item.icon)
			SignalBus.item_collected.emit(data.drop_item)
			print("[Monster] 掉落了：", data.drop_item.display_name)
		
	await anim.animation_finished
	queue_free()
>>>>>>> 7b075d86e301c5e59bc262ee2693a51f1efe938d
