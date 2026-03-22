# res://src腳本/states狀態機/monster/MonsterDieState.gd
extends MonsterState

func enter():
	monster.velocity = Vector2.ZERO
	# 🔴 關閉所有碰撞，徹底解決黏著
	monster.collision_layer = 0
	monster.collision_mask = 0
	
	# 強制播放死亡動畫
	monster.anim.stop()
	monster.play_monster_animation("die")
	
	# 掉落
	_spawn_loot()
	
	# 🔴 0.5秒後直接移除，不等動畫 finished 訊號 (防止靈異現象)
	await get_tree().create_timer(0.5).timeout
	monster.queue_free()

func _spawn_loot():
	if monster.data and monster.data.drop_item:
		if randf() <= monster.data.drop_chance:
			SignalBus.request_effect_collect.emit(monster.global_position, monster.data.drop_item.icon)
			SignalBus.item_collected.emit(monster.data.drop_item)
