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
	_grant_gold_and_xp()
	_spawn_loot()
	
	# 等待動畫結束或強制消失
	if monster.anim.sprite_frames.has_animation("die"):
		await monster.anim.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
		
	monster.queue_free()

func _grant_gold_and_xp() -> void:
	if monster.data == null:
		return
	if InventoryManager and monster.data.gold_reward > 0:
		InventoryManager.add_gold(monster.data.gold_reward)
	if ProgressionManager and monster.data.xp_reward > 0:
		ProgressionManager.distribute_kill_xp(monster.data.xp_reward)


func _spawn_loot():
	if monster.data and monster.data.drop_item:
		# 🔴 這裡就是聯動！原本是 0.5，現在變成 0.5 * 1.0 = 0.5
		# 如果你在上帝撥盤改成 2.0，機率就變成 1.0 (必掉)！
		var final_chance = monster.data.drop_chance * GlobalBalance.GLOBAL_DROP_CHANCE_MODIFIER
		
		if randf() <= final_chance:
			# 這裡可以寫一個迴圈，讓怪噴出多個物品
			for i in range(GlobalBalance.GLOBAL_DROP_QUANTITY_BONUS):
				SignalBus.request_effect_collect.emit(monster.global_position, monster.data.drop_item.icon)
				SignalBus.item_collected.emit(monster.data.drop_item)
