extends Control

const _PET_PANEL_FONT_SIZE := 11
const _PET_SKILL_TITLE_FONT_SIZE := 12
const _PET_LIST_NAME_FONT_SIZE := 12
const _PET_LIST_META_FONT_SIZE := 11
const _PET_HEADER_LEVEL_FONT_SIZE := 12
const _BROWN_TEXT := Color(0.29, 0.22, 0.16)
## 與 PetUI.tscn `StyleBoxFlat_ledger_btn_n` 底色一致；出戰／坐騎拮抗 disabled 時用（無邊框、不變灰）
const _LEDGER_BTN_BG_NORMAL := Color(0.741176, 0.717647, 0.65098, 1)
## 口語「橘色」#E2D3B5；「休息」「下騎」時 normal 底色（與 ledger_btn_p 一致）
const _LEDGER_BTN_BG_REST_RIDE := Color(0.886275, 0.827451, 0.709804, 1)
## 口語「深色」#969183；帳簿 hover、寵物頭像框底色
const _LEDGER_BTN_BG_DARK := Color(0.588235, 0.568627, 0.513725, 1)

@onready var open_button: Button = $OpenButton
@onready var panel: Control = $Panel
@onready var list_rows: VBoxContainer = $Panel/Root/MainColumns/Left/ListScroll/PetListRows
@onready var right_column: Control = $Panel/Root/MainColumns/Right
@onready var icon_frame: Panel = $Panel/Root/MainColumns/Right/HeaderRow/IconFrame
@onready var portrait_sprite: AnimatedSprite2D = $Panel/Root/MainColumns/Right/HeaderRow/IconFrame/PortraitViewportContainer/PortraitViewport/PortraitSprite
@onready var name_label: Label = $Panel/Root/MainColumns/Right/HeaderRow/NameBlock/Name
@onready var rename_button: Button = $Panel/Root/MainColumns/Right/HeaderRow/NameBlock/RenameButton
@onready var deploy_button: Button = $Panel/Root/MainColumns/Right/Buttons/DeployButton
@onready var mount_button: Button = $Panel/Root/MainColumns/Right/Buttons/MountButton
@onready var release_button: Button = $Panel/Root/MainColumns/Right/Buttons/ReleaseButton
@onready var details_level: Label = $Panel/Root/MainColumns/Right/HeaderRow/NameBlock/Level
@onready var details_story: RichTextLabel = $Panel/Root/MainColumns/Right/DetailsScroll/DetailsInner/Story
@onready var details_skills: VBoxContainer = $Panel/Root/MainColumns/Right/DetailsScroll/DetailsInner/Skills
@onready var story_hint: Label = $Panel/Root/MainColumns/Right/DetailsScroll/DetailsInner/StoryHint
@onready var skills_title: Label = $Panel/Root/MainColumns/Right/DetailsScroll/DetailsInner/SkillsTitle
@onready var dialog_layer: CanvasLayer = $DialogLayer
@onready var confirm_dialog = $DialogLayer/ConfirmDialog
@onready var nickname_popup: PopupPanel = $DialogLayer/NicknamePopup
@onready var nickname_line: LineEdit = $DialogLayer/NicknamePopup/Margin/VBox/LineEdit

var _pet_items: Array[PetResource] = []
var _style_icon_idle: StyleBoxFlat = null
var _style_icon_selected: StyleBoxFlat = null
var _style_row_idle: StyleBoxFlat = null
var _style_row_selected: StyleBoxFlat = null
var _style_row_hover: StyleBoxFlat = null
var _style_deploy_mount_mutex_disabled: StyleBoxFlat = null
var _style_ledger_normal_deploy: StyleBoxFlat = null
var _style_ledger_normal_mount: StyleBoxFlat = null
var _style_ledger_normal_rest_ride: StyleBoxFlat = null
var _pending_release: PetResource = null

