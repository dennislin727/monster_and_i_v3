extends Control

const _PET_PANEL_FONT_SIZE := 14
const _PET_LIST_NAME_FONT_SIZE := 14
const _PET_LIST_META_FONT_SIZE := 11

@onready var open_button: Button = $OpenButton
@onready var panel: Control = $Panel
@onready var list_rows: VBoxContainer = $Panel/Root/Left/ListScroll/PetListRows
@onready var icon_frame: Panel = $Panel/Root/Right/HeaderRow/IconFrame
@onready var icon_button: TextureButton = $Panel/Root/Right/HeaderRow/IconFrame/IconButton
@onready var name_label: Label = $Panel/Root/Right/HeaderRow/NameBlock/Name
@onready var id_label: Label = $Panel/Root/Right/HeaderRow/NameBlock/Id
@onready var deploy_button: Button = $Panel/Root/Right/Buttons/DeployButton
@onready var mount_button: Button = $Panel/Root/Right/Buttons/MountButton
@onready var release_button: Button = $Panel/Root/Right/Buttons/ReleaseButton
@onready var details_level: Label = $Panel/Root/Right/HeaderRow/NameBlock/Level
@onready var details_story: RichTextLabel = $Panel/Root/Right/DetailsScroll/DetailsInner/Story
@onready var details_skills: VBoxContainer = $Panel/Root/Right/DetailsScroll/DetailsInner/Skills
@onready var confirm_dialog = $DialogLayer/ConfirmDialog

var _pet_items: Array[PetResource] = []
var _mount_enabled: bool = false
var _style_icon_idle: StyleBoxFlat = null
var _style_icon_selected: StyleBoxFlat = null
var _style_row_idle: StyleBoxFlat = null
var _style_row_selected: StyleBoxFlat = null
var _style_row_hover: StyleBoxFlat = null
var _pending_release: PetResource = null

func _ready() -> void:
	if GlobalBalance:
		panel.offset_bottom = -GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	open_button.pressed.connect(_toggle_panel)
	mount_button.pressed.connect(_on_mount_pressed)
	release_button.pressed.connect(_on_release_pressed)
	deploy_button.pressed.connect(_on_deploy_pressed)
	confirm_dialog.confirmed.connect(_on_release_confirmed)
	confirm_dialog.cancelled.connect(_on_release_cancelled)
	_style_icon_idle = StyleBoxFlat.new()
	_style_icon_idle.bg_color = Color(0, 0, 0, 0)
	_style_icon_idle.set_border_width_all(2)
	_style_icon_idle.border_color = Color(1, 1, 1, 0.15)
	_style_icon_idle.set_corner_radius_all(6)

	_style_icon_selected = StyleBoxFlat.new()
	_style_icon_selected.bg_color = Color(1, 1, 1, 0.06)
	_style_icon_selected.set_border_width_all(2)
	_style_icon_selected.border_color = Color(1, 1, 1, 0.65)
	_style_icon_selected.set_corner_radius_all(6)

	_style_row_idle = StyleBoxFlat.new()
	_style_row_idle.bg_color = Color(0, 0, 0, 0)
	_style_row_selected = StyleBoxFlat.new()
	_style_row_selected.bg_color = Color(1, 1, 1, 0.09)
	_style_row_selected.set_border_width_all(1)
	_style_row_selected.border_color = Color(1, 1, 1, 0.28)
	_style_row_selected.set_corner_radius_all(4)
	_style_row_hover = StyleBoxFlat.new()
	_style_row_hover.bg_color = Color(1, 1, 1, 0.05)
	_style_row_hover.set_corner_radius_all(4)

	_hide_panel()
	_apply_icon_frame_style(false)

	if SignalBus:
		SignalBus.pet_captured.connect(_on_pet_captured)
		SignalBus.pet_roster_changed.connect(_refresh)
		SignalBus.pet_active_changed.connect(_on_pet_active_changed)
		SignalBus.pet_deployed_changed.connect(_on_pet_deployed_changed)
		SignalBus.pet_ui_close_requested.connect(_hide_panel)

	_refresh()

func _toggle_panel() -> void:
	if panel.visible:
		_hide_panel()
	else:
		_show_panel()

