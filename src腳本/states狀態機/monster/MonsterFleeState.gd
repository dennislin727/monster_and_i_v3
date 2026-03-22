# res://src腳本/states狀態機/monster/MonsterFleeState.gd
extends MonsterState

func enter():
	print("[FleeState] %s 感到生命威脅，開始遁走！" % monster.data.monster_name)
	# 逃跑時稍微提高一點速度，增加緊張感
	monster.play_monster_animation("run_" + monster.get_dir_string())

func handle_physics(_delta: float):
	# 1. 如果主角不見了，就回到待機
	if not monster.target_player:
		monster.state_machine.change_state(get_node("../Idle"))
		return
		
	# 2. 🔴 核心邏輯：逃跑時也要「隨時檢查」奧義 CD 是否好了
	# 一旦 CD 好了，立刻從逃跑切換到 Spell 狀態（執行閃現補血）
	var skill = monster._get_available_skill()
	if skill:
		monster.state_machine.change_state(get_node("../Spell"))
		return

	# 3. 計算逃跑向量：遠離玩家的方向
	var flee_dir = (monster.global_position - monster.target_player.global_position).normalized()
	
	# 加上一點點隨機偏移，讓逃跑路徑不會太死板（像是在繞圈圈逃）
	flee_dir = flee_dir.rotated(randf_range(-0.2, 0.2))
	
	monster.velocity = flee_dir * monster.data.chase_speed * 1.1
	
	# 4. 視覺更新
	monster.play_monster_animation("run_" + monster.get_dir_string())
	if monster.velocity.x != 0:
		monster.anim.flip_h = (monster.velocity.x > 0)
