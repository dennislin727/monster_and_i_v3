# res://src腳本/states狀態機/monster/MonsterAttackState.gd
extends MonsterState

func enter():
	monster.velocity = Vector2.ZERO
	_execute_attack()

func _execute_attack():
	# 1. 取得方向
	var dir_to_player = (monster.target_player.global_position - monster.global_position).normalized()
	
	# 2. 🔴 攻擊突進：發動瞬間向前衝 40 像素
	var lunge_tween = create_tween()
	lunge_tween.tween_property(monster, "global_position", monster.global_position + dir_to_player * 40, 0.15).set_trans(Tween.TRANS_QUINT)
	
	monster.play_monster_animation("attack")
	
	# 3. 傷害判定
	await get_tree().create_timer(0.25).timeout # 突進完剛好咬下去
	
	if monster.target_player:
		var dist = monster.global_position.distance_to(monster.target_player.global_position)
		if dist <= monster.data.attack_range + 30:
			monster.target_player.take_damage(10)
	
	if monster.anim.is_playing():
		await monster.anim.animation_finished
	
	monster.attack_cd_timer = monster.data.attack_cooldown
	_change_state("Idle")
