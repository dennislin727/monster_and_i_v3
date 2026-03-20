# res://src腳本/ui/SealUI.gd
extends Control

@onready var filter: ColorRect = $Filter
@onready var eye_anim: AnimatedSprite2D = $EyeCutIn

func _ready() -> void:
	# 加入群組方便找到
	add_to_group("seal_ui")
	filter.hide()
	eye_anim.hide()
	# 監聽顯示請求
	SignalBus.seal_ui_requested.connect(_on_ui_requested)

func _on_ui_requested(is_show: bool):
	if is_show:
		filter.show()
		eye_anim.show()
		eye_anim.play("open")
	else:
		filter.hide()
		eye_anim.hide()
