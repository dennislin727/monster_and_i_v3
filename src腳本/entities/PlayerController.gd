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
		# 🔴 把原本寫死的 200.0 換掉！
		velocity = input_dir * GlobalBalance.PLAYER_SPEED 
	else:
		velocity = velocity.move_toward(Vector2.ZERO, GlobalBalance.PLAYER_FRICTION)
	
	move_and_slide()

# 🔴 核心修正：統一受擊入口 (支援 0 傷害反震)
func take_damage(amount: int):
	# 如果是無敵/衝刺，或是血量已經歸零（且這是有傷害的攻擊），則無視
	if is_invincible or is_dashing: return
	if amount > 0 and health.current_hp <= 0: return
	
	is_hit_stun = true
	is_invincible = true
	
	# 🔴 只有傷害大於 0 時，才執行數據層面的扣血與噴字
	if amount > 0:
		health.take_damage(amount)
		SignalBus.damage_spawned.emit(global_position, amount, true)
	
	# 🔴 不管有沒有傷害，都要執行的視覺演繹：
	# 1. 切換到受傷狀態 (自動撥放 hit 動畫)
	state_machine.change_state(state_machine.get_node("Hurt"))
	
	# 2. 閃爍效果
	var t = create_tween().set_loops(2)
	t.tween_property(anim_sprite, "modulate:a", 0.1, 0.05)
	t.tween_property(anim_sprite, "modulate:a", 1.0, 0.05)
	
	# 3. 恢復機制
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
	# 🔴 把原本寫死的 150 換掉！
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

func play_finish_animation(is_success: bool):
	is_seal_mode = false 
	var text_msg = "Gotcha!!" if is_success else "Fail..."
	
	# 🟢 直接丟出 self
	SignalBus.popup_text.emit(self, text_msg, Color.WHITE) 
	
	var anim_name = "happy" if is_success else "sad"
	anim_sprite.play(anim_name)
	velocity = Vector2.ZERO
	
	print("[Player] 執行結算動畫: ", anim_name)
	
	# 等待動畫撥完 (假設動畫長度約 1.2 秒)
	await get_tree().create_timer(1.2).timeout
	
	# 如果播完了，確保回到 idle 狀態
	if anim_sprite.animation == anim_name:
		update_animation_by_dir("idle_")
