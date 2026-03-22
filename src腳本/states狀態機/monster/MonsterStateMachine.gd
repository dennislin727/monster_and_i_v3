class_name MonsterStateMachine
extends Node

var current_state: MonsterState

func init(monster: MonsterBase):
	for child in get_children():
		child.monster = monster
	change_state(get_child(0)) # 預設進入第一個狀態 (通常是 Idle)

func change_state(new_state: MonsterState):
	if current_state == new_state: return
	if current_state: current_state.exit()
	current_state = new_state
	current_state.enter()

func _physics_process(delta: float):
	if current_state:
		current_state.handle_physics(delta)
