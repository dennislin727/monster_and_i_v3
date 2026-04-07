# res://scenes場景/ui介面/NpcInteractionPrompt.gd
extends Control

## 直向 360×640、主角 Camera2D zoom≠1 時，世界座標仍由 get_canvas_transform() 正確換算；此處再夾在可視區內並避開底欄。
const _SCREEN_MARGIN := 4.0
const _Z_ABOVE_PANELS := 32
const _Z_BELOW_PET_UI := 8

@onready var _button: Button = $PromptButton
@onready var _font: Font = _button.get_theme_font("font") if _button else null

var _showing: bool = false
var _npc_id: String = ""
var _anchor_world: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_index = _Z_BELOW_PET_UI
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if _button:
		var f: Font = _font
		if f == null:
			f = _button.get_theme_font("font")
		DialogueLedgerButtonStyle.apply_to_npc_proximity_prompt_button(_button, f, DialogueLedgerButtonStyle.CHOICE_STRIP_WIDTH, 5)
		_button.pressed.connect(_on_button_pressed)
	if SignalBus:
		SignalBus.npc_interaction_prompt_changed.connect(_on_prompt_changed)


func _process(_delta: float) -> void:
	if not _showing:
		return
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var canvas_pos: Vector2 = xf * _anchor_world
	var pos: Vector2 = canvas_pos + Vector2(6, -4)
	var vp: Rect2 = get_viewport().get_visible_rect()
	var bar_h: float = float(GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX)
	var panel_size: Vector2 = _button.size if _button and _button.size.length_squared() > 4.0 else Vector2.ZERO
	if panel_size.x < 4.0 or panel_size.y < 4.0:
		panel_size = (
			_button.get_combined_minimum_size()
			if _button
			else Vector2(
				DialogueLedgerButtonStyle.CHOICE_STRIP_WIDTH,
				DialogueLedgerButtonStyle.STRIP_HEIGHT
			)
		)
	pos.x = clampf(pos.x, vp.position.x + _SCREEN_MARGIN, vp.end.x - panel_size.x - _SCREEN_MARGIN)
	var min_y: float = vp.position.y + _SCREEN_MARGIN
	var max_y: float = vp.end.y - panel_size.y - bar_h - _SCREEN_MARGIN
	if max_y < min_y:
		max_y = min_y
	pos.y = clampf(pos.y, min_y, max_y)
	global_position = pos


func _on_prompt_changed(
	p_visible: bool,
	npc_id: String,
	prompt_text: String,
	anchor_global: Vector2
) -> void:
	_showing = p_visible
	_npc_id = npc_id
	_anchor_world = anchor_global
	z_index = _Z_ABOVE_PANELS if p_visible else _Z_BELOW_PET_UI
	visible = p_visible
	# 根節點維持 IGNORE，只讓 PromptButton 接觸控，避免隱形全層擋住底欄／寵物頁。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _button:
		_button.text = prompt_text if p_visible else ""


func _on_button_pressed() -> void:
	if _npc_id.strip_edges().is_empty():
		return
	if SignalBus:
		SignalBus.npc_dialogue_requested.emit(_npc_id.strip_edges())
