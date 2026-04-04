extends Control

const _BROWN_TEXT := Color(0.29, 0.22, 0.16)

const GRID_COLUMNS := 3
const GRID_H_SEP := 10
const GRID_V_SEP := 6
const CELL_WIDTH_TRIM := 4
const SCROLLBAR_MIN_THICKNESS := 20
## 直向捲軸固定可見時，內容寬度一律預留捲軸厚度（與 ScrollContainer vertical_scroll_mode=SHOW_ALWAYS 搭配）
const SCROLLBAR_ALWAYS_VISIBLE := true
const ICON_MAX := 56
const ICON_MIN := 24
const QTY_FONT_SIZE := 10

@onready var open_button: Button = $OpenButton
@onready var panel: Control = $Panel
@onready var subtitle_label: Label = $Panel/Root/Subtitle
@onready var tab_items: Button = $Panel/Root/TabsChrome/TabsMargin/Tabs/TabItems
@onready var tab_headwear: Button = $Panel/Root/TabsChrome/TabsMargin/Tabs/TabHeadwear
@onready var item_scroll: ScrollContainer = $Panel/Root/ItemGridScroll
@onready var item_grid: GridContainer = $Panel/Root/ItemGridScroll/ItemGrid
@onready var bottom_label: RichTextLabel = $Panel/Root/BottomInfo/Margin/BottomLabel

var _show_headwear_tab: bool = true
var _tab_group: ButtonGroup
var _slot_group: ButtonGroup
var _equip_target_menu: PopupMenu
var _pending_headwear: HeadwearResource = null
var _equip_menu_committed: bool = false
const PLAYER_BINDING_KEY := "player:main"

var _slot_idle: StyleBoxFlat
var _slot_sel: StyleBoxFlat
var _slot_disabled: StyleBoxFlat
var _slot_focus_empty: StyleBoxEmpty

var _cell_w: int = 1
var _cell_h: int = 1
var _open_button_bounce: Tween


func _ready() -> void:
	if GlobalBalance:
		panel.offset_bottom = -GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_inventory_slot_styles()
	_tab_group = ButtonGroup.new()
	tab_items.button_group = _tab_group
	tab_headwear.button_group = _tab_group
	tab_items.toggled.connect(_on_items_toggled)
	tab_headwear.toggled.connect(_on_headwear_toggled)
	item_scroll.resized.connect(_on_item_scroll_resized)
	item_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_grid.add_theme_constant_override("h_separation", GRID_H_SEP)
	item_grid.add_theme_constant_override("v_separation", GRID_V_SEP)
	item_grid.columns = GRID_COLUMNS
	tab_headwear.button_pressed = true
	_show_headwear_tab = true
	open_button.toggle_mode = true
	open_button.toggled.connect(_on_open_button_toggled)
	open_button.resized.connect(_update_open_button_pivot)
	if SignalBus:
		SignalBus.inventory_ui_close_requested.connect(_hide_panel)
		SignalBus.item_collected.connect(_on_item_collected_bounce)
	_hide_panel()
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed_deferred)
	_refresh_list()
	_setup_equip_target_menu()
	_apply_scrollbar_touch_width()
	call_deferred("_update_open_button_pivot")


func _update_open_button_pivot() -> void:
	if open_button == null or open_button.size.x <= 0.0:
		return
	open_button.pivot_offset = open_button.size / 2.0


func _on_item_collected_bounce(_item: Resource) -> void:
	if open_button == null:
		return
	if _open_button_bounce != null and is_instance_valid(_open_button_bounce):
		_open_button_bounce.kill()
	_update_open_button_pivot()
	open_button.scale = Vector2.ONE
	_open_button_bounce = create_tween()
	_open_button_bounce.tween_property(open_button, "scale", Vector2(1.12, 1.12), 0.07)
	_open_button_bounce.tween_property(open_button, "scale", Vector2.ONE, 0.12)


