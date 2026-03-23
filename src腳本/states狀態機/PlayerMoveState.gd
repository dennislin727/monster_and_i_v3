# res://src腳本/states狀態機/PlayerMoveState.gd
extends Node
var player: PlayerController

func enter(): pass
func exit(): pass
func _process(_delta: float):
	if not player or player.is_hit_stun: return
	
	player.update_flip()
	var dir_str = player.get_dir_string()
	
	# 🔴 協議 v2.1：判斷目前是否在封印按壓期
	if player.is_seal_mode:
		# 封印期間：鎖定封印動畫，但 velocity 由繼承的物理邏輯處理
		var seal_anim = "seal_" + dir_str
		if player.anim_sprite.animation != seal_anim:
			player.anim_sprite.play(seal_anim)
	else:
		# 正常期間：撥放跑步或待機
		var prefix = "run_" if player.velocity.length() > 10 else "idle_"
		var anim_name = prefix + dir_str
		if player.anim_sprite.animation != anim_name:
			player.anim_sprite.play(anim_name)
