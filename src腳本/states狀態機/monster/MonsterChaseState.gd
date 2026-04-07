# res://src腳本/states狀態機/monster/MonsterChaseState.gd
extends MonsterState

## 遠程拉開：距離在門檻附近抖動時，用闩鎖避免每幀在「拉開／靠近」間切換造成動畫跳幀。
var _ranged_retreat_latched: bool = false

func enter():
	_ranged_retreat_latched = false
	monster.play_monster_animation("run")

func handle_physics(_delta: float):
	if monster.is_dead or not monster.target_player:
		_change_state("Idle")
		return
	if monster.data == null:
		_change_state("Idle")
		return

	var tgt := monster.get_nearest_hostile_target_global()
	var dist = monster.global_position.distance_to(tgt)
	var dir = (tgt - monster.global_position).normalized()
	var hp_pct = float(monster.health.current_hp) / monster.health.max_hp
	var ranged := monster.data.combat_style == MonsterResource.CombatStyle.RANGED_KITER

	# 1. 低血量逃跑
	if hp_pct < 0.2:
		_change_state("Flee")
		return

	# 2. 遠程：主角太近時先拉開，不貼身施法（帶遲滯避免邊界抖動）
	if ranged:
		var rb: float = monster.data.kite_retreat_below
		if dist < rb:
			_ranged_retreat_latched = true
		elif dist > rb + 24.0:
			_ranged_retreat_latched = false
		if _ranged_retreat_latched:
			monster.velocity = -dir * monster.data.chase_speed
			monster.play_monster_animation("run")
			return

	# 3. 技能（Spell 大絕：補血／攝影機橫掃等）
	var skill = monster.get_available_skill()
	if skill:
		_change_state("Spell")
		return

	# 3b. 遠程普攻（投石）：與 Spell 分開，吃 attack_cooldown
	if ranged and monster.data.ranged_basic_skill and monster.attack_cd_timer <= 0:
		var rmin: float = monster.data.ranged_basic_min_dist
		if dist >= rmin and dist <= monster.data.kite_chase_above:
			_change_state("Attack")
			return

	# 4. 遠程：距離過大時靠近到打擊距離
	if ranged:
		if dist > monster.data.kite_chase_above:
			monster.velocity = dir * monster.data.chase_speed
			monster.play_monster_animation("run")
			return
		monster.velocity = dir * monster.data.move_speed * 0.35
		monster.play_monster_animation("run")
		return

	# 5. 近戰：攻擊與追逐判定
	if dist <= monster.data.attack_range + 15:
		if monster.attack_cd_timer <= 0:
			# 🔴 CD 好了，發動飛撲！
			_change_state("Attack")
		else:
			# 🔴 修正：CD 沒好時，如果距離「超級近」(例如貼身)，才播放 idle
			if dist < 35:
				monster.velocity = Vector2.ZERO
				monster.play_monster_animation("idle")
			else:
				# 🔴 修正：距離還有一點點時，保持「跑步」動畫與「正常速度」貼近主角
				# 這樣就不會出現緩慢爬行的感覺
				monster.velocity = dir * monster.data.chase_speed
				monster.play_monster_animation("run")
	else:
		# 6. 正常距離追逐
		monster.velocity = dir * monster.data.chase_speed
		monster.play_monster_animation("run")
