# res://src腳本/entities/monsters/MonsterBase.gd
@tool
class_name MonsterBase
extends CharacterBody2D

# --- 1. 數據中心 ---
@export var data: MonsterResource:
	set(value):
		data = value
		update_visuals()

@export_group("工具")
@export var force_refresh: bool = false:
	set(_v): update_visuals()

# --- 2. 組件引用 ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var state_machine: MonsterStateMachine = $StateMachine
@onready var health_bar: TextureProgressBar = get_node_or_null("UIAnchor/HealthBar")
@onready var accessory_point: Marker2D = get_node_or_null("AccessoryPoint")

# --- 3. 共享數據庫 ---
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
	
	# 初始化生命值
	if data and health:
		health.max_hp = data.max_hp
		health.current_hp = data.max_hp
		# 🔴 核心修正：連結死亡邏輯
		health.died.connect(_on_died)
		if health_bar:
			health_bar.setup(health)
	
	# 啟動狀態機
	if state_machine:
		state_machine.init(self)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_dead: return
	
	# 更新冷卻
	for s in skill_cds.keys():
		if skill_cds[s] > 0: skill_cds[s] -= delta
		
	# 執行物理移動
	move_and_slide()
	
	# 處理血條淡入淡出 (戰鬥中才顯示)
	if health_bar:
		var target_a = 1.0 if target_player != null else 0.0
		health_bar.modulate.a = move_toward(health_bar.modulate.a, target_a, delta * 2.0)
	
	if attack_cd_timer > 0:
		attack_cd_timer -= delta

# --- 狀態機專用工具 ---

func play_monster_animation(anim_prefix: String):
	if not anim or not anim.sprite_frames: return
	var dir = get_dir_string()
	var target = anim_prefix + "_" + dir
	if not anim.sprite_frames.has_animation(target):
		target = anim_prefix if anim.sprite_frames.has_animation(anim_prefix) else "idle_down"
	
	if anim.animation != target or not anim.is_playing():
		anim.play(target)
		if dir == "side":
			_handle_side_flip()

func get_dir_string() -> String:
	var ref_vector = velocity
	if target_player and (velocity.length() < 10):
		ref_vector = target_player.global_position - global_position
	if ref_vector.length() < 2: return last_dir_str
	var x = abs(ref_vector.x); var y = abs(ref_vector.y)
	last_dir_str = ("down" if ref_vector.y > 0 else "up") if y > x * 1.3 else "side"
	return last_dir_str

func get_available_skill() -> SkillResource:
	if not data or data.skills.is_empty(): return null
	var hp_percent = float(health.current_hp) / health.max_hp
	for s in data.skills:
		if s and skill_cds.get(s, 0) <= 0 and hp_percent <= s.max_hp_pct:
			return s
	return null

func _handle_side_flip():
	var look_dir = velocity.x
	if target_player: look_dir = target_player.global_position.x - global_position.x
	if look_dir != 0: anim.flip_h = (look_dir > 0)

# --- 戰鬥接口 ---

func play_hit_animation(_is_final: bool):
	if is_dead: return
	# 打到就記仇
	target_player = get_tree().get_first_node_in_group("player")
	# 🔴 被打時強行進入 Hurt 狀態
	if state_machine:
		state_machine.change_to("Hurt")

func _on_died():
	if is_dead: return
	is_dead = true
	print("[Monster] %s 已死亡，切換至 Die 狀態" % name)
	if state_machine:
		state_machine.change_to("Die")

# --- 視覺與奧義工具 ---

func update_visuals():
	var s = get_node_or_null("AnimatedSprite2D")
	if s and data and data.sprite_frames:
		s.sprite_frames = data.sprite_frames
		s.play("idle_down")
	if has_node("AccessoryPoint") and data:
		$AccessoryPoint.position = data.accessory_offset

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
