# res://src腳本/states狀態機/monster/MonsterFleeState.gd
extends MonsterState

func enter():
	# print("[FleeState] %s 試圖逃離..." % monster.name)
	monster.play_monster_animation("run")

func handle_physics(_delta: float):
	# 1. 隨時檢查技能是否冷卻完畢 (逃跑是為了等 CD)
	var skill = monster.get_available_skill()
	if skill:
		_change_state("Spell")
		return

	# 2. 如果玩家追丟了，回到待機
	if not monster.target_player:
		_change_state("Idle")
		return

	# 3. 執行逃離位移：遠離玩家的方向
	var flee_dir = (monster.global_position - monster.target_player.global_position).normalized()
	monster.velocity = flee_dir * monster.data.chase_speed * 1.1 # 逃跑稍微快一點
	
	monster.play_monster_animation("run")
