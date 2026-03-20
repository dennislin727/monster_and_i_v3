# res://src腳本/components積木/SealManager.gd
extends Node2D

enum SealState { IDLE, EYE_INTRO, DRAWING, HOLDING }
var current_state: int = SealState.IDLE

@onready var line_2d: Line2D = Line2D.new()
var points: PackedVector2Array = []
var target_monster: CharacterBody2D = null
var is_pressing_target: bool = false

func _ready() -> void:
	add_child(line_2d)
	line_2d.width = 12.0
	line_2d.default_color = Color(0.4, 0.8, 1.0, 0.6)
	add_to_group("seal_manager")
	SignalBus.seal_mode_toggled.connect(_on_seal_button_toggled)

func _on_seal_button_toggled(enabled: bool) -> void:
	print("[SealManager] 接收到電報，開啟狀態: ", enabled) # 加這行來確認
	if enabled:
		start_seal_sequence()
	else:
		cancel_seal()

func start_seal_sequence():
	Engine.time_scale = 0.05
	SignalBus.seal_ui_requested.emit(true)
	current_state = SealState.EYE_INTRO
	await get_tree().create_timer(0.015).timeout # 約現實 0.3s
	if current_state == SealState.EYE_INTRO:
		current_state = SealState.DRAWING
		points.clear()
		line_2d.clear_points()

func _unhandled_input(event: InputEvent) -> void:
	if current_state == SealState.DRAWING:
		handle_drawing_input(event)
	elif current_state == SealState.HOLDING:
		handle_holding_input(event)

func handle_drawing_input(event: InputEvent):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if not event.pressed: finish_drawing()
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if points.size() == 0 or points[-1].distance_to(event.position) > 15:
			points.append(event.position)
			line_2d.add_point(event.position)

# 🔴 新增：處理封印鎖定後的按壓邏輯
func handle_holding_input(event: InputEvent):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			if is_touching_monster(event.position):
				is_pressing_target = true
				print("[Seal] 正在按壓怪物...")
			else:
				is_pressing_target = false
		else:
			is_pressing_target = false

func finish_drawing():
	var start = points[0] if points.size() > 0 else Vector2.ZERO
	var end = points[-1] if points.size() > 0 else Vector2.ZERO
	
	if points.size() > 10 and start.distance_to(end) < 200:
		var center = calculate_circle_center() # 🔴 補齊
		target_monster = find_monster_in_circle(center) # 🔴 補齊
		if target_monster:
			lock_on_monster()
		else:
			fail_and_reset()
	else:
		fail_and_reset()

# 🔴 補齊：計算圓心 (平均位置)
func calculate_circle_center() -> Vector2:
	var sum = Vector2.ZERO
	for p in points: sum += p
	return sum / points.size()

# 🔴 補齊：搜尋圓圈內的怪物 (需確保怪物在 "monsters" 群組)
func find_monster_in_circle(center_screen: Vector2) -> CharacterBody2D:
	var world_pos = get_canvas_transform().affine_inverse() * center_screen
	var monsters = get_tree().get_nodes_in_group("monsters")
	var nearest: CharacterBody2D = null
	var min_dist = 200.0 # 圓圈感應半徑
	
	for m in monsters:
		if m is CharacterBody2D:
			var d = m.global_position.distance_to(world_pos)
			if d < min_dist:
				min_dist = d
				nearest = m
	return nearest

# 🔴 補齊：檢查觸碰是否在怪物身上
func is_touching_monster(screen_pos: Vector2) -> bool:
	if not target_monster: return false
	var world_pos = get_canvas_transform().affine_inverse() * screen_pos
	return target_monster.global_position.distance_to(world_pos) < 120 # 點擊寬容度

func lock_on_monster():
	Engine.time_scale = 1.0
	SignalBus.seal_ui_requested.emit(false)
	current_state = SealState.HOLDING
	line_2d.clear_points()
	if target_monster.has_method("on_sealed_start"):
		target_monster.on_sealed_start()

func fail_and_reset():
	cancel_seal()
	SignalBus.seal_button_reset_requested.emit()

func cancel_seal():
	Engine.time_scale = 1.0
	SignalBus.seal_ui_requested.emit(false)
	current_state = SealState.IDLE
	points.clear()
	line_2d.clear_points()
	target_monster = null
	is_pressing_target = false
