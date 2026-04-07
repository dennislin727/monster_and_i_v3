# res://scenes場景/ui介面/HarvestWorldDim.gd
extends Control
## 採收模式：類封印的全螢幕暗化；作物由 HomeManager 另調 `modulate` 提亮。

## 與 SealUI Filter 語意相近：黑幕的「濃度」在 ColorRect 的 alpha，父節 modulate.a 只做 0→1 淡入（勿用不透明純黑，否則整個世界會被蓋死）。
const _DIM_RECT_COLOR := Color(0, 0, 0, 0.52)

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	z_index = 9
	var cr := get_node_or_null("DimRect") as ColorRect
	if cr:
		cr.color = _DIM_RECT_COLOR
	if SignalBus:
		SignalBus.harvest_mode_changed.connect(_on_harvest_mode_changed)


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _on_harvest_mode_changed(active: bool) -> void:
	_kill_tween()
	var dur := GlobalBalance.HUD_FADE_IN_SEC if GlobalBalance else 0.45
	if active:
		visible = true
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, dur)
	else:
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, dur)
		_tween.tween_callback(func() -> void:
			visible = false
		)
