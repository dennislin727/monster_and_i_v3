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

func _ready() -> void:
	update_visuals()
	if Engine.is_editor_hint(): return
	add_to_group("monsters")
	if data and health:
		health.max_hp = data.max_hp
		health.current_hp = data.max_hp
		# 🔴 核心修復：確保訊號有連上
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

func play_monster_animation(anim_name: String):
	if not anim or not anim.sprite_frames: return
	var dir = get_dir_string()
	var target = anim_name
	if anim.sprite_frames.has_animation(anim_name + "_" + dir):
		target = anim_name + "_" + dir
	elif not anim.sprite_frames.has_animation(anim_name):
		target = "idle_down"
	if anim.animation != target or not anim.is_playing():
		anim.play(target)
		if "side" in target:
			var look_x = velocity.x if velocity.length() > 5 else (target_player.global_position.x - global_position.x if target_player else 0.0)
			if look_x != 0: anim.flip_h = (look_x > 0)

func get_dir_string() -> String:
	var ref = velocity
	if target_player and velocity.length() < 10: ref = target_player.global_position - global_position
	if ref.length() < 2: return last_dir_str
	if abs(ref.y) > abs(ref.x) * 1.3: last_dir_str = "down" if ref.y > 0 else "up"
	else: last_dir_str = "side"
	return last_dir_str

func play_hit_animation(_is_final: bool):
	if is_dead: return
	if state_machine.current_state.name in ["Attack", "Spell"]: return
	target_player = get_tree().get_first_node_in_group("player")
	state_machine.change_to("Hurt")

# 🔴 核心修復：絕對死亡權限
func _on_died():
	if is_dead: return
	is_dead = true
	print("[Monster] 確定死亡，移除所有 AI 控制")
	# 關閉所有物理與狀態機
	set_physics_process(false)
	if state_machine:
		state_machine.set_physics_process(false)
		state_machine.change_to("Die")

func get_available_skill() -> SkillResource:
	if not data: return null
	var hp_pct = float(health.current_hp) / health.max_hp
	for s in data.skills:
		if s and skill_cds.get(s, 0) <= 0 and hp_pct <= s.max_hp_pct: return s
	return null

func update_visuals():
	var s = get_node_or_null("AnimatedSprite2D")
	if s and data and data.sprite_frames:
		s.sprite_frames = data.sprite_frames
		s.play("idle_down")

func perform_ghost_dash(dist: float):
	if not target_player: return
	var dash_dir = (global_position - target_player.global_position).normalized().rotated(randf_range(-0.5, 0.5))
	var t = create_tween().set_parallel(true)
	t.tween_property(anim, "scale", Vector2(1.8, 0.1), 0.15)
	t.tween_property(anim, "modulate:a", 0.0, 0.15)
	await t.finished
	global_position += dash_dir * dist
	var t2 = create_tween().set_parallel(true)
	t2.tween_property(anim, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)
	t2.tween_property(anim, "modulate:a", 1.0, 0.1)
	await t2.finished
