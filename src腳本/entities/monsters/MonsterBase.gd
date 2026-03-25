# res://src腳本/entities/monsters/MonsterBase.gd
@tool
class_name MonsterBase
extends CharacterBody2D

@export var data: MonsterResource:
	set(value):
		data = value
		update_visuals()

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var state_machine: MonsterStateMachine = $StateMachine
@onready var health_bar: TextureProgressBar = get_node_or_null("UIAnchor/HealthBar")

var target_player: PlayerController = null
var skill_cds: Dictionary = {}
var wander_dir: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var last_dir_str: String = "down"
var is_dead: bool = false
var attack_cd_timer: float = 0.0
# 🔴 新增：霸體護盾開關
var is_casting_protected: bool = false 

func _ready() -> void:
	update_visuals()
	if Engine.is_editor_hint(): return
	add_to_group("monsters")
	if data and health:
		health.max_hp = data.max_hp
		health.current_hp = data.max_hp
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)
		if health_bar: health_bar.setup(health)
	if state_machine: state_machine.init(self)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_dead: return
	
	for s in skill_cds.keys(): if skill_cds[s] > 0: skill_cds[s] -= delta
	if attack_cd_timer > 0: attack_cd_timer -= delta
	
	move_and_slide()

	if health_bar:
		var should_show = target_player != null or health.current_hp < health.max_hp
		health_bar.modulate.a = move_toward(health_bar.modulate.a, 1.0 if should_show else 0.0, delta * 2.0)

# 根據當前狀態決定轉向邏輯
func play_monster_animation(anim_name: String):
	if not anim or not anim.sprite_frames: return
	var dir = get_dir_string()
	var target = anim_name
	
	if anim.sprite_frames.has_animation(anim_name + "_" + dir):
		target = anim_name + "_" + dir
	elif anim.sprite_frames.has_animation(anim_name):
		target = anim_name
	
	if anim.animation != target:
		anim.play(target)
		
	if "side" in target:
		var current_state_name = ""
		if state_machine and state_machine.current_state:
			current_state_name = state_machine.current_state.name
			
		var look_x = 0.0
		
		if current_state_name in ["Flee", "Wander"]:
			look_x = velocity.x
		elif current_state_name in ["Chase", "Attack", "Spell", "Hurt"]:
			if target_player:
				look_x = target_player.global_position.x - global_position.x
			else:
				look_x = velocity.x
		else:
			look_x = velocity.x if velocity.length() > 5 else (target_player.global_position.x - global_position.x if target_player else 0.0)
			
		if look_x != 0:
			anim.flip_h = (look_x > 0)

func get_dir_string() -> String:
	var ref = velocity
	if target_player and velocity.length() < 10: ref = target_player.global_position - global_position
	if ref.length() < 2: return last_dir_str
	if abs(ref.y) > abs(ref.x) * 1.3: last_dir_str = "down" if ref.y > 0 else "up"
	else: last_dir_str = "side"
	return last_dir_str

func play_hit_animation(_is_final: bool):
	if is_dead: return
	
	# 🔴 核心修復：施法護盾判定
	# 如果正在霸體狀態
	if is_casting_protected:
		var p = get_tree().get_first_node_in_group("player")
		if p:
			# 1. 彈開物理位移
			var bounce_dir = (p.global_position - global_position).normalized()
			var t = create_tween()
			t.tween_property(p, "global_position", p.global_position + bounce_dir * 50, 0.15)\
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			
			# 2. 觸發主角平常的受擊演繹 (傳入 0 傷害)
			p.take_damage(0)
			
		return # 史萊姆不進入受傷狀態 

	target_player = get_tree().get_first_node_in_group("player")
	if state_machine.current_state.name in ["Spell", "Die"]: return
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

func update_visuals():
	if data and data.sprite_frames:
		$AnimatedSprite2D.sprite_frames = data.sprite_frames
		$AnimatedSprite2D.play("idle_down")

func perform_ghost_dash(dist: float):
	if is_dead: return
	var dash_dir = (global_position - target_player.global_position).normalized().rotated(randf_range(-0.5, 0.5))
	var t = create_tween().set_parallel(true)
	t.tween_property(anim, "scale", Vector2(1.8, 0.1), 0.15)
	t.tween_property(anim, "modulate:a", 0.0, 0.15)
	await t.finished
	if is_dead: return
	global_position += dash_dir * dist
	var t2 = create_tween().set_parallel(true)
	t2.tween_property(anim, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)
	t2.tween_property(anim, "modulate:a", 1.0, 0.1)
	await t2.finished

func is_targetable() -> bool:
	return not is_dead and is_instance_valid(self)
