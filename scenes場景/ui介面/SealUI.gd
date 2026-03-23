# res://src腳本/ui/SealUI.gd (單一演員協議重構版)
extends Control

@onready var filter: ColorRect = $Filter
@onready var actor: AnimatedSprite2D = $ActorPlayer

var is_ready_to_draw: bool = false # 只有開眼播完，才准進度條連動

func _ready() -> void:
	add_to_group("seal_ui")
	_reset_ui()
	SignalBus.seal_ui_requested.connect(_on_ui_requested)
	SignalBus.seal_draw_progress.connect(_on_draw_progress)
	
	# 🔴 核心：連接動畫結束信號
	if not actor.animation_finished.is_connected(_on_animation_finished):
		actor.animation_finished.connect(_on_animation_finished)

func _reset_ui():
	filter.hide()
	actor.hide()
	is_ready_to_draw = false

func _on_ui_requested(is_show: bool):
	if is_show:
		filter.show()
		actor.show()
		is_ready_to_draw = false
		
		# 1. 播放開眼動畫 (Eye Cut-In)
		actor.speed_scale = 4.0 # 補償 0.25 減速，讓它看起來是 1.0 倍速
		actor.play("open")
	else:
		_reset_ui()

func _on_animation_finished():
	# 2. 開眼播完後，自動轉入準備動作 (Spell Idle)
	if actor.animation == "open":
		actor.play("spell_idle")
		is_ready_to_draw = true # 開眼結束，可以開始畫線了

func _on_draw_progress(progress: float):
	if not is_ready_to_draw or not actor.visible: return
	
	# 3. 根據畫線進度，強制切換到 spell 動畫並撥幀
	if progress > 0.01:
		if actor.animation != "spell":
			actor.play("spell")
			actor.speed_scale = 1.0 # 畫線幀不需要快播
		
		var frames = actor.sprite_frames.get_frame_count("spell")
		actor.frame = int(progress * (frames - 1))
		actor.pause() # 手動撥幀，不自動播放
	else:
		# 4. 如果線被清空或還沒畫，維持 spell_idle
		if actor.animation != "spell_idle":
			actor.play("spell_idle")
			actor.speed_scale = 4.0