func _build_inventory_slot_styles() -> void:
	const BG := Color(0.741176, 0.717647, 0.65098, 1)
	const BORDER_IDLE := Color(0.85098, 0.85098, 0.85098, 1)
	const BORDER_SEL := Color(0.29, 0.22, 0.16, 1)
	_slot_idle = StyleBoxFlat.new()
	_slot_idle.bg_color = BG
	_slot_idle.set_border_width_all(2)
	_slot_idle.border_color = BORDER_IDLE
	_slot_idle.set_corner_radius_all(6)
	_slot_idle.set_content_margin_all(4)
	_slot_sel = _slot_idle.duplicate() as StyleBoxFlat
	_slot_sel.border_color = BORDER_SEL
	_slot_disabled = StyleBoxFlat.new()
	_slot_disabled.bg_color = Color(BG.r, BG.g, BG.b, 0.55)
	_slot_disabled.set_border_width_all(2)
	_slot_disabled.border_color = BORDER_IDLE
	_slot_disabled.set_corner_radius_all(6)
	_slot_focus_empty = StyleBoxEmpty.new()


func _apply_scrollbar_touch_width() -> void:
	var vs: ScrollBar = item_scroll.get_v_scroll_bar()
	if vs:
		vs.custom_minimum_size.x = SCROLLBAR_MIN_THICKNESS
	var hs: ScrollBar = item_scroll.get_h_scroll_bar()
	if hs:
		hs.custom_minimum_size.y = SCROLLBAR_MIN_THICKNESS


func _on_inventory_changed_deferred() -> void:
	_refresh_list.call_deferred()


func _on_item_scroll_resized() -> void:
	_apply_slot_sizes()


func _brown_bbcode(inner: String) -> String:
	return "[color=#%s]%s[/color]" % [_BROWN_TEXT.to_html(false), inner]


func _bottom_detail_with_qty_bbcode(title: String, qty: int, body: String) -> String:
	var hex := _BROWN_TEXT.to_html(false)
	var q := "×%d" % qty
	var line1 := "[color=#%s]%s[/color] [font_size=%d][color=#%s]%s[/color][/font_size]" % [
		hex, title, QTY_FONT_SIZE, hex, q
	]
	var b := body.strip_edges()
	if b.is_empty():
		return line1
	return "%s\n\n%s" % [line1, _brown_bbcode(b)]


func _item_resource_id(metadata: Variant) -> String:
	if metadata is Dictionary:
		return str(metadata.get("id", ""))
	return str(metadata)


func _scroll_inner_content_width() -> int:
	var w: int = int(item_scroll.size.x)
	if w <= 0:
		return 0
	var vs: ScrollBar = item_scroll.get_v_scroll_bar()
	var bar_w := 0
	if vs and is_instance_valid(vs):
		bar_w = int(vs.get_combined_minimum_size().x)
		if not SCROLLBAR_ALWAYS_VISIBLE and not vs.visible:
			bar_w = 0
	elif SCROLLBAR_ALWAYS_VISIBLE:
		bar_w = SCROLLBAR_MIN_THICKNESS
	w -= bar_w
	return maxi(w, 0)


func _compute_cell_metrics() -> void:
	var inner: int = _scroll_inner_content_width()
	if inner < 24:
		_cell_w = 1
		_cell_h = 1
		return
	var cols: int = GRID_COLUMNS
	var total_sep: int = GRID_H_SEP * maxi(cols - 1, 0)
	_cell_w = maxi(int((inner - total_sep) / float(cols)) - CELL_WIDTH_TRIM, 1)
	var pad := 8
	var icon_side: int = clampi(_cell_w - pad, ICON_MIN, ICON_MAX)
	_cell_h = icon_side + pad


func _full_grid_min_width() -> int:
	var cols: int = GRID_COLUMNS
	return cols * _cell_w + GRID_H_SEP * maxi(cols - 1, 0)


