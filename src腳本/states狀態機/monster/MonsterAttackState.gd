# res://src腳本/states狀態機/monster/MonsterAttackState.gd
extends MonsterState

func enter():
	monster.velocity = Vector2.ZERO
	if monster.data == null:
		_change_state("Idle")
		return
	if monster.data.combat_style == MonsterResource.CombatStyle.RANGED_KITER:
		if monster.data.ranged_basic_skill:
			monster.attack_cd_timer = monster.data.attack_cooldown
			_execute_ranged_stone_toss()
		else:
			_change_state("Chase")
		return
	# 🔴 修正：一進入攻擊狀態就先設定一個基礎冷卻，防止在動畫期間又被判定攻擊
	monster.attack_cd_timer = monster.data.attack_cooldown
	_execute_attack()

func _execute_attack():
	if monster.is_dead or not monster.target_player or monster.data == null:
		_change_state("Idle")
		return
		
	var tgt_g := monster.get_nearest_hostile_target_global()
	var dir_to_tgt = (tgt_g - monster.global_position).normalized()
	
	if dir_to_tgt.x != 0:
		monster.anim.flip_h = (dir_to_tgt.x > 0)
	
	monster.play_monster_animation("attack")
	
	# 飛撲
	var lunge = create_tween()
	lunge.tween_property(monster, "global_position", 
	monster.global_position + dir_to_tgt * GlobalBalance.MONSTER_LUNGE_DIST, 0.2)\
	.set_trans(Tween.TRANS_QUINT)
	
	await get_tree().create_timer(0.25).timeout
	if monster.is_dead or monster.state_machine.current_state != self: return
	
	var attacker_hb: HurtboxComponent = monster.get_node_or_null("HurtboxComponent") as HurtboxComponent
	var should_retailiate := false
	if monster.target_player:
		var d = monster.global_position.distance_to(monster.target_player.global_position)
		if d < monster.data.attack_range + 60:
			var phealth: HealthComponent = monster.target_player.health if monster.target_player.get("health") else null
			var hp_before := phealth.current_hp if phealth else -1
			monster.target_player.take_damage(GlobalBalance.MONSTER_BASE_DAMAGE)
			if phealth and phealth.current_hp < hp_before:
				should_retailiate = true
			print("[Attack] 怪物咬了主角！")
	for pet in monster.get_tree().get_nodes_in_group("deployed_pet"):
		if pet and pet.has_method("take_damage_from_monster"):
			var dp = monster.global_position.distance_to(pet.global_position)
			if dp < monster.data.attack_range + 60:
				var pet_h: HealthComponent = pet.health if pet.get("health") else null
				var pet_before := pet_h.current_hp if pet_h else -1
				pet.take_damage_from_monster(GlobalBalance.MONSTER_BASE_DAMAGE)
				if pet_h and pet_h.current_hp < pet_before:
					should_retailiate = true
	if should_retailiate and attacker_hb != null and is_instance_valid(attacker_hb) and SignalBus:
		SignalBus.party_damaged_by_monster.emit(attacker_hb)

	if monster.anim.is_playing():
		await monster.anim.animation_finished
	
	if monster.is_dead or monster.state_machine.current_state != self: return
	
	# 攻擊結束，再次確認冷卻時間已設定
	monster.attack_cd_timer = monster.data.attack_cooldown
	_change_state("Chase")


func _execute_ranged_stone_toss() -> void:
	var sk: SkillResource = monster.data.ranged_basic_skill
	if sk == null or monster.is_dead:
		_change_state("Chase")
		return
	var em: Node = monster.get_tree().get_first_node_in_group("effect_manager") if monster.get_tree() else null
	var impact_world: Vector2 = monster.global_position
	if monster.target_player and is_instance_valid(monster.target_player):
		impact_world = monster.get_nearest_hostile_target_global()
	monster.play_monster_animation("attack")
	if em and sk.cast_fx_template_id.strip_edges() != "" and em.has_method("play_template_fx_by_id"):
		var facing := Vector2.RIGHT
		if monster.target_player and is_instance_valid(monster.target_player):
			var v := monster.target_player.global_position - monster.global_position
			if v.length_squared() > 0.0001:
				facing = v.normalized()
		em.play_template_fx_by_id(sk.cast_fx_template_id, monster.global_position, em, facing)
	if sk.type == SkillResource.SkillType.AOE_ATTACK and sk.aoe_use_ground_target:
		if em and em.has_method("play_ground_slam_aoe_from_skill"):
			em.play_ground_slam_aoe_from_skill(sk, monster, true, impact_world)
	await get_tree().create_timer(sk.trigger_delay).timeout
	if monster.is_dead or monster.state_machine.current_state != self:
		return
	if monster.anim.is_playing():
		await monster.anim.animation_finished
	if monster.is_dead or monster.state_machine.current_state != self:
		return
	monster.attack_cd_timer = monster.data.attack_cooldown
	_change_state("Chase")
