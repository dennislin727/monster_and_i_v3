# res://src腳本/states狀態機/PlayerStateMachine.gd
extends Node

var current_state: Node
@onready var player: PlayerController = get_parent()

func _ready() -> void:
	# 等待一幀，確保父節點與子節點都準備好
	await get_tree().process_frame
	for state in get_children():
		state.player = player
		state.set_process(false) # 預設關閉所有狀態的處理
	
	change_state($Move)

func _process(_delta: float) -> void:
	if not player: return
	
	# 1. 封印模式最優先，強行切換到 Move (處理待機)
	if player.is_seal_mode:
		change_state($Move)
		return

	# 2. 🔴 核心修復：屬性安全檢查
	# 我們用 get() 來安全取得變數。如果目前的狀態沒有 is_swinging，它會回傳 null。
	var swinging = current_state.get("is_swinging")
	if swinging == true:
		return # 如果正在揮刀中，鎖定目前狀態，不准切換

	# 3. 根據感應器決定下一個狀態
	if player.current_enemy or player.current_target:
		change_state($Attack)
	else:
		change_state($Move)

func change_state(new_state: Node) -> void:
	if current_state == new_state: return
	
	if current_state:
		current_state.exit()
		current_state.set_process(false)
	
	current_state = new_state
	# print("[FSM] 切換到: ", new_state.name) # 調試用
	current_state.set_process(true)
	current_state.enter()
