# res://src腳本/ui/SealToggleButton.gd
extends Button # 或 Button

func _ready() -> void:
	toggle_mode = true
	SignalBus.seal_button_reset_requested.connect(_on_reset_requested)

func _on_toggled(toggled_on: bool) -> void:
	# 只有玩家手動點擊時，才發送 toggled 信號
	SignalBus.seal_mode_toggled.emit(toggled_on)
	modulate = Color.CYAN if toggled_on else Color.WHITE

func _on_reset_requested() -> void:
	# 🟢 正確：使用 set_pressed_no_signal，它只會改視覺，不會觸發 _on_toggled 邏輯
	set_pressed_no_signal(false)
	modulate = Color.WHITE
