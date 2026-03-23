# res://src腳本/states狀態機/monster/MonsterChaseState.gd
extends MonsterState

func enter():
	monster.play_monster_animation("run")

func handle_physics(_delta: float):
	if monster.is_dead or not monster.target_player:
		_change_state("Idle")
		return

	var dist = monster.global_position.distance_to(monster.target_player.global_position)
	var dir = (monster.target_player.global_position - monster.global_position).normalized()
	var hp_pct = float(monster.health.current_hp) / monster.health.max_hp

	# 1. 優先級：治癒術 (Spell)
	var skill = monster.get_available_skill()
	if skill:
		_change_state("Spell")
		return

	# 2. 優先級：逃跑 (Flee)
	if hp_pct < 0.2:
		_change_state("Flee")
		return

	# 3. 攻擊與追逐判定
	if dist <= monster.data.attack_range + 15:
		if monster.attack_cd_timer <= 0:
			# 🔴 CD 好了，發動飛撲！
			_change_state("Attack")
		else:
			# 🔴 修正：CD 沒好時，如果距離「超級近」(例如貼身)，才播放 idle
			if dist < 35:
				monster.velocity = Vector2.ZERO
				monster.play_monster_animation("idle")
			else:
				# 🔴 修正：距離還有一點點時，保持「跑步」動畫與「正常速度」貼近主角
				# 這樣就不會出現緩慢爬行的感覺
				monster.velocity = dir * monster.data.chase_speed
				monster.play_monster_animation("run")
	else:
		# 4. 正常距離追逐
		monster.velocity = dir * monster.data.chase_speed
		monster.play_monster_animation("run")
