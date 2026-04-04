# res://src腳本/states狀態機/monster/MonsterSpellState.gd
extends MonsterState

func enter():
	var skill = monster.get_available_skill()
	if not skill:
		_change_state("Chase")
		return
	_execute_sequence(skill)

func _execute_sequence(skill: SkillResource):
	monster.velocity = Vector2.ZERO
	monster.skill_cds[skill] = skill.cooldown
	var effect_manager := get_tree().get_first_node_in_group("effect_manager")
	var facing := _facing_to_target()
	
	# 🔴 核心修復：施法開始，開啟霸體保護
	monster.is_casting_protected = true
	if effect_manager and skill.telegraph_fx_template_id != "" and effect_manager.has_method("play_template_fx_by_id"):
		effect_manager.play_template_fx_by_id(skill.telegraph_fx_template_id, monster.global_position, effect_manager, facing)
	
	# 1. 瞬移
	if skill.dash_before_skill and monster.target_player:
		await monster.perform_ghost_dash(skill.dash_distance)
		if monster.state_machine.current_state != self: 
			_clear_protection()
			return

	# 2. 蓄力喘息 (Startup) - 強制播 idle
	monster.play_monster_animation("idle")
	await get_tree().create_timer(skill.startup_time).timeout
	if monster.state_machine.current_state != self: 
		_clear_protection()
		return
	
	# 3. 播放 Spell 動畫（落地圈 AOE 鎖定施法當下目標位置）
	var impact_world: Vector2 = monster.global_position
	if monster.target_player and is_instance_valid(monster.target_player):
		impact_world = monster.target_player.global_position
	monster.play_monster_animation(skill.animation_name)
	if effect_manager and skill.cast_fx_template_id != "" and effect_manager.has_method("play_template_fx_by_id"):
		effect_manager.play_template_fx_by_id(skill.cast_fx_template_id, monster.global_position, effect_manager, facing)
	
	if skill.type == SkillResource.SkillType.AOE_ATTACK and skill.aoe_use_ground_target:
		if effect_manager and effect_manager.has_method("play_ground_slam_aoe_from_skill"):
			effect_manager.play_ground_slam_aoe_from_skill(skill, monster, true, impact_world)
	
	# 等待觸發延遲（與 GroundSlam 警示／拋物線時長一致）
	await get_tree().create_timer(skill.trigger_delay).timeout
	if monster.state_machine.current_state != self: 
		_clear_protection()
		return
	
	# 補血效果與文字
	if skill.type == SkillResource.SkillType.HEAL:
		monster.health.current_hp += skill.power
		print("[Spell] %s 補血成功" % monster.name)
		SignalBus.heal_spawned.emit(monster.global_position, skill.power)
	elif skill.type == SkillResource.SkillType.AOE_ATTACK and not skill.aoe_use_ground_target:
		if effect_manager and effect_manager.has_method("play_line_sweep_aoe_from_skill"):
			effect_manager.play_line_sweep_aoe_from_skill(skill, monster, true)
	if effect_manager and skill.impact_fx_template_id != "" and effect_manager.has_method("play_template_fx_by_id"):
		effect_manager.play_template_fx_by_id(skill.impact_fx_template_id, monster.global_position, effect_manager, facing)
	
	if monster.anim.is_playing():
		await monster.anim.animation_finished
	if monster.state_machine.current_state != self: 
		_clear_protection()
		return
	
	# 4. 收招喘息 (Recovery) - 強制播 idle
	# 🔴 策略調整：通常補完血後的這段喘息時間是解除霸體的最佳時機（留給玩家反擊的破綻）
	monster.is_casting_protected = false 
	
	monster.play_monster_animation("idle")
	await get_tree().create_timer(skill.recovery_time).timeout
	
	if monster.state_machine.current_state != self: return
	
	_change_state("Chase")

# 當狀態被強行中斷時（例如怪物突然死亡），確保霸體關閉
func exit():
	_clear_protection()

func _clear_protection():
	monster.is_casting_protected = false

func _facing_to_target() -> Vector2:
	if monster.target_player and is_instance_valid(monster.target_player):
		var v := (monster.target_player.global_position - monster.global_position)
		if v.length() > 0.001:
			return v.normalized()
	return Vector2.RIGHT
