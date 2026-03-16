# res://src/entities/player_controller.gd (請將此腳本存放在 src)
class_name PlayerController
extends CharacterBody2D

@export var move_speed: float = 300.0

@onready var interaction_detector: Area2D = $InteractionDetector

var current_target: InteractableComponent = null

func _physics_process(_delta: float) -> void:
	# 1. 獲取原始輸入
	var raw_input: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. 修正方向 (如果你的上下左右還是反的，就在這裡加負號)
	var direction: Vector2 = Vector2.ZERO
	direction.x = raw_input.x  # 如果左右反了，改為 -raw_input.x
	direction.y = raw_input.y  # 如果上下反了，改為 -raw_input.y
	
	# 3. 執行移動
	if direction != Vector2.ZERO:
		velocity = direction * move_speed
		
		# 修正：因為原圖朝左，所以往右走時才翻轉
		if direction.x > 0:
			$Sprite2D.flip_h = true  # 往右走，翻轉圖片
		elif direction.x < 0:
			$Sprite2D.flip_h = false # 往左走，恢復原圖（朝左）
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 0.2)
		
	move_and_slide()
	
	# 如果有目標，就持續嘗試採集
	if current_target:
		current_target.start_harvest()

	# 簡單的交互偵測 (按下 Space 鍵或畫面上點擊)
	if Input.is_action_just_pressed("ui_accept"):
		try_interact()

func try_interact() -> void:
	# 取得範圍內重疊的 Area
	var areas = interaction_detector.get_overlapping_areas()
	for area in areas:
		if area is InteractableComponent:
			area.interact(self) # 呼叫組件的互動方法
			return # 每次只互動一個


func _on_interaction_detector_area_entered(area: Area2D) -> void:
	if area is InteractableComponent:
		current_target = area

func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if current_target == area:
		current_target = null
