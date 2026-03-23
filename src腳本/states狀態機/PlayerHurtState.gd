# res://src腳本/states狀態機/PlayerHurtState.gd
extends Node

var player: PlayerController

func enter():
	# 播放受擊
	player.anim_sprite.stop()
	player.anim_sprite.play("hit")
	player.anim_sprite.modulate = Color.RED
	
	# 0.05秒後恢復顏色
	await get_tree().create_timer(0.05).timeout
	var t = create_tween()
	t.tween_property(player.anim_sprite, "modulate", Color.WHITE, 0.1)
	
	# 動畫鎖定時間
	await get_tree().create_timer(0.3).timeout
	
	# 🔴 結束後手動切換回 Move 狀態
	if player.is_hit_stun:
		player.is_hit_stun = false
		player.state_machine.change_state(get_node("../Move"))

# 🔴 補上 exit 函數，防止舊版狀態機報錯
func exit():
	pass
