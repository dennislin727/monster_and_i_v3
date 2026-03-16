# res://src腳本/components積木/CollectEffect.gd
extends Sprite2D

func start_flying(start_pos: Vector2, target_pos: Vector2):
	self.global_position = start_pos
	
	# 動畫 1：噴發效果（先往上彈一下，像從石頭噴出來）
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var jump_pos = start_pos + Vector2(randf_range(-50, 50), -80) # 隨機左右噴
	tween.tween_property(self, "global_position", jump_pos, 0.4)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4) # 稍微變大
	
	await tween.finished
	
	# 動畫 2：飛向背包
	var fly_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(self, "global_position", target_pos, 0.6)
	fly_tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.6)
	fly_tween.tween_property(self, "modulate:a", 0.0, 0.6) # 漸隱
	
	await fly_tween.finished
	queue_free() # 飛到後消失
