# res://src腳本/ui/DialogueLedgerButtonStyle.gd
## 對話選項長條與 NPC 靠近提示鈕：`apply_to_button`／`apply_to_npc_proximity_prompt_button` 皆為 **橘米底＋咖啡色字**；**pressed** 改 **深色底＋白字**。
## 對話主文 `PanelContainer` 仍用 `ledger_body_panel_stylebox`（深色底＋主文白字），與選項長條區隔。
extends RefCounted
class_name DialogueLedgerButtonStyle

const BROWN := Color(0.29, 0.22, 0.16, 1)
const BG := Color(0.741176, 0.717647, 0.65098, 1)
const BG_HOVER := Color(0.588235, 0.568627, 0.513725, 1)
const BG_PRESSED := Color(0.886275, 0.827451, 0.709804, 1)
## 對話主文／選項／靠近提示的預設底（同 BG_HOVER，即文件「深色」）
const BG_DIALOG_IDLE := BG_HOVER
const TEXT_WHITE := Color(1, 1, 1, 1)
## 提示／選項長條：與 `DIALOG_STRIP_FONT_SIZE` 一併調整以維持比例
const STRIP_HEIGHT := 28
## 右欄最小寬（約比上一版縮兩個全形字視覺寬；長句靠 autowrap）
const CHOICE_STRIP_WIDTH := 132
const DIALOG_STRIP_FONT_SIZE := 10
## `DialoguePanel` 主文最小寬：viewport 減右欄與 Margin+HBox 留白（6+6+8）
const DIALOG_BODY_MIN_WIDTH_GUTTER := 20.0

static func _ledger_box(bg: Color, corner_radius: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(2)
	s.border_color = BROWN
	s.set_corner_radius_all(corner_radius)
	return s


## 對話主文 `PanelContainer`：深色底＋咖啡色框，內文配 `TEXT_WHITE`。
static func ledger_body_panel_stylebox(content_margin: int = 8) -> StyleBoxFlat:
	var s := _ledger_box(BG_DIALOG_IDLE)
	s.set_content_margin_all(content_margin)
	return s


## **`NpcInteractionPrompt`**：與對話選項同一套視覺，僅 `corner_radius` 預設為 5（微圓角）。
static func apply_to_npc_proximity_prompt_button(btn: Button, font: Font, min_width: float = 0.0, corner_radius: int = 5) -> void:
	apply_to_button(btn, font, min_width, corner_radius)


## 帳簿長條按鈕：idle／hover／focus＝橘米底＋咖啡字；pressed＝深色底（`BG_DIALOG_IDLE`）＋白字。
## `corner_radius`：對話選項傳 0；NPC 提示傳 5。
static func apply_to_button(btn: Button, font: Font, min_width: float = 0.0, corner_radius: int = 0) -> void:
	btn.custom_minimum_size.y = STRIP_HEIGHT
	if min_width > 0.0:
		btn.custom_minimum_size.x = min_width
	btn.add_theme_font_size_override("font_size", DIALOG_STRIP_FONT_SIZE)
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_color_override("font_color", BROWN)
	btn.add_theme_color_override("font_hover_color", BROWN)
	btn.add_theme_color_override("font_pressed_color", TEXT_WHITE)
	btn.add_theme_color_override("font_focus_color", BROWN)
	var orange := _ledger_box(BG_PRESSED, corner_radius)
	btn.add_theme_stylebox_override("normal", orange)
	btn.add_theme_stylebox_override("hover", orange)
	btn.add_theme_stylebox_override("pressed", _ledger_box(BG_DIALOG_IDLE, corner_radius))
	btn.add_theme_stylebox_override("focus", orange)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.clip_text = false
