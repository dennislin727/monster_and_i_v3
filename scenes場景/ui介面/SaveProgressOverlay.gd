# res://scenes場景/ui介面/SaveProgressOverlay.gd
extends Control


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if SignalBus:
		SignalBus.game_save_requested.connect(_on_save_requested)
		SignalBus.game_save_finished.connect(_on_save_finished)


func _on_save_requested() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_save_finished(_success: bool) -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
