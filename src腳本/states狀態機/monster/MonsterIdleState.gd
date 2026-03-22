# res://src腳本/states狀態機/monster/MonsterIdleState.gd
extends MonsterState

var idle_timer: float = 0.0

func enter():
	# 1. 停止移動
	monster.velocity = Vector2.ZERO
	
	# 2. 播放待機動畫（自動根據最後方向）
	monster.play_monster_animation("idle")
	
	# 3. 隨機決定待機多久（愜意的長待機）
	idle_timer = randf_range(2.0, 4.5)
	# print("[AI] %s 開始發呆..." % monster.name)

func handle_physics(delta: float):
	# 1. 🔴 優先級檢查：如果發現玩家，立刻進入追擊
	if monster.target_player != null:
		_change_state("Chase")
		return

	# 2. 倒數計時
	idle_timer -= delta
	if idle_timer <= 0:
		_change_state("Wander")
