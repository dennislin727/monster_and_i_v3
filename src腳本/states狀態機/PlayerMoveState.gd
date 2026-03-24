# res://src腳本/states狀態機/PlayerMoveState.gd
extends Node
var player: PlayerController

func enter(): pass
func exit(): pass
func _process(_delta: float):
	if not player or player.is_hit_stun: return
	
	# 🟢 第一優先：無論什麼狀態，只要有移動輸入就翻轉
	player.update_flip()
	var dir_str = player.get_dir_string()
	
	# 🟢 第二優先：演繹保護
	if player.anim_sprite.animation in ["happy", "sad"]:
		if player.anim_sprite.is_playing(): return 

	# 🟢 第三優先：封印動畫分流
	var manager = get_tree().get_first_node_in_group("seal_manager")
	var is_pressing = manager.is_pressing_target if manager else false

	if player.is_seal_mode and is_pressing:
		# 只有在「真正按壓怪物」時才播 seal
		var seal_anim = "seal_" + dir_str
		if player.anim_sprite.animation != seal_anim:
			player.anim_sprite.play(seal_anim)
	else:
		# 🔴 核心修復：只要「沒在揮刀」，就交給 MoveState 處理 run/idle
		# 這樣即便是在封印模式中砍石頭，砍完也會立刻回歸正常 run 動畫
		if not player.anim_sprite.animation.contains("attack"):
			var prefix = "run_" if player.velocity.length() > 10 else "idle_"
			player.anim_sprite.play(prefix + dir_str)
