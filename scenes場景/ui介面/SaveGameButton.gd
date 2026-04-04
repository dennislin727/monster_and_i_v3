# res://scenes場景/ui介面/SaveGameButton.gd
extends Button


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if SignalBus:
		SignalBus.game_save_requested.emit()
