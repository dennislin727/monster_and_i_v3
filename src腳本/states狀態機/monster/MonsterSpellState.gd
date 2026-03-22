# res://src腳本/states狀態機/monster/MonsterSpellState.gd
extends MonsterState

func enter():
	# 1. 取得目前該放哪一招
	var skill = monster.get_available_skill()
	if not skill:
		_change_state("Chase")
		return
	
	# 2. 啟動奧義序列 (此狀態會鎖死物理 AI，直到結束)
	_start_spell_sequence(skill)

func _start_spell_sequence(skill: SkillResource):
	# 🔴 鎖定身體：施法期間禁止自主移動
	monster.velocity = Vector2.ZERO
	monster.skill_cds[skill] = skill.cooldown # 進入冷卻
	
	var dir = monster.get_dir_string()
	
	# --- 階段一：鬼魅瞬移 (如果資源勾選) ---
	if skill.dash_before_skill and monster.target_player:
		print("[Spell] 執行瞬移位移...")
		await monster.perform_ghost_dash(skill.dash_distance)
	
	# --- 階段二：蓄力喘息 (Startup) ---
	# 展現招式前的壓迫感，播放待機動畫
	monster.play_monster_animation("idle")
	await get_tree().create_timer(skill.startup_time).timeout
	
	# --- 階段三：真正施法 (Trigger) ---
	# 播放奧義動畫 (例如 spell)
	monster.play_monster_animation(skill.animation_name)
	
	# 等待資源設定的「發動點」延遲
	await get_tree().create_timer(skill.trigger_delay).timeout
	
	# 執行技能效果 (補血或傷害)
	_apply_effect(skill)
	
	# 等待動畫播完 (如果動畫很長)
	if monster.anim.is_playing():
		await monster.anim.animation_finished
	
	# --- 階段四：收招僵直 (Recovery) ---
	# 施法完畢，播放收招動畫 (如喘氣或跌倒)
	# 這裡我們支持資源自定義收招動畫，預設是 idle
	var recovery_anim = skill.get("recovery_animation") if skill.has_method("get") else "idle"
	monster.play_monster_animation(recovery_anim)
	
	print("[Spell] 奧義收招中，留下破綻...")
	await get_tree().create_timer(skill.recovery_time).timeout
	
	# --- 序列結束：恢復追擊 ---
	_change_state("Chase")

func _apply_effect(skill: SkillResource):
	if skill.type == SkillResource.SkillType.HEAL:
		monster.health.current_hp += skill.power
		print("[Spell] %s 治癒成功！恢復了 %d HP" % [monster.name, skill.power])
	elif skill.type == SkillResource.SkillType.AOE_ATTACK:
		# 未來哥布林的範圍傷害判定點
		print("[Spell] %s 發動了範圍攻擊！" % monster.name)

func exit():
	# 安全清理：確保離開狀態時，怪物的視覺效果是正常的
	monster.anim.modulate.a = 1.0
	monster.anim.scale = Vector2.ONE
