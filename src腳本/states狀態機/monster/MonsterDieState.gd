# res://src腳本/states狀態機/monster/MonsterDieState.gd
extends MonsterState

func enter():
	print("[DieState] 進入死亡積木")
	monster.velocity = Vector2.ZERO
	monster.collision_layer = 0
	monster.collision_mask = 0
	
	# 🔴 強制重啟死亡動畫
	monster.anim.stop()
	monster.play_monster_animation("die")
	
	_spawn_loot()
	
	# 🔴 雙重保險：如果動畫沒發訊號，0.8秒後也強行移除
	var timer = get_tree().create_timer(0.8)
	if monster.anim.sprite_frames.has_animation("die"):
		await monster.anim.animation_finished
	else:
		await timer.timeout
		
	monster.queue_free()

func _spawn_loot():
	if monster.data and monster.data.drop_item:
		if randf() <= monster.data.drop_chance:
			SignalBus.request_effect_collect.emit(monster.global_position, monster.data.drop_item.icon)
			SignalBus.item_collected.emit(monster.data.drop_item)
