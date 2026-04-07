# res://scenes場景/ui介面/AreaTitleBanner.gd
extends Control
## 全專案共用：地圖區域名稱中上方漸顯／漸隱（監聽 SignalBus，無業務判斷）。

@onready var _title: Label = $TitleLabel

var _seq: int = 0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	if _title:
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if SignalBus:
		SignalBus.area_title_show_requested.connect(_on_show_requested)
		SignalBus.area_title_hide_requested.connect(_on_hide_requested)


func _on_show_requested(title: String, duration_sec: float) -> void:
	var clean := title.strip_edges()
	if clean.is_empty():
		return
	_seq += 1
	var token := _seq
	_kill_tween()
	if _title:
		_title.text = clean
	visible = true
	modulate.a = 0.0
	var fade_in := GlobalBalance.AREA_TITLE_FADE_IN_SEC
	var hold := GlobalBalance.AREA_TITLE_HOLD_SEC
	var fade_out := GlobalBalance.AREA_TITLE_FADE_OUT_SEC
	if duration_sec > 0.0:
		var base := fade_in + hold + fade_out
		if base > 0.0:
			var sc := duration_sec / base
			fade_in *= sc
			hold *= sc
			fade_out *= sc
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_in)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, fade_out)
	_tween.tween_callback(func() -> void:
		if token != _seq:
			return
		visible = false
	)


func _on_hide_requested() -> void:
	_seq += 1
	_kill_tween()
	if not visible and modulate.a <= 0.01:
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, GlobalBalance.AREA_TITLE_FADE_OUT_SEC)
	_tween.tween_callback(func() -> void: visible = false)


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
