# res://src腳本/states狀態機/monster/MonsterStateMachine.gd
class_name MonsterStateMachine
extends Node

@export var initial_state: NodePath = "Idle"

var current_state: MonsterState
var monster: MonsterBase

# 由 MonsterBase 在 _ready 階段呼叫
func init(parent_monster: MonsterBase) -> void:
	monster = parent_monster
	
	# 初始化所有子節點，把身體引用傳給它們
	for child in get_children():
		if child is MonsterState:
			child.monster = monster
		else:
			push_warning("[FSM] 警告：子節點 %s 不是 MonsterState 類型" % child.name)
	
	# 進入初始狀態
	var start_node = get_node(initial_state)
	if start_node:
		change_state(start_node)

# 核心切換邏輯
func change_state(new_state: MonsterState) -> void:
	if current_state == new_state: return
	
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter()
	# print("[FSM] %s 切換到狀態: %s" % [monster.name, new_state.name])

# 供子狀態使用的字串切換接口
func change_to(state_name: String) -> void:
	var target = get_node_or_null(state_name)
	if target and target is MonsterState:
		change_state(target)

# 將物理循環委託給當前狀態處理
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if current_state:
		current_state.handle_physics(delta)
