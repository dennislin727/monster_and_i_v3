# res://src腳本/states狀態機/monster/MonsterWanderState.gd
extends MonsterState

func enter():
	monster.state_timer = randf_range(0.8, 1.8)
	monster.wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	monster.play_monster_animation("run")

func handle_physics(delta: float):
	if monster.target_player:
		_change_state("Chase")
		return
		
	# 🔴 確保 velocity 有被設定
	monster.velocity = monster.wander_dir * monster.data.move_speed
	
	monster.state_timer -= delta
	if monster.state_timer <= 0:
		_change_state("Idle")
