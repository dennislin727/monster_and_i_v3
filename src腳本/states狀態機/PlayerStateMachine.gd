# res://src腳本/states狀態機/PlayerStateMachine.gd
extends Node

var current_state: Node
@onready var player: PlayerController = get_parent()

func _ready() -> void:
	await get_tree().process_frame
	for state in get_children():
		state.player = player
		state.set_process(false)
	change_state($Move)

func _process(_delta: float) -> void:
	if not player: return
	
	# 1. 受擊硬直鎖
	if player.is_hit_stun: return 

	# 2. 奧義/封印模式鎖
	if player.is_seal_mode:
		change_state($Move)
		return

	# 3. 攻擊鎖 (正在揮刀時不准換狀態)
	if current_state.name == "Attack":
		if current_state.get("is_swinging") == true:
			return

	# 4. 根據感應器切換
	if player.current_enemy or player.current_target:
		change_state($Attack)
	else:
		change_state($Move)

func change_state(new_state: Node) -> void:
	if current_state == new_state: return
	
	if current_state:
		# 🔴 核心修復：檢查是否有 exit 函數才呼叫
		if current_state.has_method("exit"):
			current_state.exit()
		current_state.set_process(false)
	
	current_state = new_state
	current_state.set_process(true)
	
	# 🔴 核心修復：檢查是否有 enter 函數才呼叫
	if current_state.has_method("enter"):
		current_state.enter()
