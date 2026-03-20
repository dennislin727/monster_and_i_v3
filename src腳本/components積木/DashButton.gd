extends Button

func _on_pressed() -> void:
	# 簡單粗暴：直接發電報說「我要瞬移！」
	SignalBus.dash_requested.emit()
