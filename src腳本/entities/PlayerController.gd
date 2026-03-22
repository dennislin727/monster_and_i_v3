# res://src腳本/entities/PlayerController.gd
class_name PlayerController
extends CharacterBody2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: Node = $StateMachine
@onready var health: HealthComponent = $HealthComponent

var last_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var is_hit_stun: bool = false
var is_invincible: bool = false
var is_seal_mode: bool = false
var current_target: InteractableComponent = null
var current_enemy: HurtboxComponent = null

func _ready() -> void:
	add_to_group("player")
	for state in state_machine.get_children():
		state.player = self
	SignalBus.seal_mode_toggled.connect(func(e): is_seal_mode = e)
	if SignalBus.has_signal("dash_requested"):
		SignalBus.dash_requested.connect(perform_dash)

func _physics_process(_delta: float) -> void:
	if is_hit_stun or is_dashing: return
	
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()
		velocity = input_dir * 200.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 40.0)
	
	move_and_slide()
	
	# 動畫控制權限
	if state_machine.current_state and state_machine.current_state.name == "Move":
		update_animation_by_dir("idle_" if velocity == Vector2.ZERO else "run_")

# 🔴 補回遺失的函數，解決 PlayerMoveState 的報錯
func update_flip() -> void:
	if last_direction.x != 0:
		anim_sprite.flip_h = (last_direction.x > 0)

func update_animation_by_dir(prefix: String) -> void:
	update_flip()
	var anim_name = prefix + get_dir_string()
	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)

func get_dir_string() -> String:
	if abs(last_direction.y) > abs(last_direction.x) * 1.5:
		return "down" if last_direction.y > 0 else "up"
	return "side"

func take_damage(amount: int):
	if is_invincible or is_dashing: return
	is_hit_stun = true; is_invincible = true
	if health: health.take_damage(amount)
	SignalBus.damage_spawned.emit(global_position, amount, true)
	anim_sprite.stop(); anim_sprite.play("hit")
	var t = create_tween().set_loops(4)
	t.tween_property(anim_sprite, "modulate:a", 0.3, 0.1)
	t.tween_property(anim_sprite, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(0.4).timeout
	is_hit_stun = false
	await get_tree().create_timer(0.4).timeout
	is_invincible = false

func hit_current_target() -> void:
	if current_enemy: current_enemy.take_damage(10)
	elif current_target: current_target.start_harvest()

func perform_dash():
	if is_dashing or is_hit_stun: return
	is_dashing = true
	var t = create_tween()
	t.tween_property(self, "global_position", global_position + last_direction * 150, 0.4)
	await t.finished
	is_dashing = false

func _on_interaction_detector_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent: current_enemy = area
	elif area is InteractableComponent: current_target = area

func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if area == current_enemy: current_enemy = null
	elif area == current_target: current_target = null
