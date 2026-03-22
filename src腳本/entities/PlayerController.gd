# res://src腳本/entities/PlayerController.gd
class_name PlayerController
extends CharacterBody2D

# --- 1. 參數設定 ---
@export_group("移動參數")
@export var move_speed: float = 200.0
@export var dash_distance: float = 150.0 

@export_group("戰鬥參數")
@export var invincible_time: float = 0.8  # 受傷無敵時間
@export var hit_stun_duration: float = 0.4 # 受傷動畫鎖定時間

# --- 2. 節點引用 ---
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: Node = $StateMachine
@onready var health: HealthComponent = $HealthComponent
@onready var interaction_detector: Area2D = $InteractionDetector

# --- 3. 內部狀態 ---
var last_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var is_seal_mode: bool = false
var is_hit_stun: bool = false 
var is_invincible: bool = false

var current_target: InteractableComponent = null
var current_enemy: HurtboxComponent = null

func _ready() -> void:
	if SignalBus.has_signal("dash_requested"):
		SignalBus.dash_requested.connect(perform_dash)
	
	add_to_group("player")
	
	for state in state_machine.get_children():
		state.player = self
	
	SignalBus.seal_mode_toggled.connect(func(enabled: bool): is_seal_mode = enabled)
	
	# 初始動畫
	call_deferred("update_animation_by_dir", "idle_")

func _physics_process(_delta: float) -> void:
	# 受擊或瞬移時，鎖死物理邏輯
	if is_hit_stun or is_dashing: 
		move_and_slide()
		return
	
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
	
	# 動畫管理
	_manage_animations()

func _manage_animations() -> void:
	if is_hit_stun: return 
	
	# 🔴 核心修復：加入 Nil 安全檢查
	if state_machine == null or state_machine.get("current_state") == null:
		return
		
	# 只有在 Move 狀態時才由 Controller 決定跑/待機動畫
	if state_machine.current_state.name == "Move":
		update_animation_by_dir("idle_" if velocity.length() < 5 else "run_")

# --- 4. 戰鬥接口 ---

func take_damage(amount: int):
	if is_invincible or is_dashing: return
	
	is_hit_stun = true
	is_invincible = true
	
	velocity = Vector2.ZERO 
	
	if health: health.take_damage(amount)
	# 🔴 噴發白色數字 (位置, 數值, 是否為玩家)
	SignalBus.damage_spawned.emit(global_position, amount, true)
	
	anim_sprite.stop()
	anim_sprite.play("hit")
	
	# 無敵閃爍
	var t = create_tween().set_loops(4)
	t.tween_property(anim_sprite, "modulate:a", 0.2, 0.1)
	t.tween_property(anim_sprite, "modulate:a", 1.0, 0.1)
	
	# 🔴 僵直時間：0.4秒 (剛好播完 4 幀 10FPS 的動畫)
	await get_tree().create_timer(hit_stun_duration).timeout
	is_hit_stun = false # 0.4秒後才恢復控制
	
	await get_tree().create_timer(invincible_time - hit_stun_duration).timeout
	is_invincible = false

func hit_current_target() -> void:
	if current_enemy:
		current_enemy.take_damage(10)
		SignalBus.damage_spawned.emit(current_enemy.global_position, 10, false)
	elif current_target:
		current_target.start_harvest()

# --- 5. 輔助函數 ---

func update_animation_by_dir(prefix: String) -> void:
	update_flip()
	var anim_name = prefix + get_dir_string()
	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)

func update_flip() -> void:
	if last_direction.x != 0:
		anim_sprite.flip_h = (last_direction.x > 0)

func get_dir_string() -> String:
	var x = abs(last_direction.x); var y = abs(last_direction.y)
	if y > x * 1.5: return "down" if last_direction.y > 0 else "up"
	return "side"

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
