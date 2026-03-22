# res://src腳本/states狀態機/monster/MonsterChaseState.gd
extends MonsterState

func enter():
	# print("[Chase] %s 鎖定目標，開始追擊！" % monster.name)
	monster.play_monster_animation("run")

func handle_physics(_delta: float):
	# 1. 如果失去玩家目標，回到待機
	if not monster.target_player:
		_change_state("Idle")
		return

	var hp_pct = float(monster.health.current_hp) / monster.health.max_hp

	# 2. 🔴 奧義檢查 (核心邏輯)
	# 條件：血量低於設定門檻，且技能 CD 好了
	var skill = monster.get_available_skill()
	if skill:
		# 這裡支持以後哥布林的計數觸發，或是史萊姆的血量觸發
		# 目前邏輯：只要資源定義的條件符合就放招
		_change_state("Spell")
		return

	# 3. 生存檢查：血量過低且沒技能可用，進入逃跑
	if hp_pct < 0.2:
		_change_state("Flee")
		return

	# 4. 距離判定
	var dist = monster.global_position.distance_to(monster.target_player.global_position)
	
	if dist > monster.data.detection_range * 2.0:
		print("[AI] 玩家跑太遠了，%s 放棄追逐" % monster.name)
		monster.target_player = null # 清空仇恨
		_change_state("Idle")
		return
	if dist <= monster.data.attack_range:
		# 距離夠近，進入攻擊狀態
		_change_state("Attack")
	else:
		# 距離還遠，繼續移動
		var dir = (monster.target_player.global_position - monster.global_position).normalized()
		monster.velocity = dir * monster.data.chase_speed
		monster.play_monster_animation("run")
