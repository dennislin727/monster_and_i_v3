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
var is_dead: bool = false
var last_dir_str: String = "down"

func _ready() -> void:
	update_visuals()
	if Engine.is_editor_hint(): return
	
	add_to_group("monsters")
	if data and health:
		health.max_hp = data.max_hp
		health.current_hp = data.max_hp
		health.died.connect(_on_died)
		if health_bar: health_bar.setup(health)
	
	# 🔴 啟動狀態機
	state_machine.init(self)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_dead: return
	
	# 更新冷卻
	for s in skill_cds.keys():
		if skill_cds[s] > 0: skill_cds[s] -= delta
	
	# 🔴 處理血條顯示 (戰鬥中才顯示)
	if target_player:
		health_bar.modulate.a = move_toward(health_bar.modulate.a, 1.0, delta * 2)
	else:
		health_bar.modulate.a = move_toward(health_bar.modulate.a, 0.0, delta)
	
	move_and_slide()

# --- 輔助工具 ---

func play_monster_animation(anim_name: String):
	var target = anim_name
	if not anim.sprite_frames.has_animation(target):
		var base = anim_name.split("_")[0]
		target = base if anim.sprite_frames.has_animation(base) else "idle_down"
	if anim.animation != target or not anim.is_playing():
		anim.play(target)

func get_dir_string() -> String:
	var ref = velocity
	if target_player: ref = target_player.global_position - global_position
	if ref.length() < 5: return last_dir_str
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

# 當被打時，由 HealthComponent 呼叫
func play_hit_animation(_is_final: bool):
	if is_dead: return
	target_player = get_tree().get_first_node_in_group("player")
	# 🔴 強制切換到受傷狀態
	state_machine.change_state($StateMachine/Hurt)

func _get_available_skill() -> SkillResource:
	if not data or data.skills.is_empty(): return null
	var hp_pct = float(health.current_hp) / health.max_hp
	for s in data.skills:
		if s and skill_cds.get(s, 0) <= 0 and hp_pct <= s.max_hp_pct:
			return s
	return null

# 還有這個用於瞬移的函數 (SpellState 會呼叫它)
func _perform_ghost_dash(dist: float):
	if not target_player: return
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
