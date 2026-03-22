# res://src腳本/states狀態機/MonsterSpellState.gd
extends MonsterState

func enter():
	var skill = monster._get_available_skill()
	if not skill: 
		monster.state_machine.change_state(get_node("../Chase"))
		return
	
	execute_sequence(skill)

func execute_sequence(skill: SkillResource):
	monster.velocity = Vector2.ZERO
	monster.skill_cds[skill] = skill.cooldown
	
	# A. 瞬移
	if skill.dash_before_skill and monster.target_player:
		# 執行壓扁消失動畫... (代碼略，同之前)
		await monster._perform_ghost_dash(skill.dash_distance)
	
	# B. 蓄力 (Idle)
	monster.play_monster_animation("idle_" + monster.get_dir_string())
	await get_tree().create_timer(skill.startup_time).timeout
	
	# C. 施法
	monster.play_monster_animation(skill.animation_name)
	await get_tree().create_timer(skill.trigger_delay).timeout
	if skill.type == SkillResource.SkillType.HEAL:
		monster.health.current_hp += skill.power
	
	# D. 收招 (Idle)
	if monster.anim.is_playing(): await monster.anim.animation_finished
	monster.play_monster_animation("idle_" + monster.get_dir_string())
	await get_tree().create_timer(skill.recovery_time).timeout
	
	# 回到追擊
	monster.state_machine.change_state(get_node("../Chase"))
