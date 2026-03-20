# res://src腳本/ui/SealToggleButton.gd
extends Button # 或 Button

func _ready() -> void:
	# 確保開啟切換模式
	toggle_mode = true
	SignalBus.seal_button_reset_requested.connect(_on_reset_requested)

# 🔴 參數名稱改為 toggled_on 避免與內建函數 is_pressed 重名
func _on_toggled(toggled_on: bool) -> void:
	print("[UI按鈕] 點擊觸發！目前的開關狀態是: ", toggled_on)
	SignalBus.seal_mode_toggled.emit(toggled_on)
	modulate = Color.CYAN if toggled_on else Color.WHITE

func _on_reset_requested() -> void:
	# 🔴 注意：這裡要修改內建屬性 button_pressed 而不是自定義變數
	button_pressed = false 
	modulate = Color.WHITE
