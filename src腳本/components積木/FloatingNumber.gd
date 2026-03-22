# res://src腳本/components積木/FloatingNumber.gd
extends Label

func start(value: int, _color: Color) -> void:
	text = str(value)
	modulate = Color.WHITE
	pivot_offset = size / 2
	
	# 視覺動畫
	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", position.y - 100, 0.6)
	t.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	t.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.4)
	t.chain().tween_callback(queue_free)
