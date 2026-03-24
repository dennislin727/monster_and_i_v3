# res://src腳本/components積木/FloatingNumber.gd
extends Label

var track_target: Node2D = null
var offset_vector: Vector2 = Vector2.ZERO 
var is_persistent: bool = false           

# 1. 傷害用
func start(value: int, _color: Color) -> void:
	_animate(str(value), _color, false)

# 2. 治癒用
func start_heal(value: int) -> void:
	_animate("+" + str(value), Color.GREEN, true)

# 3. 封印結算入口 (白色、標準快閃動畫)
func start_seal_text(target: Node2D, msg: String) -> void:
	track_target = target
	is_persistent = false 
	
	var canvas_transform = get_viewport().get_canvas_transform()
	var screen_pos = canvas_transform * target.global_position
	var initial_offset = Vector2(0, -100) if target.is_in_group("player") else Vector2(0, -70)
	
	self.global_position = screen_pos + initial_offset
	_animate(msg, Color.WHITE, false)

# 4. 封印持久提示入口 (長壓提示：衛星呼吸模式)
func start_persistent_hint(target: Node2D, msg: String) -> void:
	track_target = target
	is_persistent = true
	offset_vector = Vector2(80, -70) 
	
	text = msg
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_setup_visuals(Color.WHITE)
	
	var t = create_tween().set_loops()
	t.tween_property(self, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

func dismiss() -> void:
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)

func _process(_delta: float) -> void:
	if is_instance_valid(track_target):
		var canvas_transform = get_viewport().get_canvas_transform()
		var screen_pos = canvas_transform * track_target.global_position
		if is_persistent:
			global_position = screen_pos + offset_vector - (size / 2)
	elif is_persistent:
		queue_free()

func _setup_visuals(txt_color: Color):
	var settings = LabelSettings.new()
	settings.font_color = txt_color
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	settings.font_size = 14
	label_settings = settings
	pivot_offset = size / 2

# --- 核心動畫引擎 (對接 GlobalBalance) ---
func _animate(content: String, text_color: Color, is_heal: bool) -> void:
	text = content
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_setup_visuals(text_color)
	
	# 🔴 從上帝撥盤讀取基礎數值
	var rise_dist = GlobalBalance.DAMAGE_RISE_DIST
	var fade_time = GlobalBalance.UI_TEXT_FADE_TIME
	var bounce_time = 0.1 # 彈跳通常很快，可固定
	var rise_time = 0.3
	var fade_delay = 0.2

	# 🎨 節奏微調：治癒字體會飄比較慢、停比較久
	if is_heal:
		rise_dist *= 0.6    # 飄短一點
		rise_time = 0.8     # 但飄慢一點
		fade_delay = 0.6    # 停久一點
		fade_time *= 1.2    # 消失也慢一點
	
	# 🎨 節奏微調：封印結算文字只飄一點點，但停超久讓你看清楚
	elif content.contains("!") or content.contains("."):
		rise_dist = 5.0   
		fade_delay = 0.8   
		fade_time *= 0.8

	# --- 執行 Tween 動畫 ---
	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 1. 向上飄移
	t.tween_property(self, "position:y", position.y - rise_dist, rise_time)
	
	# 2. 彈跳縮放 (治癒字體從 0.5 開始大，受傷字體從 1.0 開始大)
	scale = Vector2(0.5, 0.5) if is_heal else Vector2.ONE
	t.tween_property(self, "scale", Vector2(1.5, 1.5), bounce_time)
	t.chain().tween_property(self, "scale", Vector2(1.0, 1.0), bounce_time)
	
	# 3. 漸隱消失
	t.parallel().tween_property(self, "modulate:a", 0.0, fade_time).set_delay(fade_delay)
	t.chain().tween_callback(queue_free)
