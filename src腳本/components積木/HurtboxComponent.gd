# res://src腳本/components積木/HurtboxComponent.gd
class_name HurtboxComponent
extends Area2D

func take_damage(amount: int) -> void:
	var parent = get_parent()
	var health = parent.get_node_or_null("HealthComponent")
	
	if health:
		print("[Hurtbox] 成功傳遞傷害: ", amount)
		health.take_damage(amount)
		SignalBus.damage_spawned.emit(global_position, amount, false)
	
	# 受擊視覺
	var t = create_tween()
	parent.modulate = Color.RED
	t.tween_property(parent, "modulate", Color.WHITE, 0.2)
