# res://scenes場景/ui介面/DiaryUI.gd
extends Control

const _BROWN_TEXT := Color(0.29, 0.22, 0.16)
const SCROLLBAR_MIN := 20

@onready var open_button: Button = $OpenButton
@onready var panel: Control = $Panel
@onready var tab_mood: Button = $Panel/Root/TabsChrome/TabsMargin/Tabs/TabMood
@onready var tab_career: Button = $Panel/Root/TabsChrome/TabsMargin/Tabs/TabCareer
@onready var page_mood: Control = $Panel/Root/PageMood
@onready var page_career: Control = $Panel/Root/PageCareer
@onready var mood_scroll: ScrollContainer = $Panel/Root/PageMood/MoodScroll
@onready var mood_list: VBoxContainer = $Panel/Root/PageMood/MoodScroll/MoodList
@onready var add_note_button: Button = $Panel/Root/PageMood/AddNoteButton
@onready var career_scroll: ScrollContainer = $Panel/Root/PageCareer/CareerScroll
@onready var career_list: VBoxContainer = $Panel/Root/PageCareer/CareerScroll/CareerList

var _tab_group: ButtonGroup
var _expanded_note_id: String = ""


func _ready() -> void:
	if GlobalBalance:
		panel.offset_bottom = -GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_group = ButtonGroup.new()
	tab_mood.button_group = _tab_group
	tab_career.button_group = _tab_group
	tab_mood.toggled.connect(_on_tab_mood_toggled)
	tab_career.toggled.connect(_on_tab_career_toggled)
	tab_mood.button_pressed = true
	add_note_button.pressed.connect(_on_add_note_pressed)
	mood_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	career_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_apply_scrollbar_width(mood_scroll)
	_apply_scrollbar_width(career_scroll)
	open_button.toggle_mode = true
	open_button.toggled.connect(_on_open_button_toggled)
	if SignalBus:
		SignalBus.diary_ui_close_requested.connect(_hide_panel)
	if DiaryManager:
		DiaryManager.mood_notes_changed.connect(_on_mood_notes_changed)
		DiaryManager.career_changed.connect(_on_career_changed)
	_hide_panel()
	_refresh_mood_list()
	_refresh_career_list()


func _apply_scrollbar_width(sc: ScrollContainer) -> void:
	var vs: ScrollBar = sc.get_v_scroll_bar()
	if vs:
		vs.custom_minimum_size.x = SCROLLBAR_MIN


func _on_tab_mood_toggled(pressed: bool) -> void:
	if pressed:
		page_mood.show()
		page_career.hide()


func _on_tab_career_toggled(pressed: bool) -> void:
	if pressed:
		page_mood.hide()
		page_career.show()


func _on_mood_notes_changed() -> void:
	if panel.visible:
		_refresh_mood_list()


func _on_career_changed() -> void:
	if panel.visible:
		_refresh_career_list()


func _on_add_note_pressed() -> void:
	if DiaryManager == null:
		return
	var nid := DiaryManager.add_mood_note()
	_expanded_note_id = nid
	_refresh_mood_list()
	call_deferred("_deferred_scroll_mood_to_bottom")


func _deferred_scroll_mood_to_bottom() -> void:
	await get_tree().process_frame
	var vs: ScrollBar = mood_scroll.get_v_scroll_bar()
	if vs:
		mood_scroll.scroll_vertical = int(vs.max_value)


func _deferred_focus_diary_title_edit(le: LineEdit) -> void:
	if le != null and is_instance_valid(le):
		le.grab_focus()


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
		SignalBus.inventory_ui_close_requested.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	open_button.set_pressed_no_signal(true)
	_refresh_mood_list()
	_refresh_career_list()


func _hide_panel() -> void:
	open_button.set_pressed_no_signal(false)
	panel.hide()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_mood_list() -> void:
	for c in mood_list.get_children():
		mood_list.remove_child(c)
		c.queue_free()
	if DiaryManager == null:
		return
	for n in DiaryManager.get_mood_notes():
		_add_mood_row(n)


