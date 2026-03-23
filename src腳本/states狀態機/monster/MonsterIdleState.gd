# res://src腳本/states狀態機/monster/MonsterIdleState.gd
extends MonsterState

var idle_timer: float = 0.0

func enter():
	monster.velocity = Vector2.ZERO
	monster.play_monster_animation("idle")
	idle_timer = randf_range(1.5, 3.0)

func handle_physics(delta: float):
	# 🔴 修正：主動偵測玩家
	_detect_player_logic()
	
	if monster.target_player != null:
		_change_state("Chase")
		return

	idle_timer -= delta
	if idle_timer <= 0:
		_change_state("Wander")

# 抽取出來的偵測邏輯
func _detect_player_logic():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = monster.global_position.distance_to(player.global_position)
		# 如果是主動怪，或者已經被打過了（target_player 已有值）
		if monster.data.aggro_type == MonsterResource.AggroType.AGGRESSIVE:
			if dist < monster.data.detection_range:
				monster.target_player = player
