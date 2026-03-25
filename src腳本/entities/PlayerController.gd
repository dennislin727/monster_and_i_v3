# res://src腳本/entities/PlayerController.gd
class_name PlayerController
extends CharacterBody2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: Node = $StateMachine
@onready var health: HealthComponent = $HealthComponent
# 🟢 修正：把相機抓出來
@onready var camera: Camera2D = $Camera2D 

var last_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var is_hit_stun: bool = false
var is_invincible: bool = false
var is_seal_mode: bool = false

var current_target: InteractableComponent = null
var current_enemy: HurtboxComponent = null

func _ready() -> void:
	add_to_group("player")
	# 初始化狀態機
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
		velocity = input_dir * GlobalBalance.PLAYER_SPEED 
	else:
		velocity = velocity.move_toward(Vector2.ZERO, GlobalBalance.PLAYER_FRICTION)
	
	move_and_slide()

# 🔴 受擊入口
func take_damage(amount: int):
	if is_invincible or is_dashing: return
	if amount > 0 and health.current_hp <= 0: return
	
	is_hit_stun = true
	is_invincible = true
	
	if amount > 0:
		health.take_damage(amount)
		SignalBus.damage_spawned.emit(global_position, amount, true)
	
	state_machine.change_state(state_machine.get_node("Hurt"))
	
	var t = create_tween().set_loops(2)
	t.tween_property(anim_sprite, "modulate:a", 0.1, 0.05)
	t.tween_property(anim_sprite, "modulate:a", 1.0, 0.05)
	
	await get_tree().create_timer(0.4).timeout
	is_hit_stun = false
	await get_tree().create_timer(0.6).timeout
	is_invincible = false

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

func hit_current_target() -> void:
	if current_enemy: current_enemy.take_damage(45)
	elif current_target: current_target.start_harvest()

func perform_dash():
	if is_dashing or is_hit_stun: return
	is_dashing = true
	is_invincible = true
	var t = create_tween()
	t.tween_property(self, "global_position", global_position + last_direction * GlobalBalance.PLAYER_DASH_DIST, 0.3)
	await t.finished
	is_dashing = false
	is_invincible = false

func _on_interaction_detector_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent: current_enemy = area
	elif area is InteractableComponent: current_target = area

func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if area == current_enemy: current_enemy = null
	elif area == current_target: current_target = null

# 🎨 結算動畫演出 (加上相機縮放)
func play_finish_animation(is_success: bool):
	is_seal_mode = false 
	var text_msg = "Gotcha!!" if is_success else "Fail..."
	
	# 🟢 成功時觸發相機縮放
	if is_success:
		_camera_impact_zoom()
	
	SignalBus.popup_text.emit(self, text_msg, Color.WHITE) 
	
	var anim_name = "happy" if is_success else "sad"
	anim_sprite.play(anim_name)
	velocity = Vector2.ZERO
	
	print("[Player] 執行結算動畫: ", anim_name)
	
	# 等待動畫撥完
	await get_tree().create_timer(1.2).timeout
	
	if anim_sprite.animation == anim_name:
		update_animation_by_dir("idle_")

# 🟢 內部私有函數：優雅的相機拉近演出
func _camera_impact_zoom():
	# 基礎 Zoom 是 1.4，我們拉到約 1.6
	var base_zoom = camera.zoom
	var target_zoom = base_zoom * 1.1
	
	var t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 1. 快速拉近 (0.2s)
	t.tween_property(camera, "zoom", target_zoom, 0.1)
	# 2. 停一秒讓冠冠的動畫被看清楚
	t.tween_interval(0.2)
	# 3. 慢慢恢復 (0.6s)
	t.chain().tween_property(camera, "zoom", base_zoom, 0.2)
