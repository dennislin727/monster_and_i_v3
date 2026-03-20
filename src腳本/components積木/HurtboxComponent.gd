# res://src腳本/components積木/HurtboxComponent.gd
class_name HurtboxComponent
extends Area2D

@export var health: int = 999

func take_hit(_damage: int):
	# 執行受擊震動
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(get_parent(), "scale", Vector2(1.2, 0.8), 0.05)
	tween.tween_property(get_parent(), "scale", Vector2(1.0, 1.0), 0.1)
	print("[Dummy] 哎呀！被打到了，剩餘血量：", health)
	take_damage(_damage)

# res://src腳本/components積木/HurtboxComponent.gd
func take_damage(_amount: int):
	# 1. 閃紅光
	var parent = get_parent()
	parent.modulate = Color.RED
	
	# 2. 彈跳感
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(parent, "scale", Vector2(1.2, 0.8), 0.05) # 壓扁
	tween.tween_property(parent, "scale", Vector2(1.0, 1.0), 0.1)  # 彈回
	
	# 3. 恢復顏色
	await tween.finished
	parent.modulate = Color.WHITE