func _apply_slot_sizes() -> void:
	_compute_cell_metrics()
	_apply_scrollbar_touch_width()
	var grid_w: int = _full_grid_min_width()
	if grid_w > 0:
		item_grid.custom_minimum_size.x = grid_w
	for c in item_grid.get_children():
		if not (c is Button):
			continue
		var b: Button = c as Button
		if b.disabled:
			b.custom_minimum_size = Vector2(maxf(float(grid_w), 1.0), 36.0)
		else:
			b.custom_minimum_size = Vector2(_cell_w, _cell_h)


func _clear_item_grid() -> void:
	for c in item_grid.get_children():
		item_grid.remove_child(c)
		c.queue_free()


func _style_slot_button(b: Button) -> void:
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_stylebox_override("normal", _slot_idle)
	b.add_theme_stylebox_override("hover", _slot_idle)
	b.add_theme_stylebox_override("hover_pressed", _slot_sel)
	b.add_theme_stylebox_override("pressed", _slot_sel)
	b.add_theme_stylebox_override("focus", _slot_focus_empty)
	b.add_theme_color_override("font_color", _BROWN_TEXT)
	b.add_theme_color_override("font_pressed_color", _BROWN_TEXT)
	b.add_theme_color_override("font_hover_color", _BROWN_TEXT)
	b.add_theme_color_override("font_focus_color", _BROWN_TEXT)
	var fnt: Font = bottom_label.get_theme_font("normal_font")
	if fnt:
		b.add_theme_font_override("font", fnt)
		b.add_theme_font_size_override("font_size", 12)


func _add_placeholder_button(msg: String) -> void:
	var b := Button.new()
	b.text = msg
	b.disabled = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_stylebox_override("disabled", _slot_disabled)
	b.add_theme_color_override("font_disabled_color", _BROWN_TEXT)
	var fnt: Font = bottom_label.get_theme_font("normal_font")
	if fnt:
		b.add_theme_font_override("font", fnt)
		b.add_theme_font_size_override("font_size", 12)
	item_grid.add_child(b)


func _add_item_slot(meta: Dictionary, icon_tex: Texture2D, tip: String) -> void:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _slot_group
	b.text = ""
	b.icon = icon_tex
	b.expand_icon = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.set_meta("slot_meta", meta)
	_style_slot_button(b)
	if _show_headwear_tab and meta.get("is_equipped", false):
		_add_equipped_badge_on_slot(b)
	b.toggled.connect(func(p: bool): _on_slot_toggled(p, b))
	item_grid.add_child(b)


func _add_equipped_badge_on_slot(b: Button) -> void:
	var badge := Label.new()
	badge.text = "裝備中"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bottom_label:
		var fnt: Font = bottom_label.get_theme_font("normal_font")
		if fnt:
			badge.add_theme_font_override("font", fnt)
	badge.add_theme_font_size_override("font_size", QTY_FONT_SIZE)
	badge.add_theme_color_override("font_color", _BROWN_TEXT)
	badge.anchor_left = 0.0
	badge.anchor_top = 1.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = 2.0
	badge.offset_right = -3.0
	badge.offset_top = -15.0
	badge.offset_bottom = -2.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	b.add_child(badge)


func _on_slot_toggled(pressed: bool, b: Button) -> void:
	if pressed:
		var meta: Variant = b.get_meta("slot_meta", {})
		_update_bottom_from_slot_meta(meta)
		_try_headwear_interaction(meta)
	else:
		if _slot_group.get_pressed_button() == null:
			_set_bottom_help_text(_default_bottom_text())


func _update_bottom_from_slot_meta(meta: Variant) -> void:
	if bottom_label == null:
		return
	if meta is Dictionary:
		var d: Dictionary = meta
		var title := str(d.get("bottom_title", ""))
		var body := str(d.get("bottom_body", ""))
		var qty: int = int(d.get("count", 1))
		if title.strip_edges() != "":
			bottom_label.text = _bottom_detail_with_qty_bbcode(title, qty, body)
			return
	bottom_label.text = _default_bottom_text()


