# res://src腳本/states狀態機/monster/MonsterHurtState.gd
extends MonsterState

func enter():
	monster.velocity = Vector2.ZERO
	monster.play_monster_animation("hit")
	
	# 🔴 修正：刪掉歸零那行！
	# 我們不手動改 attack_cd_timer，讓它自己慢慢扣
	
	# 擊退效果
	if monster.target_player:
		var knockback = (monster.global_position - monster.target_player.global_position).normalized()
		var t = create_tween()
		t.tween_property(monster, "global_position", monster.global_position + knockback * 30, 0.2)
	
	# 閃白效果
	monster.modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.2).timeout
	if monster.is_dead: return
	monster.modulate = Color.WHITE
	
	# 受傷完進入 Chase，它會檢查 CD 到了沒，沒到就不會攻擊
	_change_state("Chase")
