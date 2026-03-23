# res://src腳本/ui/SealUI.gd (最終簡化版)
extends Control

@onready var filter: ColorRect = $Filter
@onready var eye_anim: AnimatedSprite2D = $EyeCutIn
@onready var actor_player: AnimatedSprite2D = $ActorPlayer

func _ready() -> void:
	add_to_group("seal_ui")
	_reset_ui()
	SignalBus.seal_ui_requested.connect(_on_ui_requested)
	SignalBus.seal_draw_progress.connect(_on_draw_progress)

func _reset_ui():
	filter.hide()
	eye_anim.hide()
	actor_player.hide()

func _on_ui_requested(is_show: bool):
	if is_show:
		filter.show()
		eye_anim.show()
		eye_anim.play("open")
		await eye_anim.animation_finished
		actor_player.show()
		actor_player.play("spell")
		actor_player.pause() 
	else:
		# 畫圈結束，全部隱藏，回歸真實世界
		_reset_ui()

func _on_draw_progress(progress: float):
	if actor_player.visible:
		var frames = actor_player.sprite_frames.get_frame_count("spell")
		actor_player.frame = int(progress * (frames - 1))
