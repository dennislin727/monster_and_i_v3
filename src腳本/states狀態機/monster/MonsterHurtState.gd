# res://src腳本/states狀態機/monster/MonsterHurtState.gd
extends MonsterState

func enter():
	# 1. 徹底停止當前移動
	monster.velocity = Vector2.ZERO
	
	# 2. 播放受擊動畫（自動退路到通用 hit）
	monster.play_monster_animation("hit")
	
	# 3. 擊退視覺效果 (向後彈一小段)
	if monster.target_player:
		var knockback_dir = (monster.global_position - monster.target_player.global_position).normalized()
		var t = create_tween()
		t.tween_property(monster, "global_position", monster.global_position + knockback_dir * 30, 0.2)
	
	# 4. 閃白特效 (過曝感)
	monster.modulate = Color(10, 10, 10)
	
	# 5. 等待硬直時間 (0.3秒)
	await get_tree().create_timer(0.3).timeout
	
	# 6. 恢復顏色
	monster.modulate = Color.WHITE
	
	# 7. 🔴 決策下一步：血太少就逃跑，否則就追擊反抗
	_decide_next_state()

func _decide_next_state():
	var hp_pct = float(monster.health.current_hp) / monster.health.max_hp
	
	if hp_pct < 0.2:
		_change_state("Flee")
	else:
		_change_state("Chase")
