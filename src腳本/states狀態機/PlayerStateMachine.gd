# res://src腳本/states狀態機/PlayerStateMachine.gd
extends Node

var current_state: Node
@onready var player: PlayerController = get_parent()

func _ready() -> void:
	# 🔴 核心修正：移除 await，直接初始化
	for state in get_children():
		state.player = player
		state.set_process(false)
	
	change_state($Move)

func _process(_delta: float) -> void:
	if not player: return
	
	if player.is_seal_mode:
		change_state($Move)
		return

	var swinging = current_state.get("is_swinging")
	if swinging == true:
		return 

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
	current_state.set_process(true)
	current_state.enter()
