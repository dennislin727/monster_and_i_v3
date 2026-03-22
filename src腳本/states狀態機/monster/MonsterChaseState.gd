extends MonsterState

func handle_physics(_delta: float):
	if not monster.target_player:
		monster.state_machine.change_state(get_node("../Idle"))
		return
		
	var hp_pct = float(monster.health.current_hp) / monster.health.max_hp
	
	# 🔴 檢查技能觸發
	var skill = monster._get_available_skill()
	if skill and hp_pct < skill.max_hp_pct:
		monster.state_machine.change_state(get_node("../Spell"))
		return

	# 🔴 逃跑判定
	if hp_pct < 0.2:
		monster.state_machine.change_state(get_node("../Flee"))
		return

	var dist = monster.global_position.distance_to(monster.target_player.global_position)
	if dist <= monster.data.attack_range:
		monster._perform_attack() # 普攻暫時留在 MonsterBase 處理簡單動畫
	else:
		monster.velocity = (monster.target_player.global_position - monster.global_position).normalized() * monster.data.chase_speed
		monster.play_monster_animation("run_" + monster.get_dir_string())
