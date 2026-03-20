extends Button

var is_seal_active: bool = false

func _on_pressed() -> void:
	is_seal_active = !is_seal_active
	# 發射電報：封印模式切換了！
	SignalBus.seal_mode_toggled.emit(is_seal_active)
	
	# 視覺回饋：變藍色代表開啟
	modulate = Color(0, 1, 1) if is_seal_active else Color(1, 1, 1)