func _ready() -> void:
	if GlobalBalance:
		panel.offset_bottom = -GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	open_button.toggle_mode = true
	open_button.toggled.connect(_on_open_button_toggled)
	deploy_button.pressed.connect(_on_deploy_pressed)
	mount_button.pressed.connect(_on_place_pressed)
	mount_button.text = "看家"
	release_button.pressed.connect(_on_release_pressed)
	rename_button.pressed.connect(_open_nickname_dialog)
	confirm_dialog.confirmed.connect(_on_release_confirmed)
	confirm_dialog.cancelled.connect(_on_release_cancelled)
	nickname_popup.hide()
	_setup_nickname_popup()
	details_level.add_theme_font_size_override("font_size", _PET_HEADER_LEVEL_FONT_SIZE)
	_style_icon_idle = StyleBoxFlat.new()
	_style_icon_idle.bg_color = _LEDGER_BTN_BG_DARK
	_style_icon_idle.set_border_width_all(2)
	_style_icon_idle.border_color = _BROWN_TEXT
	_style_icon_idle.set_corner_radius_all(6)

	_style_icon_selected = StyleBoxFlat.new()
	_style_icon_selected.bg_color = _LEDGER_BTN_BG_DARK
	_style_icon_selected.set_border_width_all(2)
	_style_icon_selected.border_color = _BROWN_TEXT
	_style_icon_selected.set_corner_radius_all(6)

	_style_row_idle = StyleBoxFlat.new()
	_style_row_idle.bg_color = Color(0, 0, 0, 0)
	_style_row_selected = StyleBoxFlat.new()
	_style_row_selected.bg_color = _LEDGER_BTN_BG_REST_RIDE
	_style_row_selected.set_border_width_all(2)
	_style_row_selected.border_color = _BROWN_TEXT
	_style_row_selected.set_corner_radius_all(6)
	_style_row_hover = StyleBoxFlat.new()
	_style_row_hover.bg_color = Color(_LEDGER_BTN_BG_DARK.r, _LEDGER_BTN_BG_DARK.g, _LEDGER_BTN_BG_DARK.b, 0.42)
	_style_row_hover.set_border_width_all(0)
	_style_row_hover.set_corner_radius_all(6)

	_style_deploy_mount_mutex_disabled = StyleBoxFlat.new()
	_style_deploy_mount_mutex_disabled.bg_color = _LEDGER_BTN_BG_NORMAL
	_style_deploy_mount_mutex_disabled.set_border_width_all(0)
	_style_deploy_mount_mutex_disabled.set_corner_radius_all(6)

	var base_normal := deploy_button.get_theme_stylebox("normal")
	if base_normal != null:
		_style_ledger_normal_deploy = base_normal.duplicate() as StyleBoxFlat
		_style_ledger_normal_mount = base_normal.duplicate() as StyleBoxFlat
	else:
		_style_ledger_normal_deploy = _make_ledger_normal_stylebox(_LEDGER_BTN_BG_NORMAL)
		_style_ledger_normal_mount = _make_ledger_normal_stylebox(_LEDGER_BTN_BG_NORMAL)
	_style_ledger_normal_rest_ride = _make_ledger_normal_stylebox(_LEDGER_BTN_BG_REST_RIDE)

	_hide_panel()
	_apply_icon_frame_style(false)

	for n in [name_label, details_level]:
		n.mouse_filter = Control.MOUSE_FILTER_STOP
		n.gui_input.connect(_on_rename_zone_gui_input.bind(n))

	if SignalBus:
		SignalBus.pet_captured.connect(_on_pet_captured)
		SignalBus.pet_roster_changed.connect(_refresh)
		SignalBus.pet_active_changed.connect(_on_pet_active_changed)
		SignalBus.pet_deployed_changed.connect(_on_pet_deployed_changed)
		SignalBus.player_in_homestead_changed.connect(_on_player_in_homestead_changed)
		SignalBus.pet_ui_close_requested.connect(_hide_panel)
		SignalBus.pet_nickname_changed.connect(_on_pet_nickname_changed)

	_refresh()


func _brown_bbcode(inner: String) -> String:
	return "[color=#%s]%s[/color]" % [_BROWN_TEXT.to_html(false), inner]


## 與 `PetCompanion._resolve_sprite_frames` 同序，避免 UI／場上視覺來源分叉。
func _resolve_portrait_sprite_frames(d: PetResource) -> SpriteFrames:
	if d == null:
		return null
	if d.sprite_frames:
		return d.sprite_frames
	if d.pet_id.strip_edges().is_empty():
		return _fallback_portrait_sprite_frames()
	var path := "res://resources身分證/monster/%s.tres" % d.pet_id
	if ResourceLoader.exists(path):
		var mres := load(path) as MonsterResource
		if mres and mres.sprite_frames:
			return mres.sprite_frames
	return _fallback_portrait_sprite_frames()


