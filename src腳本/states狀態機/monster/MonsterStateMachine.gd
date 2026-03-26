# res://src腳本/states狀態機/monster/MonsterStateMachine.gd
class_name MonsterStateMachine
extends Node

@export var initial_state: NodePath = "Idle"
var current_state: MonsterState
var monster: MonsterBase

func init(parent_monster: MonsterBase) -> void:
	monster = parent_monster
	if monster == null or monster.data == null:
		return
	for child in get_children():
		if child is MonsterState:
			child.monster = monster
	
	var start_node = get_node(initial_state)
	if start_node:
		change_state(start_node)

func change_state(new_state: MonsterState) -> void:
	# 🔴 核心鎖定：如果當前已經在死亡狀態，拒絕切換到任何其他狀態
	if current_state and current_state.name == "Die":
		return 
		
	if current_state == new_state: return
	
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter()

# 供子狀態呼叫的接口
func change_to(state_name: String) -> void:
	# 🔴 核心鎖定：如果已經死了，不准再切換（除非是要切換到 Die）
	if current_state and current_state.name == "Die":
		return
		
	var target = get_node_or_null(state_name)
	if target and target is MonsterState:
		change_state(target)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if monster == null or monster.data == null:
		return
	if current_state:
		current_state.handle_physics(delta)
