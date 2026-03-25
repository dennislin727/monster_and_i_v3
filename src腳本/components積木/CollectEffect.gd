# res://src腳本/components積木/CollectEffect.gd
extends Node2D

func start_flying(start_pos: Vector2, target_pos: Vector2):
	self.global_position = start_pos
	
	# 初始縮放 (配合你的 0.5 啟動感)
	self.scale = Vector2(0.5, 0.5)
	
	# 動畫 1：噴發效果
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var jump_pos = start_pos + Vector2(randf_range(-50, 50), -80) 
	tween.tween_property(self, "global_position", jump_pos, 0.4)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4) # 彈出來變回正常大
	
	await tween.finished
	
	# 動畫 2：飛向目標 (優雅曲線可留給未來，我們先修好邏輯)
	var fly_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(self, "global_position", target_pos, 0.6)
	fly_tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.6)
	fly_tween.tween_property(self, "modulate:a", 0.0, 0.6) 
	
	await fly_tween.finished
	queue_free()
