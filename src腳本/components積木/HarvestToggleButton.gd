# res://src腳本/components積木/HarvestToggleButton.gd
extends Button
## 僅在家園顯示；進區漸顯、離區漸隱；採收模式請求經 SignalBus，狀態以 harvest_mode_changed 同步。

var _fade_tween: Tween


func _ready() -> void:
	toggle_mode = true
	visible = false
	modulate = Color(1, 1, 1, 1)
	if SignalBus:
		SignalBus.player_in_homestead_changed.connect(_on_homestead)
		SignalBus.harvest_mode_changed.connect(_on_harvest_sync)


func _kill_fade() -> void:
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null


func _on_homestead(in_homestead: bool) -> void:
	_kill_fade()
	if in_homestead:
		modulate.a = 0.0
		visible = true
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 1.0, GlobalBalance.HUD_FADE_IN_SEC)
	else:
		set_pressed_no_signal(false)
		if not visible:
			modulate = Color(1, 1, 1, 1)
			return
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 0.0, GlobalBalance.HUD_FADE_OUT_SEC)
		_fade_tween.tween_callback(func() -> void:
			visible = false
			modulate = Color(1, 1, 1, 1)
		)


func _on_harvest_sync(active: bool) -> void:
	set_pressed_no_signal(active)


func _on_toggled(toggled_on: bool) -> void:
	if SignalBus:
		SignalBus.harvest_mode_toggled.emit(toggled_on)
	modulate = Color(1, 1, 1, 0.9) if toggled_on else Color(1, 1, 1, 1)
