extends Control

@onready var open_button: Button = $OpenButton
@onready var panel: Control = $Panel
@onready var tab_items: Button = $Panel/Root/Tabs/TabItems
@onready var tab_headwear: Button = $Panel/Root/Tabs/TabHeadwear
@onready var list: ItemList = $Panel/Root/ItemList

var _show_headwear_tab: bool = false
var _tab_group: ButtonGroup

func _ready() -> void:
	if GlobalBalance:
		panel.offset_bottom = -GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_group = ButtonGroup.new()
	tab_items.button_group = _tab_group
	tab_headwear.button_group = _tab_group
	tab_items.toggled.connect(_on_items_toggled)
	tab_headwear.toggled.connect(_on_headwear_toggled)
	tab_items.button_pressed = true
	open_button.pressed.connect(_toggle_panel)
	if SignalBus:
		SignalBus.inventory_ui_close_requested.connect(_hide_panel)
	_hide_panel()
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_refresh_list)
	_refresh_list()


func _toggle_panel() -> void:
	if panel.visible:
		_hide_panel()
	else:
		_show_panel()


func _show_panel() -> void:
	if SignalBus:
		SignalBus.pet_ui_close_requested.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_list()


func _hide_panel() -> void:
	panel.hide()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_items_toggled(pressed: bool) -> void:
	if pressed:
		_show_headwear_tab = false
		_refresh_list()


func _on_headwear_toggled(pressed: bool) -> void:
	if pressed:
		_show_headwear_tab = true
		_refresh_list()


func _refresh_list() -> void:
	list.clear()
	if InventoryManager == null:
		list.add_item("（背包未就緒）")
		list.set_item_disabled(0, true)
		return
	var entries: Array[Dictionary] = (
		InventoryManager.get_headwear_tab_entries() if _show_headwear_tab
		else InventoryManager.get_item_tab_entries()
	)
	if entries.is_empty():
		list.add_item("背包裡還沒有道具" if not _show_headwear_tab else "尚無頭飾可裝備")
		list.set_item_disabled(0, true)
		return
	for e in entries:
		var ir: ItemResource = e.get("resource") as ItemResource
		var count: int = int(e.get("count", 1))
		if ir == null:
			continue
		var line := "%s  ×%d" % [ir.display_name, count]
		var idx := list.add_item(line)
		list.set_item_tooltip(idx, ir.description if ir.description.strip_edges() != "" else ir.display_name)
		list.set_item_metadata(idx, ir.item_id)
