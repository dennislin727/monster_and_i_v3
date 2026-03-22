extends MonsterState

func enter():
	monster.velocity = Vector2.ZERO
	monster.play_monster_animation("idle_" + monster.last_dir_str)
	monster.state_timer = randf_range(2.0, 4.0)

func handle_physics(delta: float):
	if monster.target_player:
		monster.state_machine.change_state(get_node("../Chase"))
		return
		
	monster.state_timer -= delta
	if monster.state_timer <= 0:
		monster.state_machine.change_state(get_node("../Wander"))
