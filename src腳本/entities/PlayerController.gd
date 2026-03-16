# res://src/entities/player_controller.gd (請將此腳本存放在 src)
class_name PlayerController
extends CharacterBody2D

@export var move_speed: float = 300.0

@onready var interaction_detector: Area2D = $InteractionDetector

var current_target: InteractableComponent = null

func _physics_process(_delta: float) -> void:
	# 基礎移動邏輯
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * move_speed
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