func _try_headwear_interaction(meta: Variant) -> void:
	if not _show_headwear_tab:
		return
	if not (meta is Dictionary):
		return
	var resource_id := _item_resource_id(meta)
	if InventoryManager == null:
		return
	var res := InventoryManager.get_resource_by_id(resource_id)
	var headwear := res as HeadwearResource
	if headwear == null:
		return
	var current_owner := InventoryManager.get_headwear_owner_key(headwear.headwear_id)
	if not current_owner.is_empty():
		InventoryManager.unequip_headwear_by_id(headwear.headwear_id)
		_pending_headwear = null
		# 勿在此同步 _refresh_list：仍在該格 Button 的 toggled 回呼內，queue_free 會釋放發送者。
		_deselect_all_slots()
		return
	_pending_headwear = headwear
	_show_equip_target_menu()


func _deselect_all_slots() -> void:
	if _slot_group == null:
		return
	for c in item_grid.get_children():
		if c is Button and c.button_group == _slot_group:
			(c as Button).button_pressed = false
	_set_bottom_help_text(_default_bottom_text())


func _on_open_button_toggled(pressed_state: bool) -> void:
	if pressed_state:
		_show_panel()
	else:
		_hide_panel()


func _show_panel() -> void:
	if SignalBus:
		if HomeManager != null and HomeManager.harvest_active:
			SignalBus.harvest_mode_toggled.emit(false)
		SignalBus.pet_ui_close_requested.emit()
		SignalBus.diary_ui_close_requested.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	open_button.set_pressed_no_signal(true)
	_refresh_list()


func _hide_panel() -> void:
	open_button.set_pressed_no_signal(false)
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


func _refresh_subtitle_gold() -> void:
	if subtitle_label == null or InventoryManager == null:
		return
	subtitle_label.text = "分類與堆疊（簡易版）　金幣：%d" % InventoryManager.get_gold()


func _refresh_list() -> void:
	_refresh_subtitle_gold()
	_clear_item_grid()
	_slot_group = null
	_set_bottom_help_text(_default_bottom_text())
	if InventoryManager == null:
		_add_placeholder_button("（背包未就緒）")
		_queue_apply_slot_sizes()
		return
	var entries: Array[Dictionary] = (
		InventoryManager.get_headwear_tab_entries() if _show_headwear_tab
		else InventoryManager.get_item_tab_entries()
	)
	if entries.is_empty():
		_add_placeholder_button(
			"背包裡還沒有道具" if not _show_headwear_tab else "尚無頭飾可裝備"
		)
		_queue_apply_slot_sizes()
		return
	_slot_group = ButtonGroup.new()
	for e in entries:
		var r: Resource = e.get("resource") as Resource
		var count: int = int(e.get("count", 1))
		if r == null:
			continue
		var display_name := ""
		var tip := ""
		var id := ""
		var icon_tex: Texture2D = null
		var bottom_body := ""
		var is_equipped_headwear := false
		if r is ItemResource:
			var ir := r as ItemResource
			display_name = ir.display_name
			bottom_body = ir.description.strip_edges()
			tip = ir.description if ir.description.strip_edges() != "" else ir.display_name
			id = ir.item_id
			icon_tex = ir.icon
		elif r is HeadwearResource:
			var hr := r as HeadwearResource
			display_name = hr.display_name
			bottom_body = hr.description.strip_edges()
			tip = hr.description if hr.description.strip_edges() != "" else hr.display_name
			id = hr.headwear_id
			icon_tex = hr.icon
			var owner_key := InventoryManager.get_headwear_owner_key(id)
			is_equipped_headwear = not owner_key.is_empty()
			var owner_label := _owner_label(owner_key)
			if not owner_label.is_empty():
				display_name += " [%s]" % owner_label
				tip += "\n目前裝備：%s" % owner_label
				if not bottom_body.is_empty():
					bottom_body += "\n目前裝備：%s" % owner_label
				else:
					bottom_body = "目前裝備：%s" % owner_label
		else:
			continue
		var meta := {
			"id": id,
			"bottom_title": display_name,
			"bottom_body": bottom_body,
			"count": count,
			"is_equipped": is_equipped_headwear,
		}
		_add_item_slot(meta, icon_tex, tip)
	_queue_apply_slot_sizes()


