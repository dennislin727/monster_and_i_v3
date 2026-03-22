# res://src腳本/components積木/FloatingNumber.gd
extends Label

func start(value: int, color: Color):
	text = str(value)
	modulate = color
	# 向上飄動並淡出的 Tween
	var t = create_tween().set_parallel(true)
	t.tween_property(self, "position:y", position.y - 60, 0.6)
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(queue_free)
