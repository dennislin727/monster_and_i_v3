# res://src腳本/states狀態機/PlayerMoveState.gd
extends Node
var player: PlayerController

func enter(): pass
func exit(): pass
func _process(_delta: float):
	if not player or player.is_hit_stun: return
	
	# 🟢 第一優先：無論什麼狀態，只要有移動輸入就翻轉
	player.update_flip()
	
	# 🟢 第二優先：演繹保護
	if player.anim_sprite.animation in ["happy", "sad"]:
		if player.anim_sprite.is_playing(): return 

	# 衝刺期間 velocity 被清空，MoveState 會誤判 idle；每幀鎖回 dash_（含斜向／降級）
	if player.is_dashing:
		player.apply_dash_body_animation()
		return

	# 手動寵物地面技鬆手：維持 seal_ 至計時結束，勿每幀改回 run/idle
	if player._pet_command_pose_left > 0.0:
		player.update_flip()
		return

	# 🟢 第三優先：封印動畫分流
	var manager = get_tree().get_first_node_in_group("seal_manager")
	var is_pressing = manager.is_pressing_target if manager else false

	if player.is_seal_mode and is_pressing:
		# 只有在「真正按壓怪物」時才播 seal（無斜向資源時自動降級四向／裸名）
		var seal_anim := player.resolve_directional_animation_name("seal_", player.last_direction)
		if player.anim_sprite.animation != seal_anim:
			player.anim_sprite.play(seal_anim)
	else:
		# 🔴 核心修復：只要「沒在揮刀」，就交給 MoveState 處理 run/idle
		# 這樣即便是在封印模式中砍石頭，砍完也會立刻回歸正常 run 動畫
		if not player.anim_sprite.animation.contains("attack"):
			var prefix := "run_" if player.velocity.length() > 10 else "idle_"
			var body_anim := player.resolve_directional_animation_name(prefix, player.last_direction)
			if player.anim_sprite.animation != body_anim:
				player.anim_sprite.play(body_anim)
