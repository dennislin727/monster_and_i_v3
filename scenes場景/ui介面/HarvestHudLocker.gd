# res://scenes場景/ui介面/HarvestHudLocker.gd
extends Node
## 採收模式：隱藏封印／翻滾／血條／搖桿（對齊 DialogueHudLocker 的搖桿 set_process_input 作法）。

const _HUD_NODE_NAMES: Array[String] = [
	"RightActionHud",
	"SealToggleButton",
	"PlayerHealthBar",
	"PlayerXpRow",
	"PetPartySlotHud",
	"SaveGameButton",
]

var _dialogue_blocked: bool = false
var _seal_ui_open: bool = false


func _ready() -> void:
	if SignalBus:
		SignalBus.harvest_mode_changed.connect(_on_harvest_mode_changed)
		SignalBus.dialogue_blocking_changed.connect(_on_dialogue_blocking_changed)
		SignalBus.seal_ui_requested.connect(_on_seal_ui_requested)
		SignalBus.player_in_homestead_changed.connect(_on_homestead_changed)


func _on_homestead_changed(_in_homestead: bool) -> void:
	if HomeManager != null and HomeManager.harvest_active:
		return
	_restore_if_allowed()


func _on_seal_ui_requested(is_open: bool) -> void:
	_seal_ui_open = is_open
	if not is_open:
		_restore_if_allowed()


func _on_dialogue_blocking_changed(blocked: bool) -> void:
	_dialogue_blocked = blocked
	if not blocked:
		_restore_if_allowed()


func _on_harvest_mode_changed(active: bool) -> void:
	var layer := get_parent() as CanvasLayer
	if layer == null:
		return
	if active:
		_set_virtual_joystick_harvest(layer, true)
		for node_name in _HUD_NODE_NAMES:
			var n := layer.get_node_or_null(node_name) as CanvasItem
			if n == null:
				continue
			if node_name == "SealToggleButton" and n.has_method("set_hud_visible"):
				n.call("set_hud_visible", false, true)
			else:
				n.visible = false
	else:
		_set_virtual_joystick_harvest(layer, false)
		_restore_if_allowed()


func _restore_if_allowed() -> void:
	if HomeManager and HomeManager.harvest_active:
		return
	if _dialogue_blocked:
		return
	if _seal_ui_open:
		return
	var layer := get_parent() as CanvasLayer
	if layer == null:
		return
	_set_virtual_joystick_harvest(layer, false)
	for node_name in _HUD_NODE_NAMES:
		var n := layer.get_node_or_null(node_name) as CanvasItem
		if n == null:
			continue
		var show := true
		if node_name == "SealToggleButton" and HomeManager != null and HomeManager.in_homestead:
			show = false
		if node_name == "SealToggleButton" and n.has_method("set_hud_visible"):
			n.call("set_hud_visible", show, false)
		else:
			n.visible = show


func _set_virtual_joystick_harvest(layer: CanvasLayer, harvest_hide: bool) -> void:
	var joy := layer.get_node_or_null("Virtual Joystick")
	if joy is VirtualJoystick:
		var vj := joy as VirtualJoystick
		if harvest_hide:
			vj._reset()
			vj.set_process_input(false)
			vj.hide()
		else:
			if _dialogue_blocked:
				return
			vj.restore_after_blocking_overlay()
	else:
		if joy is CanvasItem:
			joy.visible = not harvest_hide
