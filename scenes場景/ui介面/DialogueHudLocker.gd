# res://scenes場景/ui介面/DialogueHudLocker.gd
extends Node

const _HUD_NODE_NAMES: Array[String] = [
	"RightActionHud",
	"SealToggleButton",
	"HarvestToggleButton",
]

var _dialogue_blocked: bool = false


func _ready() -> void:
	if SignalBus:
		SignalBus.dialogue_blocking_changed.connect(_on_dialogue_blocking_changed)
		SignalBus.player_in_homestead_changed.connect(_on_homestead_changed)


func _on_homestead_changed(_in_homestead: bool) -> void:
	_apply_hud_visibility()


func _on_dialogue_blocking_changed(blocked: bool) -> void:
	_dialogue_blocked = blocked
	_apply_hud_visibility()


func _apply_hud_visibility() -> void:
	var layer := get_parent() as CanvasLayer
	if layer == null:
		return
	_set_virtual_joystick_dialogue_blocked(layer, _dialogue_blocked)
	for node_name in _HUD_NODE_NAMES:
		var n := layer.get_node_or_null(node_name) as CanvasItem
		if n == null:
			continue
		var show := not _dialogue_blocked
		if show and node_name == "SealToggleButton" and HomeManager != null and HomeManager.in_homestead:
			show = false
		if show and node_name == "HarvestToggleButton" and HomeManager != null and not HomeManager.in_homestead:
			show = false
		if node_name == "SealToggleButton" and n.has_method("set_hud_visible"):
			var instant := _dialogue_blocked and not show
			n.call("set_hud_visible", show, instant)
		else:
			n.visible = show


## 與封印流程一致：僅 hide 仍會跑 _input 並 set_input_as_handled，會吃掉 SealManager 畫圈／放開。
func _set_virtual_joystick_dialogue_blocked(layer: CanvasLayer, blocked: bool) -> void:
	var joy := layer.get_node_or_null("Virtual Joystick")
	if joy is VirtualJoystick:
		var vj := joy as VirtualJoystick
		if blocked:
			vj._reset()
			vj.set_process_input(false)
			vj.hide()
		else:
			vj.restore_after_blocking_overlay()
	else:
		if joy is CanvasItem:
			joy.visible = not blocked
