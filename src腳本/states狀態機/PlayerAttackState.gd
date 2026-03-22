# res://src腳本/states狀態機/PlayerAttackState.gd
extends Node
var player: PlayerController
var combo_index: int = 1
var is_swinging: bool = false
var has_hit_this_swing: bool = false # 🔴 防止重複傷害

func enter():
	start_attack_sequence()

func exit():
	is_swinging = false

func start_attack_sequence():
	if is_swinging: return
	is_swinging = true
	has_hit_this_swing = false # 重置傷害標記
	
	var dir = player.get_dir_string()
	var anim_name = "attack_%s_%d" % [dir, combo_index]
	
	if not player.anim_sprite.sprite_frames.has_animation(anim_name):
		combo_index = 1
		anim_name = "attack_%s_1" % dir
	
	print("[PlayerAttack] 執行：%s" % anim_name)
	player.update_flip()
	player.anim_sprite.play(anim_name)
	
	# 🔴 核心修復：自動傷害保險絲 (揮刀 0.15 秒後自動觸發)
	# 這樣就算你動畫裡沒加 Method Track，也會有傷害判定
	get_tree().create_timer(0.15).timeout.connect(func():
		if is_swinging and not has_hit_this_swing:
			trigger_damage_safe()
	)
	
	await player.anim_sprite.animation_finished
	
	# 喘息
	player.anim_sprite.play("idle_" + dir)
	await get_tree().create_timer(0.2).timeout 
	
	is_swinging = false
	if player.current_enemy or player.current_target:
		combo_index = (combo_index % 5) + 1
		start_attack_sequence()

# 🔴 供腳本自動呼叫或動畫軌道呼叫
func trigger_damage_safe():
	if has_hit_this_swing: return
	has_hit_this_swing = true
	
	# 呼叫 Controller 裡的判定邏輯
	if player.has_method("hit_current_target"):
		player.hit_current_target()
