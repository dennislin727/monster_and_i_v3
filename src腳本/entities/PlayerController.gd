# res://src腳本/entities/PlayerController.gd
class_name PlayerController
extends CharacterBody2D

@export_group("移動與跳躍")
@export var move_speed: float = 200.0
@export var dash_distance: float = 150.0 
@export var dash_duration: float = 0.4  

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: Node = $StateMachine
@onready var interaction_detector: Area2D = $InteractionDetector

var last_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var is_seal_mode: bool = false
var is_attacking: bool = false
var is_hit_stun: bool = false # 受擊硬直鎖

var current_target: InteractableComponent = null
var current_enemy: HurtboxComponent = null

func _ready() -> void:
	if SignalBus.has_signal("dash_requested"):
		SignalBus.dash_requested.connect(perform_dash)
	add_to_group("player")
	for state in state_machine.get_children():
		state.player = self
	SignalBus.seal_mode_toggled.connect(func(enabled: bool): is_seal_mode = enabled)

func _physics_process(_delta: float) -> void:
	if is_dashing: return # 瞬移依然保持控制鎖
	
	# 🔴 允許移動：即使 is_hit_stun 為 true 也能獲取輸入
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Engine.time_scale < 1.0:
		velocity = Vector2.ZERO
	else:
		if input_dir != Vector2.ZERO:
			last_direction = input_dir.normalized()
			velocity = input_dir * move_speed
		else:
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 0.2)
	
	move_and_slide()
	
	# 🔴 核心修正：如果正在受擊，不准更新移動動畫，讓 hit 播完
	if is_hit_stun: return 

	if state_machine.current_state.name == "Move":
		update_animation_by_dir("idle_" if velocity == Vector2.ZERO else "run_")

func update_animation_by_dir(prefix: String) -> void:
	if is_hit_stun: return 
	update_flip()
	var anim_name = prefix + get_dir_string()
	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)

func update_flip() -> void:
	anim_sprite.flip_h = (last_direction.x > 0)

func get_dir_string() -> String:
	var x = abs(last_direction.x); var y = abs(last_direction.y)
	if y > x * 1.5: return "down" if last_direction.y > 0 else "up"
	elif x > y * 1.5: return "side"
	else: return "side_down" if last_direction.y > 0 else "side_up"

func take_damage(_amount: int):
	if is_hit_stun or is_dashing: return
	
	is_hit_stun = true
	# 🔴 不再將 velocity 設為 0，讓玩家可以繼續滑行
	
	anim_sprite.stop()
	anim_sprite.play("hit")
	anim_sprite.modulate = Color.RED
	
	# 🔴 極短硬直鎖定動畫，0.15秒後才准許切換回跑/待機
	await get_tree().create_timer(0.05).timeout
	var t = create_tween()
	t.tween_property(anim_sprite, "modulate", Color.WHITE, 0.1)
	
	await get_tree().create_timer(0.1).timeout
	is_hit_stun = false

func perform_dash() -> void:
	if is_dashing or is_hit_stun: return
	is_dashing = true
	var target_pos = global_position + (last_direction * dash_distance)
	var dash_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	dash_tween.tween_property(self, "global_position", target_pos, 0.5)
	anim_sprite.pause() 
	var jump_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(anim_sprite, "position:y", -80.0, 0.25)
	jump_tween.chain().set_ease(Tween.EASE_IN).tween_property(anim_sprite, "position:y", 0.0, 0.25)
	await dash_tween.finished
	is_dashing = false
	anim_sprite.play()

func _on_interaction_detector_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent: current_enemy = area
	elif area is InteractableComponent: current_target = area

func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if area == current_enemy: current_enemy = null
	elif area == current_target: current_target = null

func hit_current_target() -> void:
	if current_target: current_target.start_harvest()
	elif current_enemy: current_enemy.take_damage(10)
