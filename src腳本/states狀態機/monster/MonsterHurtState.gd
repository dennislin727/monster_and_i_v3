# res://src腳本/states狀態機/MonsterHurtState.gd
extends MonsterState

func enter():
	monster.velocity = Vector2.ZERO
	monster.play_monster_animation("hit_" + monster.get_dir_string())
	monster.modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.3).timeout
	monster.modulate = Color.WHITE
	
	# 判斷受傷後該逃跑還是追擊
	var hp_pct = float(monster.health.current_hp) / monster.health.max_hp
	if hp_pct < 0.2:
		monster.state_machine.change_state(get_node("../Flee"))
	else:
		monster.state_machine.change_state(get_node("../Chase"))
