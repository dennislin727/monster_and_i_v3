# res://src腳本/components積木/FloatingNumber.gd
extends Label

var track_target: Node2D = null
var offset_vector: Vector2 = Vector2.ZERO # 🔴 用 Vector2 統一處理偏移
var is_persistent: bool = false           # 🔴 標記是否為「持久提示」

# 1. 傷害用 (維持原樣)
func start(value: int, _color: Color) -> void:
	_animate(str(value), _color, false)

# 2. 治癒用 (維持原樣)
func start_heal(value: int) -> void:
	_animate("+" + str(value), Color.GREEN, true)

# 3. 封印結算入口 (Success/Fail：白色、標準快閃動畫)
func start_seal_text(target: Node2D, msg: String) -> void:
	track_target = target
	is_persistent = false # 確保是快閃模式
	
	# 🔴 核心修復：在動畫開始前，先計算並設定一次初始位置
	# 因為 top_level = true，必須手動對齊螢幕座標
	var canvas_transform = get_viewport().get_canvas_transform()
	var screen_pos = canvas_transform * target.global_position
	var initial_offset = Vector2(0, -100) if target.is_in_group("player") else Vector2(0, -70)
	
	self.global_position = screen_pos + initial_offset
	_animate(msg, Color.WHITE, false)

# 🟢 4. 封印持久提示入口 (長壓提示：衛星呼吸模式)
func start_persistent_hint(target: Node2D, msg: String) -> void:
	track_target = target
	is_persistent = true
	
	# 🔴 [位置微調區] 這裡設定字體出現在怪物的：[右方 80, 上方 70]
	offset_vector = Vector2(80, -70) 
	
	text = msg
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 套用視覺設定 (白色小字)
	_setup_visuals(Color.WHITE)
	
	# 🟢 呼吸動畫：持久模式專屬，不會自動 queue_free
	var t = create_tween().set_loops()
	t.tween_property(self, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

# 🟢 提供給 SealingComponent 手動消除的方法
func dismiss() -> void:
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)

func _process(_delta: float) -> void:
	if is_instance_valid(track_target):
		var canvas_transform = get_viewport().get_canvas_transform()
		var screen_pos = canvas_transform * track_target.global_position
		
		if is_persistent:
			# 持久模式：每一幀都「黏」在側邊
			global_position = screen_pos + offset_vector - (size / 2)
		else:
			# 🟢 快閃模式：不需要在 _process 裡更新
			# 因為 _animate 裡的 Tween 會控制它向上飄移，我們不准干擾它
			pass
	elif is_persistent:
		queue_free()

# 輔助：視覺設定
func _setup_visuals(txt_color: Color):
	var settings = LabelSettings.new()
	settings.font_color = txt_color
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	settings.font_size = 14
	label_settings = settings
	pivot_offset = size / 2

# --- 核心動畫引擎 (維持你最滿意的數值) ---
func _animate(content: String, text_color: Color, is_heal: bool) -> void:
	text = content
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_setup_visuals(text_color)
	
	# 數值微調區
	var rise_dist = 110.0   
	var rise_time = 0.3     
	var bounce_time = 0.1   
	var fade_delay = 0.2    
	var fade_time = 0.4     

	if is_heal:
		rise_dist = 60.0    
		rise_time = 0.8     
		bounce_time = 0.2   
		fade_delay = 0.6    
		fade_time = 0.8
	
	elif content.contains("!") or content.contains("."):
		rise_dist = 5.0   # 封印結算只飄一點點
		fade_delay = 0.8   # 停在頭上久一點 (0.2 -> 0.8) 讓玩家看清楚
		fade_time = 0.6    # 慢慢消失

	# --------------------------

	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 1. 向上飄移 (現在 rise_dist 會根據模式變化了)
	t.tween_property(self, "position:y", position.y - rise_dist, rise_time)
	
	# 2. 彈跳縮放
	scale = Vector2(0.5, 0.5) if is_heal else Vector2.ONE
	t.tween_property(self, "scale", Vector2(1.5, 1.5), bounce_time)
	t.chain().tween_property(self, "scale", Vector2(1.0, 1.0), bounce_time)
	
	# 3. 漸隱消失
	t.parallel().tween_property(self, "modulate:a", 0.0, fade_time).set_delay(fade_delay)
	
	t.chain().tween_callback(queue_free)
