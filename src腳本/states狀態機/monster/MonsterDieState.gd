# res://src腳本/states狀態機/monster/MonsterDieState.gd
extends MonsterState

func enter():
	# 1. 物理鎖死
	monster.velocity = Vector2.ZERO
	monster.set_collision_layer_value(1, false)
	monster.set_collision_mask_value(1, false)
	
	# 2. 播放死亡
	monster.play_monster_animation("die")
	print("[DieState] 執行死亡演出: ", monster.name)
	
	# 3. 掉落
	_spawn_loot()
	
	# 4. 🔴 核心修正：加一個 1.5 秒保險絲，防止動畫沒發訊號導致怪物不消失
	var timer = get_tree().create_timer(1.5)
	
	# 監聽動畫結束或時間到
	if monster.anim.is_playing():
		await monster.anim.animation_finished
	else:
		await timer.timeout
	
	monster.queue_free()

func _spawn_loot():
	if monster.data and monster.data.drop_item:
		if randf() <= monster.data.drop_chance:
			SignalBus.request_effect_collect.emit(monster.global_position, monster.data.drop_item.icon)
			SignalBus.item_collected.emit(monster.data.drop_item)
