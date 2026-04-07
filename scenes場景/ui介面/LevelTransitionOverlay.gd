# res://scenes場景/ui介面/LevelTransitionOverlay.gd
extends Control
## 換關時全螢幕漸黑／漸透（電影式轉場）；掛 `level_transition_overlay` 群組供 HomeManager 呼叫。

var _tween: Tween


func _ready() -> void:
	add_to_group("level_transition_overlay")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null


## `to_black=true` 漸暗；`false` 漸亮並隱藏。
func run_fade(to_black: bool, duration_sec: float) -> void:
	_kill_tween()
	var d := maxf(0.05, duration_sec)
	if to_black:
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, d)
		await _tween.finished
	else:
		modulate.a = 1.0
		visible = true
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, d)
		await _tween.finished
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_kill_tween()
