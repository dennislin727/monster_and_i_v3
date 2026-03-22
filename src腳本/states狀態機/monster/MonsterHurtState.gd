# res://src腳本/states狀態機/monster/MonsterHurtState.gd
extends MonsterState

func enter():
	monster.velocity = Vector2.ZERO # 🔴 強制停下，中斷所有位移
	monster.play_monster_animation("hit")
	
	# 擊退效果
	if monster.target_player:
		var knockback = (monster.global_position - monster.target_player.global_position).normalized()
		var t = create_tween()
		t.tween_property(monster, "global_position", monster.global_position + knockback * 20, 0.2)
	
	monster.modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.25).timeout
	monster.modulate = Color.WHITE
	
	# 決定下一個狀態
	var hp_pct = float(monster.health.current_hp) / monster.health.max_hp
	if hp_pct < 0.2:
		_change_state("Flee")
	else:
		_change_state("Chase")