func _queue_apply_slot_sizes() -> void:
	_apply_slot_sizes.call_deferred()


func _default_bottom_text() -> String:
	if _show_headwear_tab:
		return _brown_bbcode("點選頭飾以裝備或脫下；選取後此處顯示說明。")
	return _brown_bbcode("點選道具以查看說明。")


func _set_bottom_help_text(bb: String) -> void:
	if bottom_label:
		bottom_label.text = bb


func _setup_equip_target_menu() -> void:
	_equip_target_menu = PopupMenu.new()
	_equip_target_menu.name = "EquipTargetMenu"
	add_child(_equip_target_menu)
	# PopupMenu 以程式建立時不繼承 Panel 字體；須與背包／RichTextLabel 一致，否則手機預設字體缺中文。
	if bottom_label:
		var fnt: Font = bottom_label.get_theme_font("normal_font")
		if fnt:
			_equip_target_menu.add_theme_font_override("font", fnt)
			_equip_target_menu.add_theme_font_size_override("font_size", 12)
	_equip_target_menu.id_pressed.connect(_on_equip_target_selected)
	_equip_target_menu.popup_hide.connect(_on_equip_target_menu_hidden)


func _show_equip_target_menu() -> void:
	if _equip_target_menu == null:
		return
	_equip_menu_committed = false
	_equip_target_menu.clear()
	_equip_target_menu.add_item("裝備給主角", 0)
	if PetManager != null:
		for e in PetManager.get_deployed_party_entries():
			var slot_i: int = int(e.get("slot", -1))
			var pr: PetResource = e.get("pet") as PetResource
			if slot_i < 0 or pr == null:
				continue
			var nm := pr.nickname.strip_edges() if pr.nickname.strip_edges() != "" else (
				pr.pet_name if pr.pet_name.strip_edges() != "" else pr.pet_id
			)
			_equip_target_menu.add_item("槽%d %s" % [slot_i + 1, nm], 100 + slot_i)
	_equip_target_menu.position = get_global_mouse_position()
	_equip_target_menu.popup()


func _on_equip_target_selected(id: int) -> void:
	if _pending_headwear == null:
		return
	_equip_menu_committed = true
	match id:
		0:
			_equip_to_player(_pending_headwear)
		_:
			if id >= 100:
				var slot := id - 100
				var key := PetManager.get_party_slot_binding_key(slot) if PetManager != null else ""
				if not key.is_empty():
					_equip_to_owner(_pending_headwear, key)
				else:
					_equip_to_player(_pending_headwear)
	_pending_headwear = null
	_refresh_list()
	_deselect_all_slots()


func _on_equip_target_menu_hidden() -> void:
	_equip_menu_committed = false
	_deselect_all_slots()


func _equip_to_player(headwear: HeadwearResource) -> void:
	_equip_to_owner(headwear, PLAYER_BINDING_KEY)


func _equip_to_owner(headwear: HeadwearResource, owner_key: String) -> void:
	if headwear == null or InventoryManager == null:
		return
	if owner_key.strip_edges().is_empty():
		return
	InventoryManager.equip_headwear_to_owner(headwear, owner_key)
	_deselect_all_slots()


func _owner_label(owner_key: String) -> String:
	match owner_key:
		PLAYER_BINDING_KEY:
			return "主角"
		_:
			if owner_key.begins_with("pet:") and PetManager != null:
				return PetManager.get_owner_key_slot_label(owner_key)
	return ""
