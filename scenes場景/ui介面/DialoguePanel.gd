# res://scenes場景/ui介面/DialoguePanel.gd
extends Control

## 關閉時必須低於 PetUI(20)／InventoryUI(20)，否則全螢幕 Control 仍會攔截輸入。
const _Z_ACTIVE := 28
const _Z_HIDDEN := 8

@onready var _bottom_bar: Control = $BottomBar
@onready var _body_panel: PanelContainer = $BottomBar/Margin/HBox/BodyPanel
@onready var _body: RichTextLabel = $BottomBar/Margin/HBox/BodyPanel/Body
@onready var _choices: VBoxContainer = $BottomBar/Margin/HBox/Choices


func _ready() -> void:
	z_index = _Z_HIDDEN
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _body_panel:
		_body_panel.add_theme_stylebox_override(
			"panel",
			DialogueLedgerButtonStyle.ledger_body_panel_stylebox(6)
		)
	if _body:
		_body.add_theme_color_override("default_color", DialogueLedgerButtonStyle.TEXT_WHITE)
	if SignalBus:
		SignalBus.dialogue_presented.connect(_on_dialogue_presented)
	call_deferred("_sync_layout_for_viewport")
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_sync_layout_for_viewport()


## 與主場景底欄高度一致（預設 63）；寬度隨視窗（預設 360×640）。
func _sync_layout_for_viewport() -> void:
	if _bottom_bar:
		_bottom_bar.offset_bottom = -float(GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX)
	var vp_w: float = get_viewport().get_visible_rect().size.x
	if _body:
		var reserve: float = (
			DialogueLedgerButtonStyle.CHOICE_STRIP_WIDTH
			+ DialogueLedgerButtonStyle.DIALOG_BODY_MIN_WIDTH_GUTTER
		)
		_body.custom_minimum_size.x = maxf(72.0, vp_w - reserve)


func _on_dialogue_presented(
	p_visible: bool,
	body_bbcode: String,
	choice_labels: PackedStringArray
) -> void:
	z_index = _Z_ACTIVE if p_visible else _Z_HIDDEN
	visible = p_visible
	mouse_filter = Control.MOUSE_FILTER_STOP if p_visible else Control.MOUSE_FILTER_IGNORE
	if not p_visible:
		_clear_choices()
		if _body:
			_body.text = ""
		return
	if _body:
		_body.text = body_bbcode
	_clear_choices()
	var choice_font: Font = _body.get_theme_font("normal_font") if _body else null
	for i in choice_labels.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = str(choice_labels[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DialogueLedgerButtonStyle.apply_to_button(b, choice_font, DialogueLedgerButtonStyle.CHOICE_STRIP_WIDTH)
		var idx: int = i
		b.pressed.connect(func() -> void:
			if SignalBus:
				SignalBus.dialogue_choice_selected.emit(idx)
		)
		_choices.add_child(b)


func _clear_choices() -> void:
	if _choices == null:
		return
	for c in _choices.get_children():
		c.queue_free()
