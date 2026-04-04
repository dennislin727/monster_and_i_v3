# res://src腳本/components積木/CollectEffect.gd
extends Node2D

var _arc_p0: Vector2
var _arc_p1: Vector2
var _arc_p2: Vector2


func _apply_dialogue_arc_t(t: float) -> void:
	var u := 1.0 - t
	global_position = u * u * _arc_p0 + 2.0 * u * t * _arc_p1 + t * t * _arc_p2


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


## 對話獲獎：先小幅彈起，再以二次貝塞爾拋物線落向螢幕下方（起訖皆為螢幕座標）
func start_flying_dialogue_reward_arc(start_pos: Vector2, end_pos: Vector2, duration: float = 0.72) -> void:
	global_position = start_pos
	scale = Vector2(0.38, 0.38)
	modulate = Color(1, 1, 1, 1)
	var tw_pop := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pop := start_pos + Vector2(randf_range(-22.0, 22.0), -52.0)
	tw_pop.tween_property(self, "global_position", pop, 0.2)
	tw_pop.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.2)
	await tw_pop.finished
	var mid := (pop + end_pos) * 0.5
	var ctrl := mid + Vector2(randf_range(64.0, 120.0) * (1.0 if randf() > 0.5 else -1.0), (end_pos.y - pop.y) * 0.22)
	_arc_p0 = pop
	_arc_p1 = ctrl
	_arc_p2 = end_pos
	var tw_arc := create_tween()
	tw_arc.tween_method(_apply_dialogue_arc_t, 0.0, 1.0, duration)
	tw_arc.parallel().tween_property(self, "scale", Vector2(0.12, 0.12), duration * 0.92)
	tw_arc.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.95)
	await tw_arc.finished
	queue_free()
