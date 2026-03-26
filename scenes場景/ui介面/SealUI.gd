# res://src腳本/ui/SealUI.gd
extends Control

@onready var filter: ColorRect = $Filter
@onready var actor: AnimatedSprite2D = $ActorPlayer

var is_ready_to_draw: bool = false
var is_finishing: bool = false # 🟢 防止大劍期間還在動進度條

func _ready() -> void:
	add_to_group("seal_ui")
	_reset_ui()
	SignalBus.seal_ui_requested.connect(_on_ui_requested)
	SignalBus.seal_draw_progress.connect(_on_draw_progress)
	# 🟢 聽這個信號來啟動大劍
	SignalBus.seal_draw_confirmed.connect(_on_draw_confirmed)
	
	if not actor.animation_finished.is_connected(_on_animation_finished):
		actor.animation_finished.connect(_on_animation_finished)

func _reset_ui():
	filter.hide()
	actor.hide()
	is_ready_to_draw = false
	is_finishing = false
	actor.speed_scale = 1.0

func _on_ui_requested(is_show: bool):
	if is_show:
		_reset_ui() # 先重置狀態
		filter.show()
		actor.show()
		actor.speed_scale = 4.0 # 補償 0.25x 慢動作
		actor.play("open")
	else:
		_reset_ui()

func _on_draw_confirmed():
	is_finishing = true
	is_ready_to_draw = false
	
	# 🟢 這裡回歸純粹：重置速度為 1.0，直接播放
	actor.speed_scale = 1.0
	actor.play("sword_fall")

func _on_animation_finished():
	if actor.animation == "open":
		actor.play("spell_idle")
		is_ready_to_draw = true
	
	# 🟢 大劍播完立刻消失，絕對不擋住後面的 MagicCircle
	elif actor.animation == "sword_fall":
		_reset_ui()
		SignalBus.seal_sword_fall_finished.emit()

func _on_draw_progress(progress: float):
	# 🟢 如果已經進入大劍演出 (is_finishing)，就不准再動 Frame
	if not is_ready_to_draw or is_finishing or not actor.visible: return
	
	if progress > 0.01:
		if actor.animation != "spell":
			actor.play("spell")
			actor.speed_scale = 1.0
		
		var frames = actor.sprite_frames.get_frame_count("spell")
		actor.frame = int(progress * (frames - 1))
		actor.pause()
	else:
		if actor.animation != "spell_idle":
			actor.play("spell_idle")
			actor.speed_scale = 4.0
