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
	if monster.data == null:
		monster.velocity = Vector2.ZERO
		return
	# 🔴 確保 velocity 有被設定
	monster.velocity = monster.wander_dir * monster.data.move_speed
	
	monster.state_timer -= delta
	if monster.state_timer <= 0:
		_change_state("Idle")
		
func _detect_player_logic():
	if monster.data == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = monster.global_position.distance_to(player.global_position)
		# 如果是主動怪，或者已經被打過了（target_player 已有值）
		if monster.data.aggro_type == MonsterResource.AggroType.AGGRESSIVE:
			if dist < monster.data.detection_range:
				monster.target_player = player
