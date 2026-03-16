# res://src腳本/components積木/SealManager.gd
extends Node2D

var points: PackedVector2Array = [] # 儲存手指路徑
var is_drawing: bool = false
@onready var line_2d: Line2D = Line2D.new() # 在畫面上顯示線條

func _ready() -> void:
	add_child(line_2d)
	line_2d.width = 10.0
	line_2d.default_color = Color(0.4, 0.8, 1.0, 0.6) # 半透明天藍色

func _input(event: InputEvent) -> void:
	# 當手指/滑鼠按下
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			start_drawing()
		else:
			finish_drawing()

	# 當手指/滑鼠移動
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if is_drawing:
			add_point(event.position)

func start_drawing():
	is_drawing = true
	points.clear()
	line_2d.clear_points()

func add_point(pos: Vector2):
	# 為了效能與邏輯，距離太近的點不記錄
	if points.size() == 0 or points[-1].distance_to(pos) > 20:
		points.append(pos)
		line_2d.add_point(pos)

func finish_drawing():
	is_drawing = false
	if points.size() > 10: # 劃得夠長才算
		check_circle_and_seal()
	line_2d.clear_points()

func check_circle_and_seal():
	# 簡單的判斷：起點跟終點是否夠接近？
	var start = points[0]
	var end = points[-1]
	
	if start.distance_to(end) < 150: # 距離夠近，視為閉合的圓
		print("[SealManager] 劃圓成功！嘗試封印範圍內的怪物...")
		trigger_seal_effect()

func trigger_seal_effect():
	# 這裡會發訊號給 SignalBus，通知所有範圍內的怪物：「你們被封印了！」
	# SignalBus.seal_attempted.emit(...)
	pass
