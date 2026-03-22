# res://src腳本/entities/PlayerController.gd
class_name PlayerController
extends CharacterBody2D

@export_group("移動與跳躍")
@export var move_speed: float = 200.0
@export var dash_distance: float = 150.0 
@export var dash_duration: float = 0.4  

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: Node = $StateMachine # 🔴 確保有這行
@onready var interaction_detector: Area2D = $InteractionDetector

var last_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var is_seal_mode: bool = false
var current_target: InteractableComponent = null
var current_enemy: HurtboxComponent = null

func _ready() -> void:
	# 連結訊號
	if SignalBus.has_signal("dash_requested"):
		SignalBus.dash_requested.connect(perform_dash)
	
	add_to_group("player")
	
	# 初始化狀態機
	if state_machine:
		for state in state_machine.get_children():
			state.player = self
	
	# 監聽封印模式
	SignalBus.seal_mode_toggled.connect(func(enabled: bool): is_seal_mode = enabled)

func _physics_process(_delta: float) -> void:
	if is_dashing: return
	
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 🔴 判斷：是否在畫圈（時間變慢）
	if Engine.time_scale < 1.0:
		velocity = Vector2.ZERO # 畫圈時鎖死
	else:
		# 時間正常時，恢復移動
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
	
	# 🎨 畫家參數設定區
	var up_time = 0.2    # 跳起來的時間
	var down_time = 0.2  # 落地（衝擊）的時間
	var total_time = up_time + down_time # 總共 0.3s
	
	var target_pos = global_position + (last_direction * dash_distance)
	
	# 1. 水平位移 (這段時間內人物會一直往前滑)
	var dash_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dash_tween.tween_property(self, "global_position", target_pos, total_time)
	
	# 2. 垂直彈跳 (讓圖片上下晃動)
	var jump_tween = create_tween()
	anim_sprite.pause() 
	
	# 【上升段】 往斜前方跳起的感覺
	jump_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(anim_sprite, "position:y", -25.0, up_time)
	
	# 【下降段】 這是你說的「落地過程繼續往前」
	# 這裡使用 EASE_IN 讓落地有加速度，且時間與水平位移同時結束
	jump_tween.chain().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	jump_tween.tween_property(anim_sprite, "position:y", 0.0, down_time)
	
	# 3. 落地後的清理
	dash_tween.finished.connect(func(): 
		is_dashing = false
		anim_sprite.play() # 恢復動畫
	)

# 訊號接收：只負責紀錄目標
func _on_interaction_detector_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent: current_enemy = area
	elif area is InteractableComponent: current_target = area

func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if area == current_enemy: current_enemy = null
	elif area == current_target: current_target = null

# res://src腳本/entities/PlayerController.gd

# 🔴 由動畫影格自動觸發
func hit_current_target() -> void:
	if current_target:
		# 這是採集物
		current_target.start_harvest()
		# 震動相機 (Shake Effect) 增加打擊感
		apply_camera_shake(0.2)
	elif current_enemy:
		# 這是怪物
		current_enemy.take_damage(10)
		apply_camera_shake(0.3)

func apply_camera_shake(intensity: float):
	var cam = $Camera2D
	var tween = create_tween()
	# 簡單的隨機抖動
	for i in range(4):
		tween.tween_property(cam, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)) * 10, 0.05)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.05)
	
func take_damage(amount: int):
	if is_dashing: return # 瞬移無敵幀
	
	# 1. 播放受擊動畫
	if anim_sprite.sprite_frames.has_animation("hit"):
		anim_sprite.play("hit")
	
	# 2. 暫時失去控制 (硬直)
	is_dashing = true 
	
	# 3. 視覺震動
	var t = create_tween()
	t.tween_property(anim_sprite, "modulate", Color.RED, 0.1)
	t.tween_property(anim_sprite, "modulate", Color.WHITE, 0.1)
	
	await get_tree().create_timer(0.2).timeout
	is_dashing = false
	# 恢復原本動畫由狀態機接管
