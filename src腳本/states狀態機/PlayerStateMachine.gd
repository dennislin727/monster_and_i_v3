# res://src腳本/states狀態機/PlayerStateMachine.gd
extends Node

var current_state: Node
@onready var player: PlayerController = get_parent()

func _ready() -> void:
	# 🔴 核心修正：不要 await，立刻初始化所有子狀態的 player 引用
	for state in get_children():
		state.player = player
		state.set_process(false)
	
	# 立刻進入第一個狀態
	change_state($Move)

func _process(_delta: float) -> void:
	if not player: return
	
	# 🔴 核心邏輯：封印模式下，強制維持在 Move 狀態，確保 velocity 運算被執行
	if player.is_seal_mode:
		if current_state != $Move:
			change_state($Move)
		return # 封印時跳過後續的攻擊判定

	# 攻擊鎖
	if current_state.name == "Attack":
		if current_state.get("is_swinging") == true:
			return

	# 狀態切換判定
	if player.current_enemy or player.current_target:
		change_state($Attack)
	else:
		change_state($Move)

func change_state(new_state: Node) -> void:
	if current_state == new_state: return
	
	if current_state:
		if current_state.has_method("exit"):
			current_state.exit()
		current_state.set_process(false)
	
	current_state = new_state
	current_state.set_process(true)
	
	if current_state.has_method("enter"):
		current_state.enter()
