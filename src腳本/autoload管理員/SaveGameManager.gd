# res://src腳本/autoload管理員/SaveGameManager.gd
extends Node

const SAVE_PATH := "user://monster_and_i_save_v1.json"
const SAVE_VERSION := 1
const MIN_SAVE_OVERLAY_SEC := 0.55

var _pending_json: Variant = null
var _applied_load: bool = false
var _save_busy: bool = false


func _ready() -> void:
	_read_file_into_pending()
	if SignalBus:
		SignalBus.game_save_requested.connect(_on_game_save_requested)


func has_pending_save() -> bool:
	return _pending_json is Dictionary and int((_pending_json as Dictionary).get("version", 0)) == SAVE_VERSION


func _read_file_into_pending() -> void:
	_pending_json = null
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	var j := JSON.new()
	if j.parse(txt) != OK:
		return
	var data: Variant = j.data
	if data is Dictionary:
		_pending_json = data


## 由 Main._ready await：整棵 Main 子樹 _ready 完成後套用讀檔
func apply_pending_save_if_any() -> void:
	if _applied_load:
		return
	if not has_pending_save():
		return
	_applied_load = true
	await _apply_all(_pending_json as Dictionary)
	_pending_json = null


func _on_game_save_requested() -> void:
	if _save_busy:
		return
	_save_busy = true
	await _perform_save_with_timing()
	_save_busy = false


func _perform_save_with_timing() -> void:
	var t0 := Time.get_ticks_msec()
	var ok := write_save_to_disk()
	var elapsed := Time.get_ticks_msec() - t0
	var min_ms := int(MIN_SAVE_OVERLAY_SEC * 1000.0)
	var wait_ms := maxi(0, min_ms - int(elapsed))
	if wait_ms > 0:
		await get_tree().create_timer(float(wait_ms) / 1000.0).timeout
	if SignalBus:
		SignalBus.game_save_finished.emit(ok)


func write_save_to_disk() -> bool:
	var data := _build_save_dictionary()
	var json_string := JSON.stringify(data, "\t")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveGameManager] 無法寫入存檔")
		return false
	f.store_string(json_string)
	return true


func _build_save_dictionary() -> Dictionary:
	var level_path := _get_current_level_path()
	var pos := Vector2.ZERO
	var hp := -1
	var max_hp := -1
	var tree := get_tree()
	if tree:
		var pl := tree.get_first_node_in_group("player")
		if pl is Node2D:
			pos = (pl as Node2D).global_position
		if pl:
			var hc: HealthComponent = pl.get_node_or_null("HealthComponent") as HealthComponent
			if hc:
				hp = hc.current_hp
				max_hp = hc.max_hp
	return {
		"version": SAVE_VERSION,
		"level_path": level_path,
		"player_global": [pos.x, pos.y],
		"player_hp": hp,
		"player_max_hp": max_hp,
		"inventory": InventoryManager.get_save_snapshot(),
		"pets": PetManager.get_save_snapshot(),
		"home": HomeManager.get_save_snapshot(),
		"progression": ProgressionManager.get_save_snapshot(),
		"npc": NpcStateManager.get_save_snapshot(),
		"diary": DiaryManager.get_save_snapshot(),
	}


func _get_current_level_path() -> String:
	var tree := get_tree()
	if tree == null:
		return ""
	var lc := tree.get_first_node_in_group("level_container")
	if lc == null:
		return ""
	for c in lc.get_children():
		if c != null and c.is_in_group("loaded_level"):
			var pth := str(c.scene_file_path)
			if not pth.is_empty():
				return pth
	return ""


func _apply_all(data: Dictionary) -> void:
	NpcStateManager.apply_save_snapshot(data.get("npc", {}) as Dictionary)
	InventoryManager.apply_save_snapshot(data.get("inventory", {}) as Dictionary)
	PetManager.apply_save_snapshot(data.get("pets", {}) as Dictionary)
	HomeManager.apply_save_snapshot(data.get("home", {}) as Dictionary)
	ProgressionManager.apply_save_snapshot(data.get("progression", {}) as Dictionary)
	DiaryManager.apply_save_snapshot(data.get("diary", {}) as Dictionary)
	var want_level := str(data.get("level_path", ""))
	var pos_arr: Array = data.get("player_global", [0.0, 0.0]) as Array
	var px: float = float(pos_arr[0]) if pos_arr.size() > 0 else 0.0
	var py: float = float(pos_arr[1]) if pos_arr.size() > 1 else 0.0
	var ppos := Vector2(px, py)
	if not want_level.is_empty():
		var cur := _get_current_level_path()
		if cur != want_level:
			if want_level.contains("HomesteadLevel"):
				await HomeManager.switch_to_homestead_async()
			else:
				await HomeManager.switch_to_lake_async()
	var tree := get_tree()
	if tree == null:
		return
	var pl := tree.get_first_node_in_group("player")
	if pl is Node2D:
		(pl as Node2D).global_position = ppos
	var hp := int(data.get("player_hp", -1))
	var mhp := int(data.get("player_max_hp", -1))
	if pl:
		var hc: HealthComponent = pl.get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			if mhp > 0:
				hc.max_hp = mhp
			if hp >= 0:
				hc.current_hp = hp
	if SignalBus:
		SignalBus.pet_deployed_changed.emit(PetManager.is_deployed)
		SignalBus.pet_active_changed.emit(PetManager.active_pet)
		SignalBus.pet_roster_changed.emit()
	InventoryManager.inventory_changed.emit()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	InventoryManager.apply_saved_equipment_to_world()
