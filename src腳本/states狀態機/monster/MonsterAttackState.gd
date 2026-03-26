# res://src腳本/states狀態機/monster/MonsterAttackState.gd
extends MonsterState

func enter():
	monster.velocity = Vector2.ZERO
	if monster.data == null:
		_change_state("Idle")
		return
	# 🔴 修正：一進入攻擊狀態就先設定一個基礎冷卻，防止在動畫期間又被判定攻擊
	monster.attack_cd_timer = monster.data.attack_cooldown
	_execute_attack()

func _execute_attack():
	if monster.is_dead or not monster.target_player or monster.data == null:
		_change_state("Idle")
		return
		
	var dir_to_player = (monster.target_player.global_position - monster.global_position).normalized()
	
	if dir_to_player.x != 0:
		monster.anim.flip_h = (dir_to_player.x > 0)
	
	monster.play_monster_animation("attack")
	
	# 飛撲
	var lunge = create_tween()
	lunge.tween_property(monster, "global_position", 
	monster.global_position + dir_to_player * GlobalBalance.MONSTER_LUNGE_DIST, 0.2)\
	.set_trans(Tween.TRANS_QUINT)
	
	await get_tree().create_timer(0.25).timeout
	if monster.is_dead or monster.state_machine.current_state != self: return
	
	if monster.target_player:
		var d = monster.global_position.distance_to(monster.target_player.global_position)
		if d < monster.data.attack_range + 60:
			monster.target_player.take_damage(GlobalBalance.MONSTER_BASE_DAMAGE)
			print("[Attack] 怪物咬了主角！")
	var pet := get_tree().get_first_node_in_group("deployed_pet")
	if pet and pet.has_method("take_damage_from_monster"):
		var dp = monster.global_position.distance_to(pet.global_position)
		if dp < monster.data.attack_range + 60:
			pet.take_damage_from_monster(GlobalBalance.MONSTER_BASE_DAMAGE)

	if monster.anim.is_playing():
		await monster.anim.animation_finished
	
	if monster.is_dead or monster.state_machine.current_state != self: return
	
	# 攻擊結束，再次確認冷卻時間已設定
	monster.attack_cd_timer = monster.data.attack_cooldown
	_change_state("Chase")
