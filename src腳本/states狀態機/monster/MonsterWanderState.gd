# res://src腳本/states狀態機/monster/MonsterWanderState.gd
extends MonsterState

var wander_timer: float = 0.0

func enter():
	# 1. 隨機選一個遊走方向
	monster.wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# 2. 設定遊走時間（短距離跳動）
	wander_timer = randf_range(0.6, 1.5)
	
	# 3. 播放移動動畫
	monster.play_monster_animation("run")
	# print("[AI] %s 開始隨機遊走" % monster.name)

func handle_physics(delta: float):
	# 1. 🔴 優先級檢查：如果發現玩家，立刻進入追擊
	if monster.target_player != null:
		_change_state("Chase")
		return

	# 2. 執行移動
	if monster.data:
		monster.velocity = monster.wander_dir * monster.data.move_speed
	
	# 3. 倒數計時
	wander_timer -= delta
	if wander_timer <= 0:
		_change_state("Idle")
