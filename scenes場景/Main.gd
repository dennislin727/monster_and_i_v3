# res://scenes場景/Main.gd
extends Node2D


func _ready() -> void:
	if SaveGameManager:
		await SaveGameManager.apply_pending_save_if_any()
	_register_joystick_touch_exclusions.call_deferred()


func _register_joystick_touch_exclusions() -> void:
	## 與搖桿大範圍觸控區重疊的按鈕：避免被搶占為搖桿，才能邊移動邊按翻滾／開面板等。
	var paths: Array[String] = [
		"UILayer/DashButton",
		"UILayer/SealToggleButton",
		"UILayer/HarvestToggleButton",
		"UILayer/PetUI/OpenButton",
		"UILayer/InventoryUI/OpenButton",
		"UILayer/DiaryUI/OpenButton",
	]
	for p in paths:
		var n := get_node_or_null(NodePath(p))
		if n and n is Control:
			(n as Control).add_to_group("joystick_touch_exclusion")
