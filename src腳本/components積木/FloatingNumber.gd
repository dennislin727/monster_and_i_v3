# res://src腳本/components積木/FloatingNumber.gd
extends Label

func start(value: int, color: Color) -> void:
	_animate(str(value), color)

func start_with_text(msg: String, color: Color) -> void:
	_animate(msg, color)

func _animate(content: String, text_color: Color) -> void:
	# 1. 基礎外觀設定
	text = content
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 2. 強化手機端視覺 (增加描邊)
	var settings = LabelSettings.new()
	settings.font_color = text_color
	settings.outline_size = 8
	settings.outline_color = Color.BLACK
	settings.font_size = 24
	label_settings = settings
	
	# 3. 確保縮放中心在正中央
	pivot_offset = size / 2
	
	# 4. 視覺動畫：先彈出再飄移漸隱
	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 向上飄移
	t.tween_property(self, "position:y", position.y - 120, 0.8)
	
	# 彈跳縮放效果
	scale = Vector2.ZERO
	t.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2)
	t.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	# 漸隱與刪除
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.6)
	t.chain().tween_callback(queue_free)
