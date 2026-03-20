# res://src腳本/components積木/SealingComponent.gd
extends Node2D

@export var seal_difficulty: float = 2.0 # 封印需要按壓的秒數
var current_progress: float = 0.0

func _process(delta: float):
	var manager = get_tree().get_first_node_in_group("seal_manager")
	if manager and manager.target_monster == get_parent() and manager.is_pressing_target:
		# 🔴 玩家正在按壓，進度增加
		current_progress += delta
		update_ui_progress()
		
		if current_progress >= seal_difficulty:
			complete_seal()
	else:
		# 沒按壓，進度緩慢倒退
		current_progress = max(0, current_progress - delta * 0.5)

func update_ui_progress():
	# 顯示怪物頭上的縮收效果或法陣變化
	pass

func complete_seal():
	# 封印成功！
	SignalBus.seal_attempt_finished.emit(true, get_parent().data)
	get_parent().queue_free()
