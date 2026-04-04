# res://src腳本/components積木/FloatingNumber.gd
extends Label

## 與 Main／帳簿 UI 相同；LabelSettings 未指定 font 時在 Android 會退回系統預設字體，中文易變方塊／亂碼。
const _PIXEL_FONT: FontFile = preload("res://assets圖片_字體_音效/PixelFont.ttf")

var track_target: Node2D = null
var offset_vector: Vector2 = Vector2.ZERO 
var is_persistent: bool = false           
var active_tween: Tween = null # 🟢 新增：用於追蹤並管理當前動畫，防止 Tween 衝突

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
	# 主角與怪物高度不同，給予不同偏移
	var initial_offset = Vector2(0, -100) if target.is_in_group("player") else Vector2(0, -70)
	
	self.global_position = screen_pos + initial_offset
	_animate(msg, Color.WHITE, false)

# 4. 封印持久提示入口 (長壓提示：衛星呼吸模式)
func start_persistent_hint(target: Node2D, msg: String) -> void:
	# 🟢 1. 出生瞬間：先把自己關燈 (透明度 0)
	modulate.a = 0 
	
	track_target = target
	is_persistent = true
	offset_vector = Vector2(80, -70) 
	text = msg
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_setup_visuals(Color.WHITE)
	
	# 🟢 2. 關鍵黑科技：等兩幀 (讓系統 Layout 算好 Size，且 _process 抓到座標)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 🟢 3. 此時座標已經被 _process 修正好了，這才開燈並開始呼吸
	var intro_t = create_tween()
	intro_t.tween_property(self, "modulate:a", 1.0, 0) # 順便給個 0.2s 漸顯更絲滑
	
	if active_tween: active_tween.kill()
	active_tween = create_tween().set_loops()
	active_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_SINE)
	active_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)

# 5. 強制關閉入口 (由 SealingComponent 呼叫)
func dismiss() -> void:
	# 🟢 核心修正：立刻殺死呼吸動畫，否則會跟消失動畫打架
	if active_tween: 
		active_tween.kill()
	
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)

func _process(_delta: float) -> void:
	# 衛星跟隨邏輯
	if is_instance_valid(track_target):
		var canvas_transform = get_viewport().get_canvas_transform()
		var screen_pos = canvas_transform * track_target.global_position
		if is_persistent:
			# 考慮 Label 尺寸進行居中偏移
			global_position = screen_pos + offset_vector - (size / 2)
	elif is_persistent:
		# 如果追蹤目標消失（如怪物被刪除），持久文字也應自動消失
		queue_free()

func _setup_visuals(txt_color: Color):
	var settings = LabelSettings.new()
	settings.font = _PIXEL_FONT
	settings.font_color = txt_color
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	settings.font_size = 14
	label_settings = settings
	# 設定縮放中心點為文字中央
	pivot_offset = size / 2

# --- 核心動畫引擎 (對接 GlobalBalance) ---
func _animate(content: String, text_color: Color, is_heal: bool) -> void:
	text = content
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_setup_visuals(text_color)
	
	# 🔴 數值解耦：從上帝撥盤讀取視覺基準
	var rise_dist = GlobalBalance.DAMAGE_RISE_DIST
	var fade_time = GlobalBalance.UI_TEXT_FADE_TIME
	var bounce_time = 0.1 
	var rise_time = 0.3
	var fade_delay = 0.2

	# 🎨 治癒演出微調：節奏較輕柔
	if is_heal:
		rise_dist *= 0.6    
		rise_time = 0.8     
		fade_delay = 0.6    
		fade_time *= 1.2    
	
	# 🎨 封印成功/失敗文字微調：幾乎不移動，讓玩家看清楚
	elif content.contains("!") or content.contains("."):
		rise_dist = 5.0   
		fade_delay = 0.8   
		fade_time *= 0.8

	# --- 執行演出 Tween ---
	if active_tween: active_tween.kill()
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 1. 位移
	active_tween.tween_property(self, "position:y", position.y - rise_dist, rise_time)
	
	# 2. 彈跳縮放
	scale = Vector2(0.5, 0.5) if is_heal else Vector2.ONE
	active_tween.tween_property(self, "scale", Vector2(1.5, 1.5), bounce_time)
	active_tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), bounce_time)
	
	# 3. 漸隱與自動銷毀
	active_tween.parallel().tween_property(self, "modulate:a", 0.0, fade_time).set_delay(fade_delay)
	active_tween.chain().tween_callback(queue_free)
