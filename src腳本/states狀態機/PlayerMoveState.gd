# res://src腳本/states狀態機/PlayerMoveState.gd
extends Node # 👈 確保這裡是 Node

var player: PlayerController

func enter(): pass
func exit(): pass

func _process(_delta: float):
	if not player: return
	
	var prefix = "run_" if player.velocity.length() > 10 else "idle_"
	var anim_name = prefix + player.get_dir_string()
	
	player.update_flip()
	
	if player.anim_sprite.animation != anim_name:
		player.anim_sprite.play(anim_name)
