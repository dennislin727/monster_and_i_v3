# res://src腳本/states狀態機/monster/MonsterDieState.gd
extends MonsterState

func enter():
	# 1. 鎖死所有物理與碰撞
	monster.velocity = Vector2.ZERO
	monster.set_collision_layer_value(1, false) # 關閉碰撞，防止屍體擋路
	monster.set_collision_mask_value(1, false)
	
	# 2. 播放死亡動畫
	monster.play_monster_animation("die")
	print("[DieState] %s 倒下了..." % monster.name)
	
	# 3. 🔴 掉落物噴發邏輯
	_spawn_loot()
	
	# 4. 等待動畫播放完畢後消失
	if monster.anim.is_playing():
		await monster.anim.animation_finished
	
	monster.queue_free()

func _spawn_loot():
	var data = monster.data
	if data and data.drop_item:
		# 根據機率判定
		if randf() <= data.drop_chance:
			print("[DieState] 掉落道具：%s" % data.drop_item.display_name)
			# 發射噴發特效訊號 (飛向背包)
			SignalBus.request_effect_collect.emit(monster.global_position, data.drop_item.icon)
			# 正式加入背包數據
			SignalBus.item_collected.emit(data.drop_item)
