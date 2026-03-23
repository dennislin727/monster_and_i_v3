# res://src腳本/states狀態機/monster/MonsterDieState.gd
extends MonsterState

func enter():
	monster.is_dead = true
	monster.velocity = Vector2.ZERO
	
	# 🔴 核心修復：立即關閉 Hurtbox 的偵測
	var hurtbox = monster.get_node_or_null("HurtboxComponent")
	if hurtbox:
		# 使用 set_deferred 確保在物理幀安全關閉
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		# 關閉所有碰撞層位
		hurtbox.collision_layer = 0
		hurtbox.collision_mask = 0

	var ui_anchor = monster.get_node_or_null("UIAnchor")
	if ui_anchor: ui_anchor.hide()
	
	monster.play_monster_animation("die")
	_spawn_loot()
	
	# 等待動畫結束或強制消失
	if monster.anim.sprite_frames.has_animation("die"):
		await monster.anim.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
		
	monster.queue_free()

func _spawn_loot():
	if monster.data and monster.data.drop_item:
		if randf() <= monster.data.drop_chance:
			SignalBus.request_effect_collect.emit(monster.global_position, monster.data.drop_item.icon)
			SignalBus.item_collected.emit(monster.data.drop_item)
