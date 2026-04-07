extends Button
## 視覺以場景（例如 Main.tscn）的 Theme Overrides 為準；此腳本只負責發送 dash 請求。

func _on_pressed() -> void:
	SignalBus.dash_requested.emit()
