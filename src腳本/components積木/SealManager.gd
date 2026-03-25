# res://src腳本/components積木/SealManager.gd
extends Node2D

enum SealState { IDLE, EYE_INTRO, DRAWING, HOLDING, RESULT }
var current_state: int = SealState.IDLE

@onready var line_2d: Line2D = Line2D.new()
var points: PackedVector2Array = []
var target_monster: CharacterBody2D = null
var is_pressing_target: bool = false

@onready var world_player: PlayerController = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	add_child(line_2d)
	line_2d.width = 15.0
	line_2d.default_color = Color(0.4, 0.8, 1.0, 0.6)
	line_2d.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line_2d.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_to_group("seal_manager")
	# 接聽按鈕
	SignalBus.seal_mode_toggled.connect(_on_seal_button_toggled)

func _on_seal_button_toggled(enabled: bool) -> void:
	if enabled: 
		start_seal_sequence()
	else:
		# 只有在非壓制、非結算時才允許取消，防止誤觸
		if current_state != SealState.HOLDING and current_state != SealState.RESULT:
			cancel_seal()

# --- 階段 A：儀式感 (UI 層) ---

func start_seal_sequence():
	Engine.time_scale = 0.25 
	current_state = SealState.EYE_INTRO
	
	if world_player: 
		world_player.hide()
		world_player.set_physics_process(false) 
		
	SignalBus.seal_ui_requested.emit(true) 
	
	# 等待開眼 (配合 Single Actor 協議)
	await get_tree().create_timer(0.5, true, false, true).timeout 
	if current_state == SealState.EYE_INTRO:
		current_state = SealState.DRAWING
		points.clear()
		line_2d.clear_points()

func _unhandled_input(event: InputEvent) -> void:
	match current_state:
		SealState.DRAWING:
			handle_drawing_input(event)
		SealState.HOLDING:
			handle_holding_input(event)

func handle_drawing_input(event: InputEvent):
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed:
		finish_drawing()
		
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if points.size() == 0 or points[-1].distance_to(event.position) > 12:
			points.append(event.position)
			line_2d.add_point(event.position)
			var progress = clamp(float(points.size()) / 35.0, 0.0, 1.0)
			SignalBus.seal_draw_progress.emit(progress)

func finish_drawing():
	if points.size() > 15 and points[0].distance_to(points[-1]) < 180:
		var center = calculate_circle_center()
		target_monster = find_monster_in_circle(center)
		
		if is_instance_valid(target_monster) and target_monster.has_node("SealingComponent"):
			# 🟢 改動：不要直接 execute_sword_fall
			_transition_to_holding_visuals()
		else:
			fail_and_reset()
	else:
		fail_and_reset()

# 🟢 新增：視覺轉場處理
func _transition_to_holding_visuals():
	# 1. 核心修正：立刻把遊戲時間恢復正常！
	Engine.time_scale = 1.0 
	
	# 2. 通知 UI 播大劍
	SignalBus.seal_draw_confirmed.emit()
	
	# 3. 讓大劍用正常速度跑完 (0.3秒通常是動畫落下的黃金時間)
	await get_tree().create_timer(GlobalBalance.SEAL_SWORD_WAIT_TIME).timeout 
	
	# 4. 進入世界層的壓制邏輯
	execute_sword_fall()

func execute_sword_fall():
	# 這裡不需要再改 Engine.time_scale 了，上面已經改好了
	if world_player:
		world_player.show()
		world_player.set_physics_process(true)
		world_player.is_seal_mode = true       
		SignalBus.seal_button_reset_requested.emit()

	if is_instance_valid(target_monster):
		var seal_comp = target_monster.get_node("SealingComponent")
		if seal_comp.has_method("start_struggle"):
			seal_comp.start_struggle()
	
	current_state = SealState.HOLDING
	line_2d.clear_points()

func handle_holding_input(event: InputEvent):
	var screen_size = get_viewport_rect().size
	
	# 直式手機過濾左下搖桿區
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.position.y > screen_size.y * 0.75 and event.position.x < screen_size.x * 0.5:
			return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var is_touching = is_touching_monster(event.position)
		if event.pressed:
			if is_touching:
				is_pressing_target = true
				get_viewport().set_input_as_handled() 
		else:
			is_pressing_target = false 

	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if is_pressing_target:
			if is_touching_monster(event.position):
				get_viewport().set_input_as_handled() 
			else:
				is_pressing_target = false 

# --- 階段 C：結算演繹 ---

func resolve_sealing(success: bool):
	current_state = SealState.RESULT
	is_pressing_target = false
	
	if world_player:
		# 🟢 唯一指令：叫主角去演戲，跳字讓主角自己處理
		if world_player.has_method("play_finish_animation"):
			world_player.play_finish_animation(success)
	
	if success:
		SignalBus.seal_orb_fly.emit(target_monster.global_position)
	else:
		SignalBus.seal_button_reset_requested.emit()

	var monster_data: Resource = null
	if is_instance_valid(target_monster):
		monster_data = target_monster.get("data")
	SignalBus.seal_attempt_finished.emit(success, monster_data)
	
	await get_tree().create_timer(1.2).timeout
	current_state = SealState.IDLE
	target_monster = null

# --- 座標轉換與工具 ---

func is_touching_monster(screen_pos: Vector2) -> bool:
	if not is_instance_valid(target_monster): return false
	# 🔴 座標對齊協議：將螢幕轉回世界
	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	return target_monster.global_position.distance_to(world_pos) < 180

func find_monster_in_circle(center_screen: Vector2) -> CharacterBody2D:
	var world_center = get_viewport().get_canvas_transform().affine_inverse() * center_screen
	var monsters = get_tree().get_nodes_in_group("monsters")
	var closest = null
	var min_dist = 180.0 
	
	for m in monsters:
		# 🔴 核心修正：確保回傳的是 CharacterBody2D，而不是內部的 Sprite
		if not m is CharacterBody2D: continue 
		if m.get("is_dead"): continue
		
		var d = m.global_position.distance_to(world_center)
		if d < min_dist:
			min_dist = d
			closest = m
	return closest # 現在保證回傳的是 CharacterBody2D

func calculate_circle_center() -> Vector2:
	var sum = Vector2.ZERO
	for p in points: sum += p
	return sum / points.size()

func cancel_seal():
	Engine.time_scale = 1.0
	if world_player: 
		world_player.show()
		world_player.set_physics_process(true) 
		world_player.is_seal_mode = false      
	SignalBus.seal_ui_requested.emit(false)
	current_state = SealState.IDLE
	line_2d.clear_points()
	SignalBus.seal_button_reset_requested.emit() 

func fail_and_reset():
	cancel_seal()