func _add_mood_row(note: Dictionary) -> void:
	var nid := str(note.get("id", ""))
	var created := int(note.get("created_unix", 0))
	var title := str(note.get("title", ""))
	var body := str(note.get("body", ""))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 6)
	var expand_btn := Button.new()
	expand_btn.text = "▼" if _expanded_note_id == nid else "▶"
	expand_btn.custom_minimum_size = Vector2(28, 28)
	expand_btn.focus_mode = Control.FOCUS_NONE
	_style_small_button(expand_btn)
	var summary := Label.new()
	summary.text = DiaryManager.format_note_date_line(created, title)
	summary.add_theme_color_override("font_color", _BROWN_TEXT)
	var fnt: Font = open_button.get_theme_font("font")
	if fnt:
		summary.add_theme_font_override("font", fnt)
	summary.add_theme_font_size_override("font_size", 11)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var del_btn := Button.new()
	del_btn.text = "刪"
	del_btn.custom_minimum_size = Vector2(32, 28)
	del_btn.focus_mode = Control.FOCUS_NONE
	_style_small_button(del_btn)
	head_row.add_child(expand_btn)
	head_row.add_child(summary)
	head_row.add_child(del_btn)
	var editor := VBoxContainer.new()
	editor.visible = _expanded_note_id == nid
	var title_edit := LineEdit.new()
	title_edit.placeholder_text = "短標題（選填）"
	title_edit.text = title
	title_edit.virtual_keyboard_enabled = true
	title_edit.add_theme_color_override("font_color", _BROWN_TEXT)
	if fnt:
		title_edit.add_theme_font_override("font", fnt)
		title_edit.add_theme_font_size_override("font_size", 11)
	var body_edit := TextEdit.new()
	body_edit.custom_minimum_size = Vector2(0, 88)
	body_edit.placeholder_text = "心情與紀錄…"
	body_edit.text = body
	body_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body_edit.virtual_keyboard_enabled = true
	if fnt:
		body_edit.add_theme_font_override("font", fnt)
		body_edit.add_theme_font_size_override("font_size", 11)
	editor.add_child(title_edit)
	editor.add_child(body_edit)
	outer.add_child(head_row)
	outer.add_child(editor)
	mood_list.add_child(outer)
	if editor.visible:
		call_deferred("_deferred_focus_diary_title_edit", title_edit)
	expand_btn.pressed.connect(func() -> void:
		_expanded_note_id = "" if _expanded_note_id == nid else nid
		_commit_note_if_needed(nid, title_edit.text, body_edit.text)
		_refresh_mood_list()
	)
	del_btn.pressed.connect(func() -> void:
		if DiaryManager:
			DiaryManager.remove_mood_note(nid)
		if _expanded_note_id == nid:
			_expanded_note_id = ""
		_refresh_mood_list()
	)
	title_edit.text_changed.connect(func(_t: String) -> void:
		if DiaryManager:
			DiaryManager.update_mood_note(nid, title_edit.text, body_edit.text, false)
	)
	body_edit.text_changed.connect(func() -> void:
		if DiaryManager:
			DiaryManager.update_mood_note(nid, title_edit.text, body_edit.text, false)
	)


func _commit_note_if_needed(nid: String, title: String, body: String) -> void:
	if DiaryManager == null:
		return
	DiaryManager.update_mood_note(nid, title, body, false)


func _style_small_button(b: Button) -> void:
	b.add_theme_color_override("font_color", _BROWN_TEXT)
	b.add_theme_color_override("font_pressed_color", _BROWN_TEXT)
	b.add_theme_color_override("font_hover_color", _BROWN_TEXT)


func _refresh_career_list() -> void:
	for c in career_list.get_children():
		career_list.remove_child(c)
		c.queue_free()
	if DiaryManager == null:
		return
	var entries := DiaryManager.get_career_list()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "尚未解鎖生涯紀錄。完成劇情與一次性事件後會自動寫入。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", _BROWN_TEXT)
		var fnt2: Font = open_button.get_theme_font("font")
		if fnt2:
			empty.add_theme_font_override("font", fnt2)
		empty.add_theme_font_size_override("font_size", 11)
		career_list.add_child(empty)
		return
	for e in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var bullet := Label.new()
		bullet.text = "・"
		bullet.add_theme_color_override("font_color", _BROWN_TEXT)
		var lab := Label.new()
		var ux := int(e.get("unix", 0))
		var tline := ""
		if ux > 0:
			var dt := Time.get_datetime_dict_from_unix_time(ux) as Dictionary
			tline = "%d/%d/%d　" % [int(dt.get("year", 0)), int(dt.get("month", 0)), int(dt.get("day", 0))]
		lab.text = tline + str(e.get("title", ""))
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.add_theme_color_override("font_color", _BROWN_TEXT)
		var fnt3: Font = open_button.get_theme_font("font")
		if fnt3:
			lab.add_theme_font_override("font", fnt3)
		lab.add_theme_font_size_override("font_size", 11)
		row.add_child(bullet)
		row.add_child(lab)
		career_list.add_child(row)