func _fallback_portrait_sprite_frames() -> SpriteFrames:
	var mres := load("res://resources身分證/monster/slime_green.tres") as MonsterResource
	if mres:
		return mres.sprite_frames
	return null


## 與 `PetCompanion._play_celebrate` 前段優先序對齊，再補 idle 後備。
func _pick_portrait_animation(sf: SpriteFrames) -> String:
	if sf == null:
		return ""
	if sf.has_animation("happy") and sf.get_frame_count("happy") > 0:
		return "happy"
	if sf.has_animation("spell") and sf.get_frame_count("spell") > 0:
		return "spell"
	for cand in ["idle_down", "idle_side", "idle_up"]:
		if sf.has_animation(cand) and sf.get_frame_count(cand) > 0:
			return cand
	var names := sf.get_animation_names()
	if names.size() > 0:
		return str(names[0])
	return ""


func _clear_portrait() -> void:
	if portrait_sprite == null:
		return
	portrait_sprite.stop()
	portrait_sprite.sprite_frames = null


func _play_portrait_anim(p: PetResource) -> void:
	if portrait_sprite == null:
		return
	var sf := _resolve_portrait_sprite_frames(p)
	if sf == null:
		_clear_portrait()
		return
	portrait_sprite.sprite_frames = sf.duplicate(true)
	var anim_name := _pick_portrait_animation(portrait_sprite.sprite_frames)
	if anim_name.is_empty():
		_clear_portrait()
		return
	portrait_sprite.stop()
	portrait_sprite.play(anim_name)


