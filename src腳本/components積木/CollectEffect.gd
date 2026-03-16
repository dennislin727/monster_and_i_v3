# res://src/components/CollectEffect.gd
extends Sprite2D

func start_flying(start_pos: Vector2, target_pos: Vector2):
	global_position = start_pos
	scale = Vector2(0.5, 0.5)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 往上彈一下再飛向角落
	tween.tween_property(self, "global_position", start_pos + Vector2(0, -50), 0.3)
	
	# 第二階段：飛往左上角（通常是背包位置）
	var fly_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	await tween.finished
	fly_tween.tween_property(self, "global_position", Vector2(50, 50), 0.6)
	fly_tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.6)
	
	await fly_tween.finished
	queue_free()
