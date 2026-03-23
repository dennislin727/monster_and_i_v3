# res://src腳本/states狀態機/PlayerMoveState.gd
extends Node
var player: PlayerController

func enter(): pass
func exit(): pass
func _process(_delta: float):
	if not player or player.is_hit_stun: return
	
	# 🔴 核心修復：封印模式下，我們「只跳過動畫播放」，但不跳過「移動讀取」
	# 這樣玩家才能邊壓怪物邊走路
	var can_play_move_anim = (player.get("is_seal_mode") == false)

	var prefix = "run_" if player.velocity.length() > 10 else "idle_"
	var anim_name = prefix + player.get_dir_string()
	
	player.update_flip()
	
	# 只有非封印模式才更新動畫，避免搶走 seal_ 方向動畫
	if can_play_move_anim:
		if player.anim_sprite.animation != anim_name:
			player.anim_sprite.play(anim_name)
