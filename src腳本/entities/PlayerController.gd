# res://src腳本/entities/PlayerController.gd
class_name PlayerController
extends CharacterBody2D

@export var move_speed: float = 200.0
@export var dash_distance: float = 80.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: Node = $StateMachine

# 數據中心
var last_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var is_seal_mode: bool = false
var current_target: InteractableComponent = null
var current_enemy: HurtboxComponent = null

func _ready() -> void:
	if SignalBus.has_signal("dash_requested"):
		SignalBus.dash_requested.connect(perform_dash)
	add_to_group("player")
	
	# 初始化狀態機：讓每個狀態都知道誰是主角
	for state in state_machine.get_children():
		state.player = self
	
	SignalBus.seal_mode_toggled.connect(func(enabled: bool): is_seal_mode = enabled)

func _physics_process(_delta: float) -> void:
	if is_dashing: return
	
	# 基礎物理移動 (永遠在跑，除非封印模式)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if is_seal_mode:
		velocity = Vector2.ZERO
	else:
		if input_dir != Vector2.ZERO:
			last_direction = input_dir.normalized()
			velocity = input_dir * move_speed
		else:
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 0.2)
	
	move_and_slide()

# 提供給狀態機使用的工具函數
func get_dir_string() -> String:
	var x = abs(last_direction.x); var y = abs(last_direction.y)
	if y > x * 1.5: return "down" if last_direction.y > 0 else "up"
	elif x > y * 1.5: return "side"
	else: return "side_down" if last_direction.y > 0 else "side_up"

func update_flip() -> void:
	anim_sprite.flip_h = (last_direction.x > 0)

func perform_dash() -> void:
	if is_dashing: return
	is_dashing = true
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	anim_sprite.pause()
	tween.tween_property(self, "global_position", global_position + (last_direction * dash_distance), 0.1)
	await tween.finished
	is_dashing = false
	anim_sprite.play()

# 訊號接收：只負責紀錄目標
func _on_interaction_detector_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent: current_enemy = area
	elif area is InteractableComponent: current_target = area

func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if area == current_enemy: current_enemy = null
	elif area == current_target: current_target = null