func _show_panel() -> void:
	if SignalBus:
		SignalBus.inventory_ui_close_requested.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()

func _hide_panel() -> void:
	panel.hide()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_icon_frame_style(false)
	_pending_release = null

func _on_mount_pressed() -> void:
	_mount_enabled = not _mount_enabled
	mount_button.text = "下騎" if _mount_enabled else "坐騎"
	SignalBus.pet_mount_requested.emit(_mount_enabled)
	_sync_deploy_mount_mutex()

func _on_release_pressed() -> void:
	var p := PetManager.active_pet
	if p == null:
		return
	_pending_release = p
	var display_name := p.nickname if p.nickname.strip_edges() != "" else (p.pet_name if p.pet_name != "" else p.pet_id)
	var lvl := maxi(1, p.level)
	var body := (
		"要將 [b]%s[/b]（Lv.%d）從隨身清單移除了嗎？\n\n"
		+ "[color=#b8956f]可以放到家園陪媽媽，確定要移除嗎？[/color]"
	) % [display_name, lvl]
	confirm_dialog.present("確認移除", body, "移除", "取消")

func _on_release_confirmed() -> void:
	if _pending_release != null:
		SignalBus.pet_release_requested.emit(_pending_release)
	_pending_release = null

func _on_release_cancelled() -> void:
	_pending_release = null

func _on_pet_captured(_pet_data: PetResource) -> void:
	_refresh()

func _on_pet_active_changed(_pet_data: Variant) -> void:
	_refresh_details()
	_refresh_deploy_button()
	_refresh_selection()

func _on_pet_deployed_changed(_is_deployed: bool) -> void:
	_refresh()

func _refresh() -> void:
	_pet_items = PetManager.captured_pets.duplicate()
	for c in list_rows.get_children():
		c.queue_free()

	var row_font := open_button.get_theme_font("font")
	for p in _pet_items:
		if p == null:
			continue
		list_rows.add_child(_make_pet_list_row(p, row_font))

	_refresh_details()
	_refresh_selection()
	_refresh_deploy_button()

func _make_pet_list_row(p: PetResource, row_font: Font) -> Button:
	var display_name := p.nickname if p.nickname.strip_edges() != "" else (p.pet_name if p.pet_name != "" else p.pet_id)
	var meta := "Lv%d" % maxi(1, p.level)
	if PetManager.deployed_pet == p:
		meta += "·[戰]"

	var btn := Button.new()
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size.y = 28
	btn.set_meta("pet_resource", p)
	btn.add_theme_stylebox_override("normal", _style_row_idle)
	btn.add_theme_stylebox_override("hover", _style_row_hover)
	btn.add_theme_stylebox_override("pressed", _style_row_selected)
	btn.pressed.connect(_on_list_row_pressed.bind(p))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	btn.add_child(h)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_top = 2
	h.offset_right = -6
	h.offset_bottom = -2

	var name_l := Label.new()
	name_l.text = display_name
	if row_font:
		name_l.add_theme_font_override("font", row_font)
	name_l.add_theme_font_size_override("font_size", _PET_LIST_NAME_FONT_SIZE)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true

	var meta_l := Label.new()
	meta_l.text = meta
	if row_font:
		meta_l.add_theme_font_override("font", row_font)
	meta_l.add_theme_font_size_override("font_size", _PET_LIST_META_FONT_SIZE)
	meta_l.add_theme_color_override("font_color", Color(0.8, 0.84, 0.9, 1))

	h.add_child(name_l)
	h.add_child(meta_l)
	return btn

func _on_list_row_pressed(p: PetResource) -> void:
	if p == null:
		return
	if _mount_enabled and PetManager.active_pet != p:
		_mount_enabled = false
		mount_button.text = "坐騎"
		SignalBus.pet_mount_requested.emit(false)
	SignalBus.pet_active_requested.emit(p)

func _refresh_selection() -> void:
	var active := PetManager.active_pet
	for btn in list_rows.get_children():
		if not btn is Button:
			continue
		var pr: PetResource = btn.get_meta("pet_resource") if btn.has_meta("pet_resource") else null
		var selected := pr != null and pr == active
		var idle_box: StyleBoxFlat = _style_row_selected if selected else _style_row_idle
		btn.add_theme_stylebox_override("normal", idle_box)
		btn.add_theme_stylebox_override("focus", idle_box)

