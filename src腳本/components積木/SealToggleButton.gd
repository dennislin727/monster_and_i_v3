# res://src腳本/components積木/SealToggleButton.gd
extends Button
## 視覺以場景（例如 Main.tscn）的 Theme Overrides 為準。
## 進出家園區時由 DialogueHudLocker／HarvestHudLocker 呼叫 set_hud_visible（漸顯／漸隱與 GlobalBalance.HUD_FADE_* 對齊）。

var _hud_fade_tween: Tween


func _ready() -> void:
	toggle_mode = true
	SignalBus.seal_button_reset_requested.connect(_on_reset_requested)


func _kill_hud_fade() -> void:
	if _hud_fade_tween != null and is_instance_valid(_hud_fade_tween):
		_hud_fade_tween.kill()
	_hud_fade_tween = null


## 由 HUD 協調腳本控制是否該出現在欄上（非封印儀式狀態）。
## instant：對話阻擋、進入採收模式等需立刻隱藏時為 true。
func set_hud_visible(want_visible: bool, instant: bool = false) -> void:
	_kill_hud_fade()
	if instant:
		visible = want_visible
		_sync_modulate_with_toggle()
		return
	var target_a := 0.9 if button_pressed else 1.0
	if want_visible:
		if visible and absf(modulate.a - target_a) < 0.02:
			return
		modulate.a = 0.0
		visible = true
		_hud_fade_tween = create_tween()
		_hud_fade_tween.tween_property(self, "modulate:a", target_a, GlobalBalance.HUD_FADE_IN_SEC)
	else:
		if not visible:
			_sync_modulate_with_toggle()
			return
		_hud_fade_tween = create_tween()
		_hud_fade_tween.tween_property(self, "modulate:a", 0.0, GlobalBalance.HUD_FADE_OUT_SEC)
		_hud_fade_tween.tween_callback(func() -> void:
			visible = false
			_sync_modulate_with_toggle()
		)


func _sync_modulate_with_toggle() -> void:
	modulate = Color(1, 1, 1, 0.9) if button_pressed else Color(1, 1, 1, 1)


func _on_pressed() -> void:
	pass


func _on_toggled(toggled_on: bool) -> void:
	SignalBus.seal_mode_toggled.emit(toggled_on)
	modulate = Color(1, 1, 1, 0.9) if toggled_on else Color(1, 1, 1, 1)


func _on_reset_requested() -> void:
	_kill_hud_fade()
	set_pressed_no_signal(false)
	modulate = Color(1, 1, 1, 1)
