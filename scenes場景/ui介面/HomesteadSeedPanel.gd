# res://scenes場景/ui介面/HomesteadSeedPanel.gd
extends CanvasLayer

const _BROWN := Color(0.29, 0.22, 0.16)
const _PIXEL_FONT: FontFile = preload("res://assets圖片_字體_音效/PixelFont.ttf")

var _instance_id: String = ""
var _on_closed: Callable = Callable()


func _ready() -> void:
	layer = 48
	hide()


func present(instance_id: String, on_closed: Callable) -> void:
	for c in get_children():
		c.queue_free()
	_instance_id = instance_id.strip_edges()
	_on_closed = on_closed
	_build_ui()
	show()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0, 0, 0, 0.55)
	dim.gui_input.connect(_on_dim_gui_input)
	root.add_child(dim)
	var center := PanelContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -152.0
	center.offset_top = -190.0
	center.offset_right = 152.0
	center.offset_bottom = 190.0
	root.add_child(center)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	center.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var title := Label.new()
	title.add_theme_font_override("font", _PIXEL_FONT)
	title.add_theme_color_override("font_color", _BROWN)
	title.add_theme_font_size_override("font_size", 13)
	title.text = "給予種子"
	vbox.add_child(title)
	var q_head := Label.new()
	q_head.add_theme_font_override("font", _PIXEL_FONT)
	q_head.add_theme_color_override("font_color", _BROWN)
	q_head.add_theme_font_size_override("font_size", 11)
	q_head.text = "寵物播種佇列"
	vbox.add_child(q_head)
	if PetManager:
		var q := PetManager.get_seed_queue_item_ids(_instance_id)
		if q.is_empty():
			var empty_l := Label.new()
			empty_l.add_theme_font_override("font", _PIXEL_FONT)
			empty_l.add_theme_font_size_override("font_size", 10)
			empty_l.add_theme_color_override("font_color", _BROWN)
			empty_l.text = "（尚無）"
			vbox.add_child(empty_l)
		else:
			for seed_id in q:
				var lab := Label.new()
				lab.add_theme_font_override("font", _PIXEL_FONT)
				lab.add_theme_font_size_override("font_size", 10)
				lab.add_theme_color_override("font_color", _BROWN)
				var dn := str(seed_id)
				if DataManager:
					var ir: ItemResource = DataManager.get_item(str(seed_id)) as ItemResource
					if ir:
						dn = ir.display_name
				lab.text = "・%s" % dn
				vbox.add_child(lab)
	var p_head := Label.new()
	p_head.add_theme_font_override("font", _PIXEL_FONT)
	p_head.add_theme_color_override("font_color", _BROWN)
	p_head.add_theme_font_size_override("font_size", 11)
	p_head.text = "背包種子（點選移入佇列）"
	vbox.add_child(p_head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	if InventoryManager:
		for e in InventoryManager.get_seed_stack_entries():
			var r: Resource = e.get("resource")
			var cnt: int = int(e.get("count", 1))
			if not (r is ItemResource) or cnt <= 0:
				continue
			var ir := r as ItemResource
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = "%s×%d" % [ir.display_name, cnt]
			b.add_theme_font_override("font", _PIXEL_FONT)
			b.add_theme_font_size_override("font_size", 9)
			b.pressed.connect(_on_seed_pick.bind(ir.item_id))
			grid.add_child(b)
	var close_btn := Button.new()
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.text = "關閉"
	close_btn.add_theme_font_override("font", _PIXEL_FONT)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(_close_panel)
	vbox.add_child(close_btn)


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_panel()


func _on_seed_pick(item_id: String) -> void:
	if PetManager:
		PetManager.append_seed_to_station_queue(_instance_id, item_id)
	present(_instance_id, _on_closed)


func _close_panel() -> void:
	for c in get_children():
		c.queue_free()
	hide()
	if _on_closed.is_valid():
		_on_closed.call()