func _refresh_details() -> void:
	var p := PetManager.active_pet
	if p == null:
		icon_button.texture_normal = null
		_apply_icon_frame_style(false)
		name_label.text = "尚未擁有寵物"
		id_label.text = ""
		id_label.remove_theme_color_override("font_color")
		details_level.text = "等級：—"
		deploy_button.disabled = true
		release_button.disabled = true
		details_story.text = "[color=gray]—[/color]"
		for c in details_skills.get_children():
			c.queue_free()
		return

	icon_button.texture_normal = p.icon
	name_label.text = p.nickname if p.nickname.strip_edges() != "" else (p.pet_name if p.pet_name != "" else "未命名寵物")
	id_label.text = "編號 %s" % p.pet_id
	id_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74, 1))
	_apply_icon_frame_style(true)
	_refresh_details_panel(p)

func _apply_icon_frame_style(selected: bool) -> void:
	if not icon_frame:
		return
	icon_frame.add_theme_stylebox_override("panel", _style_icon_selected if selected else _style_icon_idle)

func _refresh_details_panel(p: PetResource) -> void:
	if p == null:
		return
	details_level.text = "等級：%d" % maxi(1, p.level)
	details_story.text = p.story if p.story.strip_edges() != "" else "[color=gray]（尚無故事）[/color]"
	for c in details_skills.get_children():
		c.queue_free()
	if p.skills.size() == 0:
		var l := Label.new()
		l.add_theme_font_override("font", name_label.get_theme_font("font"))
		l.add_theme_font_size_override("font_size", _PET_PANEL_FONT_SIZE)
		l.text = "（尚無技能）"
		details_skills.add_child(l)
		return
	for e in p.skills:
		if e == null or e.skill == null:
			continue
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var title := Label.new()
		title.add_theme_font_override("font", name_label.get_theme_font("font"))
		title.add_theme_font_size_override("font_size", _PET_PANEL_FONT_SIZE)
		title.text = "%s  Lv.%d" % [e.skill.skill_name, maxi(1, e.skill_level)]
		var cd := Label.new()
		cd.add_theme_font_override("font", name_label.get_theme_font("font"))
		cd.add_theme_font_size_override("font_size", _PET_PANEL_FONT_SIZE)
		cd.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74, 1))
		cd.text = "冷卻：%.1fs" % e.skill.cooldown
		var desc := RichTextLabel.new()
		desc.fit_content = true
		desc.scroll_active = false
		desc.bbcode_enabled = true
		desc.add_theme_font_override("normal_font", name_label.get_theme_font("font"))
		desc.add_theme_font_size_override("normal_font_size", _PET_PANEL_FONT_SIZE)
		desc.text = e.skill.description if e.skill.description.strip_edges() != "" else "[color=gray]（尚無描述）[/color]"
		box.add_child(title)
		box.add_child(cd)
		box.add_child(desc)
		details_skills.add_child(box)

func _refresh_deploy_button() -> void:
	if PetManager.active_pet == null:
		deploy_button.text = "出戰"
	else:
		deploy_button.text = "休息" if (PetManager.deployed_pet == PetManager.active_pet and PetManager.is_deployed) else "出戰"
	_sync_deploy_mount_mutex()

func _sync_deploy_mount_mutex() -> void:
	if PetManager.active_pet == null:
		deploy_button.disabled = true
		mount_button.disabled = true
		release_button.disabled = true
		return
	release_button.disabled = false
	if PetManager.is_deployed:
		deploy_button.disabled = false
		mount_button.disabled = true
	elif _mount_enabled:
		deploy_button.disabled = true
		mount_button.disabled = false
	else:
		deploy_button.disabled = false
		mount_button.disabled = false

func _on_deploy_pressed() -> void:
	if PetManager.active_pet == null:
		return
	if PetManager.is_deployed and PetManager.deployed_pet == PetManager.active_pet:
		SignalBus.pet_recall_requested.emit()
	else:
		SignalBus.pet_deploy_requested.emit(PetManager.active_pet)
