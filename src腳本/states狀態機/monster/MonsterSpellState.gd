# res://src腳本/states狀態機/monster/MonsterSpellState.gd (全量更新)
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
	
	# 1. 瞬移
	if skill.dash_before_skill and monster.target_player:
		await monster.perform_ghost_dash(skill.dash_distance)
		if monster.state_machine.current_state != self: return

	# 2. 蓄力喘息 (Startup) - 強制播 idle
	monster.play_monster_animation("idle")
	await get_tree().create_timer(skill.startup_time).timeout
	if monster.state_machine.current_state != self: return
	
	# 3. 播放 Spell 動畫
	monster.play_monster_animation(skill.animation_name)
	
	# 等待觸發延遲
	await get_tree().create_timer(skill.trigger_delay).timeout
	if monster.state_machine.current_state != self: return
	
	# 補血效果
	if skill.type == SkillResource.SkillType.HEAL:
		monster.health.current_hp += skill.power
		print("[Spell] %s 補血成功" % monster.name)
	
	if monster.anim.is_playing():
		await monster.anim.animation_finished
	if monster.state_machine.current_state != self: return
	
	# 4. 收招喘息 (Recovery) - 強制播 idle
	monster.play_monster_animation("idle")
	await get_tree().create_timer(skill.recovery_time).timeout
	if monster.state_machine.current_state != self: return
	
	_change_state("Chase")
