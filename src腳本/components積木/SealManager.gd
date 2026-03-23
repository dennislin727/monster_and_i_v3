# res://src腳本/components積木/SealManager.gd
extends Node2D

enum SealState { IDLE, EYE_INTRO, DRAWING, HOLDING, RESULT }
var current_state: int = SealState.IDLE

@onready var line_2d: Line2D = Line2D.new()
var points: PackedVector2Array = []
var target_monster: CharacterBody2D = null
var is_pressing_target: bool = false

# 紀錄世界主角參考
@onready var world_player: PlayerController = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	add_child(line_2d)
	line_2d.width = 15.0
	line_2d.default_color = Color(0.4, 0.8, 1.0, 0.6)
	line_2d.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line_2d.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_to_group("seal_manager")
	SignalBus.seal_mode_toggled.connect(_on_seal_button_toggled)

func _on_seal_button_toggled(enabled: bool) -> void:
	if enabled: start_seal_sequence()
	else: cancel_seal()

# --- 階段 A：儀式感開始 (UI 層) ---
func start_seal_sequence():
	Engine.time_scale = 0.25 # 減速至 1/4
	current_state = SealState.EYE_INTRO
	
	if world_player: 
		world_player.hide()
		world_player.set_physics_process(false) # 暫停物理邏輯防止意外移動
		
	SignalBus.seal_ui_requested.emit(true) # 通知 UI 開濾鏡與演員
	
	# 等待開眼演繹結束 (真實時間約 0.5s)
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
			# 傳遞畫線百分比給 UI 演員做幀同步
			var progress = clamp(float(points.size()) / 35.0, 0.0, 1.0)
			SignalBus.seal_draw_progress.emit(progress)

func finish_drawing():
	# 圓圈判定：點數足夠且首尾接近
	if points.size() > 15 and points[0].distance_to(points[-1]) < 180:
		var center = calculate_circle_center()
		target_monster = find_monster_in_circle(center)
		if target_monster and target_monster.has_node("SealingComponent"):
			execute_sword_fall()
		else:
			fail_and_reset()
	else:
		fail_and_reset()

# --- 階段 B：分水嶺切換 (回到遊戲世界) ---
func execute_sword_fall():
	Engine.time_scale = 1.0 
	SignalBus.seal_ui_requested.emit(false) 
	
	if world_player:
		world_player.show()
		# 🔴 核心修復 1：強制開啟物理處理，讓主角可以走位
		world_player.set_physics_process(true)
		world_player.is_seal_mode = true 
		
		# 🔴 核心修復 2：通知電台，封印模式已進入「操作階段」，請搖桿現身
		# 我們可以發送一個特殊的訊號，或者再次發送 false 讓搖桿以為結束了(但其實是進入按壓期)
		SignalBus.seal_mode_toggled.emit(false) # 讓搖桿以為關閉了，從而顯示出來

	if target_monster:
		# 🔴 核心修復 3：座標檢查。如果文字沒出現，通常是偏移量或座標系問題
		# 嘗試改用 target_monster 的 global_position
		SignalBus.popup_text.emit(target_monster.global_position, "長壓幫助封印!!", Color.YELLOW)
		
		if target_monster.has_node("SealingComponent"):
			target_monster.get_node("SealingComponent").start_struggle()
	
	current_state = SealState.HOLDING
	line_2d.clear_points()

func handle_holding_input(event: InputEvent):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed and is_touching_monster(event.position):
			is_pressing_target = true
			get_viewport().set_input_as_handled() # 阻斷移動輸入
		else:
			is_pressing_target = false

# --- 階段 C：真實世界結算 ---
func resolve_sealing(success: bool):
	current_state = SealState.RESULT
	is_pressing_target = false
	
	if world_player:
		world_player.is_seal_mode = false # 解除狀態鎖
		
		# 直接在遊戲世界演繹動畫與跳字
		var anim_name = "happy" if success else "sad"
		var text_msg = "Got you!" if success else "Fail"
		var text_col = Color.CYAN if success else Color.CORAL
		
		world_player.anim_sprite.play(anim_name)
		SignalBus.popup_text.emit(world_player.global_position + Vector2(0, -110), text_msg, text_col)
	
	if success:
		SignalBus.seal_orb_fly.emit(target_monster.global_position)
	else:
		SignalBus.seal_button_reset_requested.emit()
	
	# 重置狀態
	await get_tree().create_timer(1.2).timeout
	current_state = SealState.IDLE
	target_monster = null

func is_touching_monster(screen_pos: Vector2) -> bool:
	if not target_monster: return false
	# 螢幕轉世界座標
	var world_pos = get_canvas_transform().affine_inverse() * screen_pos
	# 🔴 核心修復 4：增加判定半徑到 150，手機比較好點到
	var dist = target_monster.global_position.distance_to(world_pos)
	print("[SealManager] 檢查點擊距離: ", dist) # 加入偵錯文字
	return dist < 150

func calculate_circle_center() -> Vector2:
	var sum = Vector2.ZERO
	for p in points: sum += p
	return sum / points.size()

func find_monster_in_circle(center_screen: Vector2) -> CharacterBody2D:
	var world_pos = get_canvas_transform().affine_inverse() * center_screen
	var monsters = get_tree().get_nodes_in_group("monsters")
	for m in monsters:
		if m.global_position.distance_to(world_pos) < 150: return m
	return null

func cancel_seal():
	Engine.time_scale = 1.0
	if world_player: world_player.show()
	SignalBus.seal_ui_requested.emit(false)
	current_state = SealState.IDLE
	line_2d.clear_points()

func fail_and_reset():
	cancel_seal()
	SignalBus.seal_button_reset_requested.emit()
