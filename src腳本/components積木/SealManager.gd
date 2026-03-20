# res://src腳本/components積木/SealManager.gd
extends Node2D

@export var is_seal_mode_enabled: bool = false
const JOYSTICK_SAFE_ZONE_Y: float = 0.7 # 螢幕下方 30% 為搖桿區

var points: PackedVector2Array = [] 
var is_drawing: bool = false
@onready var line_2d: Line2D = Line2D.new() 

func _ready() -> void:
	add_child(line_2d)
	line_2d.width = 10.0
	line_2d.default_color = Color(0.4, 0.8, 1.0, 0.6)
	
	# 監聽開關
	SignalBus.seal_mode_toggled.connect(_on_seal_mode_toggled)

func _on_seal_mode_toggled(enabled: bool) -> void:
	is_seal_mode_enabled = enabled
	if not enabled:
		stop_drawing() # 關閉模式時立刻清空線條

func _input(event: InputEvent) -> void:
	if not is_seal_mode_enabled: return
	
	# 觸控或滑鼠按下
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			# 安全區檢查：太靠近下方則不啟動
			var screen_size = get_viewport_rect().size
			if event.position.y > screen_size.y * JOYSTICK_SAFE_ZONE_Y:
				return 
			start_drawing()
		else:
			finish_drawing()

	# 繪製移動中
	if (event is InputEventScreenDrag or event is InputEventMouseMotion) and is_drawing:
		add_point(event.position)

func start_drawing() -> void:
	is_drawing = true
	points.clear()
	line_2d.clear_points()

func stop_drawing() -> void:
	is_drawing = false
	points.clear()
	line_2d.clear_points()

func add_point(pos: Vector2) -> void:
	if points.size() == 0 or points[-1].distance_to(pos) > 20:
		points.append(pos)
		line_2d.add_point(pos)

func finish_drawing() -> void:
	is_drawing = false
	if points.size() > 10:
		check_circle_and_seal()
	line_2d.clear_points()

func check_circle_and_seal() -> void:
	var start = points[0]
	var end = points[-1]
	if start.distance_to(end) < 150:
		print("[SealManager] 劃圓成功！")
		# 未來這裡會呼叫 SignalBus.seal_attempted.emit()
