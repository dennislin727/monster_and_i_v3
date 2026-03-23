# res://src腳本/components積木/FloatingNumber.gd
extends Label

func start(value: int, _color: Color) -> void:
	_animate(str(value), _color, false)

func start_with_text(msg: String, _color: Color) -> void:
	_animate(msg, _color, false)

# 新增補血專用入口
func start_heal(value: int) -> void:
	_animate("+" + str(value), Color.GREEN, true)

func _animate(content: String, text_color: Color, is_heal: bool) -> void:
	text = content
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var settings = LabelSettings.new()
	settings.font_color = text_color
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	settings.font_size = 15
	label_settings = settings
	pivot_offset = size / 2

	# --- [調整區] 動態參數設定 ---
	var rise_dist = 100.0   # 向上飄移距離
	var rise_time = 0.3     # 預設上升時間 (秒)
	var bounce_time = 0.1   # 預設彈跳時間 (秒)
	var fade_delay = 0.2    # 預設等待多久才消失 (秒)
	var fade_time = 0.4     # 預設漸隱時間 (秒)

	if is_heal:
		# 🔴 補血模式：讓這裏的數字變大、變慢
		rise_dist = 60.0    # 補血不用飄太高
		rise_time = 0.8     # 慢速上升 (原本 0.3 -> 0.8)
		bounce_time = 0.2   # 慢速彈開 (原本 0.1 -> 0.2)
		fade_delay = 0.6    # 停留在螢幕久一點 (原本 0.2 -> 0.6)
		fade_time = 0.8     # 慢慢消失 (原本 0.4 -> 0.8)
	# --------------------------

	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 1. 向上飄移
	t.tween_property(self, "position:y", position.y - rise_dist, rise_time)
	
	# 2. 彈跳縮放
	scale = Vector2(0.5, 0.5) if is_heal else Vector2.ONE
	t.tween_property(self, "scale", Vector2(1.5, 1.5), bounce_time)
	t.chain().tween_property(self, "scale", Vector2(1.0, 1.0), bounce_time)
	
	# 3. 漸隱消失
	t.parallel().tween_property(self, "modulate:a", 0.0, fade_time).set_delay(fade_delay)
	
	t.chain().tween_callback(queue_free)
