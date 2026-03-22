extends MonsterState

func enter():
	monster.state_timer = randf_range(0.8, 1.8)
	monster.wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	monster.play_monster_animation("run_" + monster.get_dir_string())

func handle_physics(delta: float):
	if monster.target_player:
		monster.state_machine.change_state(get_node("../Chase"))
		return
		
	monster.velocity = monster.wander_dir * monster.data.move_speed
	
	monster.state_timer -= delta
	if monster.state_timer <= 0:
		monster.state_machine.change_state(get_node("../Idle"))
