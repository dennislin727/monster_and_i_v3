# res://src腳本/states狀態機/monster/MonsterAttackState.gd
extends MonsterState

func enter():
	monster.velocity = Vector2.ZERO # 攻擊時站定
	_execute_attack()

func _execute_attack():
	# 1. 播放攻擊動畫
	monster.play_monster_animation("attack")
	
	# 2. 🔴 傷害判定：等待動畫揮下的那一刻 (約 0.3 秒)
	await get_tree().create_timer(0.3).timeout
	
	# 再次檢查距離，防止玩家已經閃開
	if monster.target_player:
		var dist = monster.global_position.distance_to(monster.target_player.global_position)
		if dist <= monster.data.attack_range + 20:
			monster.target_player.take_damage(10) # 🔴 讓主角受傷
	
	# 3. 等待動畫播完
	if monster.anim.is_playing():
		await monster.anim.animation_finished
	
	# 4. 攻擊結束，回到追擊狀態
	_change_state("Chase")
