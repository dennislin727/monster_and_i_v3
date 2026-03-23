# res://src腳本/states狀態機/monster/MonsterDieState.gd
extends MonsterState

func enter():
	# 1. 再次確保 Base 的死亡標記開啟
	monster.is_dead = true
	monster.velocity = Vector2.ZERO
	var ui_anchor = monster.get_node_or_null("UIAnchor")
	if ui_anchor:
		ui_anchor.hide()
	
	# 2. 徹底關閉碰撞與受擊感應，防止死後還被吸住或被打
	monster.set_collision_layer_value(2, false)
	monster.set_collision_mask_value(1, false)
	var hurtbox = monster.get_node_or_null("HurtboxComponent")
	if hurtbox: 
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	
	# 3. 播放動畫
	monster.play_monster_animation("die")
	
	# 4. 掉落物
	_spawn_loot()
	
	# 5. 等待動畫結束
	# 如果你的動畫叫 "die"，它會播完；如果沒有這個動畫，0.5秒後強行移除
	if monster.anim.sprite_frames.has_animation(monster.anim.animation):
		await monster.anim.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
		
	monster.queue_free()

func _spawn_loot():
	if monster.data and monster.data.drop_item:
		if randf() <= monster.data.drop_chance:
			SignalBus.request_effect_collect.emit(monster.global_position, monster.data.drop_item.icon)
			SignalBus.item_collected.emit(monster.data.drop_item)
