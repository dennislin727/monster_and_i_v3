# res://src腳本/states狀態機/monster/MonsterState.gd
class_name MonsterState
extends Node

# 這是每個狀態積木都能看到的「身體」引用
var monster: MonsterBase 

# 當進入這個狀態時觸發（只觸發一次）
func enter() -> void:
	pass

# 當離開這個狀態時觸發（只觸發一次）
func exit() -> void:
	pass

# 每一幀的物理邏輯處理（由 StateMachine 呼叫）
func handle_physics(_delta: float) -> void:
	pass

# 輔助：快速切換到其他狀態
func _change_state(state_name: String) -> void:
	if monster and monster.state_machine:
		monster.state_machine.change_to(state_name)