func _make_ledger_normal_stylebox(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(2)
	s.border_color = _BROWN_TEXT
	s.set_corner_radius_all(6)
	return s


func _apply_rest_ride_normal_styles() -> void:
	if _style_ledger_normal_deploy == null or _style_ledger_normal_mount == null:
		return
	if _style_ledger_normal_rest_ride == null:
		return
	var ap := PetManager.active_pet
	var at_rest := ap != null and PetManager.is_pet_on_party(ap)
	if at_rest:
		deploy_button.add_theme_stylebox_override("normal", _style_ledger_normal_rest_ride)
	else:
		deploy_button.add_theme_stylebox_override("normal", _style_ledger_normal_deploy)
	if HomeManager and HomeManager.in_homestead:
		mount_button.add_theme_stylebox_override("normal", _style_ledger_normal_mount)


func _setup_nickname_popup() -> void:
	var ok_btn: Button = nickname_popup.get_node_or_null("Margin/VBox/OkRow/OkButton") as Button
	var cancel_btn: Button = nickname_popup.get_node_or_null("Margin/VBox/OkRow/CancelButton") as Button
	if ok_btn:
		ok_btn.pressed.connect(_on_nickname_confirmed)
	if cancel_btn:
		cancel_btn.pressed.connect(_on_nickname_cancelled)
	nickname_line.text_submitted.connect(func(_t: String) -> void: _on_nickname_confirmed())
	nickname_line.max_length = 12


func _on_open_button_toggled(pressed_state: bool) -> void:
	if pressed_state:
		_show_panel()
	else:
		_hide_panel()


func _show_panel() -> void:
	if SignalBus:
		if HomeManager != null and HomeManager.harvest_active:
			SignalBus.harvest_mode_toggled.emit(false)
		SignalBus.inventory_ui_close_requested.emit()
		SignalBus.diary_ui_close_requested.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	open_button.set_pressed_no_signal(true)
	_refresh()


func _hide_panel() -> void:
	open_button.set_pressed_no_signal(false)
	if confirm_dialog.visible:
		confirm_dialog.dismiss()
	_clear_portrait()
	panel.hide()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_icon_frame_style(false)
	_pending_release = null
	nickname_popup.hide()
	dialog_layer.visible = false


func _on_place_pressed() -> void:
	if PetManager.active_pet == null or HomeManager == null:
		return
	if not HomeManager.in_homestead:
		return
	if SignalBus:
		SignalBus.pet_sent_to_home_requested.emit(PetManager.active_pet)
	_refresh()


func _on_player_in_homestead_changed(_inside: bool) -> void:
	_refresh_deploy_button()


func _on_release_pressed() -> void:
	var p := PetManager.active_pet
	if p == null:
		return
	_pending_release = p
	var display_name := p.nickname if p.nickname.strip_edges() != "" else (p.pet_name if p.pet_name != "" else p.pet_id)
	var lvl := maxi(1, p.level)
	var body := (
		"要將 %s（Lv.%d）放生嗎？\n\n"
		+ "放生後牠會離開隨身清單；也可先放到家園陪媽媽。確定嗎？"
	) % [display_name, lvl]
	dialog_layer.visible = true
	confirm_dialog.present("確認放生", body, "放生", "取消")


func _on_release_confirmed() -> void:
	if _pending_release != null:
		SignalBus.pet_release_requested.emit(_pending_release)
	_pending_release = null
	dialog_layer.visible = false


func _on_release_cancelled() -> void:
	_pending_release = null
	dialog_layer.visible = false


func _on_pet_captured(_pet_data: PetResource) -> void:
	_refresh()


func _on_pet_active_changed(_pet_data: Variant) -> void:
	_refresh_details()
	_refresh_deploy_button()
	_refresh_selection()


func _on_pet_deployed_changed(_is_deployed: bool) -> void:
	_refresh()


func _on_pet_nickname_changed(_pet_data: PetResource) -> void:
	_refresh()


func _open_nickname_dialog() -> void:
	if PetManager.active_pet == null:
		return
	nickname_line.text = ""
	nickname_line.virtual_keyboard_enabled = true
	dialog_layer.visible = true
	nickname_popup.popup_centered(Vector2i(320, 140))
	call_deferred("_nickname_line_grab_focus_for_mobile_keyboard")


func _nickname_line_grab_focus_for_mobile_keyboard() -> void:
	if nickname_line and is_instance_valid(nickname_line):
		nickname_line.grab_focus()


func _on_nickname_confirmed() -> void:
	var p := PetManager.active_pet
	if p != null and SignalBus:
		SignalBus.pet_nickname_change_requested.emit(p, nickname_line.text)
	nickname_popup.hide()
	dialog_layer.visible = false


func _on_nickname_cancelled() -> void:
	nickname_popup.hide()
	dialog_layer.visible = false


func _on_rename_zone_gui_input(event: InputEvent, _which: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_nickname_dialog()


func _refresh() -> void:
	_pet_items = PetManager.captured_pets.duplicate()
	for c in list_rows.get_children():
		c.queue_free()

	var row_font := open_button.get_theme_font("font")
	for p in _pet_items:
		if p == null:
			continue
		if PetManager.is_pet_stationed(p):
			continue
		list_rows.add_child(_make_pet_list_row(p, row_font))

	_refresh_details()
	_refresh_selection()
	_refresh_deploy_button()


func _make_pet_list_row(p: PetResource, row_font: Font) -> Button:
	var display_name := p.nickname if p.nickname.strip_edges() != "" else (p.pet_name if p.pet_name != "" else p.pet_id)
	var meta := " Lv%d" % maxi(1, p.level)
	if PetManager.is_pet_on_party(p):
		meta += "·[戰]"

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size.y = 44
	btn.set_meta("pet_resource", p)
	btn.add_theme_stylebox_override("normal", _style_row_idle)
	btn.add_theme_stylebox_override("hover", _style_row_hover)
	btn.add_theme_stylebox_override("pressed", _style_row_selected)
	btn.pressed.connect(_on_list_row_pressed.bind(p))

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	btn.add_child(outer)
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 6
	outer.offset_top = 4
	outer.offset_right = -6
	outer.offset_bottom = -4

	var name_l := Label.new()
	name_l.text = display_name
	if row_font:
		name_l.add_theme_font_override("font", row_font)
	name_l.add_theme_font_size_override("font_size", _PET_LIST_NAME_FONT_SIZE)
	name_l.add_theme_color_override("font_color", _BROWN_TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true

	var meta_l := Label.new()
	meta_l.text = meta
	if row_font:
		meta_l.add_theme_font_override("font", row_font)
	meta_l.add_theme_font_size_override("font_size", _PET_LIST_META_FONT_SIZE)
	meta_l.add_theme_color_override("font_color", _BROWN_TEXT)

	outer.add_child(name_l)
	outer.add_child(meta_l)
	return btn


func _on_list_row_pressed(p: PetResource) -> void:
	if p == null:
		return
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
	right_column.visible = p != null
	if p == null:
		_clear_portrait()
		return

	name_label.text = p.nickname if p.nickname.strip_edges() != "" else (p.pet_name if p.pet_name != "" else "未命名寵物")
	_apply_icon_frame_style(true)
	_play_portrait_anim(p)
	_refresh_details_panel(p)


func _apply_icon_frame_style(selected: bool) -> void:
	if not icon_frame:
		return
	icon_frame.add_theme_stylebox_override("panel", _style_icon_selected if selected else _style_icon_idle)


func _refresh_details_panel(p: PetResource) -> void:
	if p == null:
		return
	var xp_hint := ""
	if GlobalBalance and p.level < GlobalBalance.PET_MAX_LEVEL:
		var need := GlobalBalance.xp_needed_for_pet_next_level(p.level)
		xp_hint = "　（經驗 %d/%d）" % [p.experience, need]
	details_level.text = "等級：%d%s" % [maxi(1, p.level), xp_hint]
	details_story.text = p.story if p.story.strip_edges() != "" else _brown_bbcode("（尚無故事）")
	for c in details_skills.get_children():
		c.queue_free()
	if p.skills.size() == 0:
		var l := Label.new()
		l.add_theme_font_override("font", name_label.get_theme_font("font"))
		l.add_theme_font_size_override("font_size", _PET_PANEL_FONT_SIZE)
		l.add_theme_color_override("font_color", _BROWN_TEXT)
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
		title.add_theme_font_size_override("font_size", _PET_SKILL_TITLE_FONT_SIZE)
		title.add_theme_color_override("font_color", _BROWN_TEXT)
		var disp_lv := maxi(1, e.skill_level)
		if GlobalBalance:
			disp_lv = maxi(disp_lv, GlobalBalance.combat_skill_display_level_from_pet_level(p.level))
		title.text = "%s  Lv.%d" % [e.skill.skill_name, disp_lv]
		var cd := Label.new()
		cd.add_theme_font_override("font", name_label.get_theme_font("font"))
		cd.add_theme_font_size_override("font_size", _PET_PANEL_FONT_SIZE)
		cd.add_theme_color_override("font_color", _BROWN_TEXT)
		if e.skill.is_homestead_till_skill and GlobalBalance:
			cd.text = "家園土格上限：%d" % GlobalBalance.homestead_soil_cap_from_pet_level(p.level)
		else:
			cd.text = "冷卻：%.1fs" % e.skill.cooldown
		var desc := RichTextLabel.new()
		desc.fit_content = true
		desc.scroll_active = false
		desc.bbcode_enabled = true
		desc.add_theme_color_override("default_color", _BROWN_TEXT)
		desc.add_theme_font_override("normal_font", name_label.get_theme_font("font"))
		desc.add_theme_font_size_override("normal_font_size", _PET_PANEL_FONT_SIZE)
		desc.text = e.skill.description if e.skill.description.strip_edges() != "" else _brown_bbcode("（尚無描述）")
		box.add_child(title)
		box.add_child(cd)
		box.add_child(desc)
		details_skills.add_child(box)


func _refresh_deploy_button() -> void:
	if PetManager.active_pet == null:
		deploy_button.text = "出戰"
	else:
		var at_rest := PetManager.is_pet_on_party(PetManager.active_pet)
		deploy_button.text = "休息" if at_rest else "出戰"
	_sync_deploy_mount_mutex()


func _sync_deploy_mount_mutex() -> void:
	deploy_button.remove_theme_stylebox_override("disabled")
	mount_button.remove_theme_stylebox_override("disabled")
	var at_home := HomeManager != null and HomeManager.in_homestead
	mount_button.visible = at_home
	if PetManager.active_pet == null:
		deploy_button.disabled = true
		mount_button.disabled = true
		release_button.disabled = true
		_apply_rest_ride_normal_styles()
		return
	release_button.disabled = false
	var party_full := PetManager.find_first_empty_party_slot() < 0
	var on_party := PetManager.is_pet_on_party(PetManager.active_pet)
	deploy_button.disabled = (not on_party) and party_full
	if at_home:
		var can_place := not PetManager.is_pet_stationed(PetManager.active_pet)
		mount_button.disabled = not can_place
		if not can_place:
			mount_button.add_theme_stylebox_override("disabled", _style_deploy_mount_mutex_disabled)
	_apply_rest_ride_normal_styles()


func _on_deploy_pressed() -> void:
	if PetManager.active_pet == null:
		return
	if PetManager.is_pet_on_party(PetManager.active_pet):
		SignalBus.pet_recall_requested.emit()
	else:
		SignalBus.pet_deploy_requested.emit(PetManager.active_pet)
