# res://src腳本/states狀態機/PlayerAttackState.gd
extends Node

var player: PlayerController
var combo_index: int = 1
var is_swinging: bool = false # 揮刀中鎖定

func enter() -> void:
	is_swinging = false
	start_attack()

func exit() -> void:
	is_swinging = false

func _process(_delta: float) -> void:
	if not player: return
	
	# 如果揮完了，但目標還在，自動進入下一段連招
	if not is_swinging:
		if player.current_enemy or player.current_target:
			start_attack()
		else:
			pass # 🔴 這裡加了 pass，就不會報錯了

func start_attack() -> void:
	if is_swinging: return
	is_swinging = true
	
	var dir = player.get_dir_string()
	var anim_name = "attack_%s_%d" % [dir, combo_index]
	
	# 檢查動畫是否存在，不存在則重置連招
	if not player.anim_sprite.sprite_frames.has_animation(anim_name):
		combo_index = 1
		anim_name = "attack_%s_1" % dir
	
	player.update_flip()
	player.anim_sprite.play(anim_name)
	
	# --- 觸發採集邏輯 ---
	if player.current_target:
		# 為了打擊感，延遲 0.1 秒（模擬刀揮下去的時間）再觸發採集
		await get_tree().create_timer(0.1).timeout
		if player.current_target: # 再次確認目標還在
			player.current_target.start_harvest()
	
	# --- 觸發傷害邏輯 (假人) ---
	if player.current_enemy:
		await get_tree().create_timer(0.1).timeout
		if player.current_enemy and player.current_enemy.has_method("take_damage"):
			player.current_enemy.take_damage(10)
	
	# 等待動畫播完
	await player.anim_sprite.animation_finished
	
	is_swinging = false
	combo_index = (combo_index % 5) + 1 # 1-5 循環
