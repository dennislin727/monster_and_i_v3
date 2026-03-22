# res://src腳本/states狀態機/PlayerAttackState.gd
extends Node

var player: PlayerController
var combo_index: int = 1
var is_swinging: bool = false # 🔴 代表「正在揮刀動畫中」

func enter():
	# 進入狀態立刻揮第一刀
	_execute_combo()

func _process(_delta: float):
	if not player: return
	
	# 🔴 核心邏輯：如果刀揮完了，但目標還在，就自動接下一刀
	if not is_swinging:
		if player.current_enemy or player.current_target:
			_execute_combo()
		else:
			# 如果沒目標了，is_swinging 為 false 會讓狀態機切回 Move
			pass

func _execute_combo():
	if is_swinging: return
	is_swinging = true
	
	# 1. 執行踏步位移
	player.perform_attack_lunge()
	
	# 2. 播放動畫
	player.anim_sprite.play("attack_" + player.get_dir_string() + "_" + str(combo_index))
	
	# 3. 傷害判定
	get_tree().create_timer(0.15).timeout.connect(func(): player.hit_current_target())
	
	await player.anim_sprite.animation_finished
	
	# 🔴 增加收刀後搖：強制喘息 0.3 秒，不能立刻接下一招
	player.anim_sprite.play("idle_" + player.get_dir_string())
	await get_tree().create_timer(0.3).timeout
	
	is_swinging = false
	combo_index = (combo_index % 5) + 1

func exit():
	is_swinging = false
	combo_index = 1
