extends Control
## 可重用確認對話框：標題、內文（BBCode）、確認／取消按鈕。不經 SignalBus，由呼叫端接 signal。

signal confirmed
signal cancelled

@onready var _dim: ColorRect = $Dim
@onready var _title_label: Label = $PanelRoot/Column/TitleLabel
@onready var _body_label: RichTextLabel = $PanelRoot/Column/BodyLabel
@onready var _confirm_btn: Button = $PanelRoot/Column/ButtonsRow/ConfirmBtn
@onready var _cancel_btn: Button = $PanelRoot/Column/ButtonsRow/CancelBtn

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)


func present(
		title: String,
		body_bbcode: String,
		confirm_text: String = "確認",
		cancel_text: String = "取消"
	) -> void:
	_title_label.text = title
	_body_label.text = body_bbcode
	_confirm_btn.text = confirm_text
	_cancel_btn.text = cancel_text
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	move_to_front()


func dismiss() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_confirm_pressed() -> void:
	dismiss()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	dismiss()
	cancelled.emit()
