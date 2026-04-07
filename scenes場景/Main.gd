# res://scenes場景/Main.gd
extends Node2D


func _ready() -> void:
	if SaveGameManager:
		var had_save := SaveGameManager.has_pending_save()
		await SaveGameManager.apply_pending_save_if_any()
		if not had_save:
			call_deferred("_spawn_player_at_default_level_marker")
	_register_joystick_touch_exclusions.call_deferred()


func _spawn_player_at_default_level_marker() -> void:
	var tree := get_tree()
	if tree == null or HomeManager == null:
		return
	var lc := tree.get_first_node_in_group("level_container")
	if lc == null:
		return
	for c in lc.get_children():
		if c != null and c.is_in_group("loaded_level"):
			HomeManager.warp_player_to_spawn_marker(c, "PlayerSpawn_Bed")
			return


func _register_joystick_touch_exclusions() -> void:
	## 與搖桿大範圍觸控區重疊的按鈕：避免被搶占為搖桿，才能邊移動邊按翻滾／開面板等。
	var paths: Array[String] = [
		"UILayer/RightActionHud/DashButton",
		"UILayer/RightActionHud/PetCommandSkillButton",
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
