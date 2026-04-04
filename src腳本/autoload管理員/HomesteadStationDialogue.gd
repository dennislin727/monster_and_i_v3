# res://src腳本/autoload管理員/HomesteadStationDialogue.gd
extends Node

const _PREFIX := "homestead_station:"

var _active: bool = false
var _pet_instance_id: String = ""
var _phase: String = ""

func is_active() -> bool:
	return _active


func try_open(npc_id: String) -> bool:
	var clean := npc_id.strip_edges()
	if not clean.begins_with(_PREFIX):
		return false
	var iid := clean.substr(_PREFIX.length()).strip_edges()
	if iid.is_empty() or PetManager == null:
		return false
	var pet := PetManager.find_pet_by_instance_id(iid)
	if pet == null:
		return false
	_pet_instance_id = iid
	_active = true
	_phase = "main"
	if SignalBus:
		SignalBus.pet_ui_close_requested.emit()
		SignalBus.inventory_ui_close_requested.emit()
		SignalBus.diary_ui_close_requested.emit()
		SignalBus.dialogue_blocking_changed.emit(true)
		SignalBus.npc_interaction_prompt_changed.emit(false, "", "", Vector2.ZERO)
	_present_main(pet)
	return true


func _present_main(pet: PetResource) -> void:
	var nm := pet.nickname.strip_edges() if pet.nickname.strip_edges() != "" else pet.pet_name
	var prompt := "給嘟嘟種子" if pet.pet_id == "dudu" else "與%s聊天" % nm
	var body := (
		"[font_size=13]%s：[/font_size]\n[font_size=11]%s[/font_size]\n\n[font_size=13]（家園駐留中）[/font_size]"
		% [nm, prompt]
	)
	var choices := PackedStringArray(["給予種子", "收回身邊", "待會再來"])
	if SignalBus:
		SignalBus.dialogue_presented.emit(true, body, choices)


func consume_choice(choice_index: int) -> bool:
	if not _active:
		return false
	match _phase:
		"main":
			return _handle_main_choice(choice_index)
		_:
			return false


func _handle_main_choice(idx: int) -> bool:
	if idx == 0:
		_phase = "seed"
		if SignalBus:
			SignalBus.dialogue_presented.emit(false, "", PackedStringArray())
		_open_seed_panel()
		return true
	if idx == 1:
		if PetManager:
			PetManager.unstation_pet_to_roster_tail(_pet_instance_id)
		force_close()
		return true
	if idx == 2:
		force_close()
		return true
	return false


func _open_seed_panel() -> void:
	var panel_scene: PackedScene = load("res://scenes場景/ui介面/HomesteadSeedPanel.tscn") as PackedScene
	if panel_scene == null:
		_phase = "main"
		var pet := PetManager.find_pet_by_instance_id(_pet_instance_id) if PetManager else null
		if pet != null:
			_present_main(pet)
		return
	var root := get_tree().root
	var panel: Node = panel_scene.instantiate()
	root.add_child(panel)
	if panel.has_method("present"):
		panel.call("present", _pet_instance_id, Callable(self, "_on_seed_panel_closed"))


func _on_seed_panel_closed() -> void:
	if not _active:
		return
	_phase = "main"
	var pet := PetManager.find_pet_by_instance_id(_pet_instance_id) if PetManager else null
	if pet != null:
		if SignalBus:
			SignalBus.dialogue_blocking_changed.emit(true)
		_present_main(pet)
	else:
		force_close()


func force_close() -> void:
	_active = false
	_pet_instance_id = ""
	_phase = ""
	if SignalBus:
		SignalBus.dialogue_presented.emit(false, "", PackedStringArray())
		SignalBus.dialogue_blocking_changed.emit(false)
