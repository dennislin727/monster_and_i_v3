# res://src腳本/states狀態機/PlayerAttackState.gd
extends Node

var player: PlayerController
var combo_index: int = 1
var is_swinging: bool = false # 揮刀 + 喘息的總鎖定時間

# 🔴 調整這裡來對齊石頭的震動速度
@export var recovery_time: float = 0.4 # 攻擊完後的「喘息/僵直」時間

func enter() -> void:
	is_swinging = false
	start_attack_sequence()

func exit() -> void:
	is_swinging = false

func _process(_delta: float) -> void:
	# 此狀態下不由 _process 主動觸發，由 start_attack_sequence 的循環控制
	pass

func start_attack_sequence() -> void:
	if is_swinging: return
	is_swinging = true
	
	# 1. 決定方向與動畫
	var dir = player.get_dir_string()
	var anim_name = "attack_%s_%d" % [dir, combo_index]
	
	if not player.anim_sprite.sprite_frames.has_animation(anim_name):
		combo_index = 1
		anim_name = "attack_%s_1" % dir
	
	# 2. 播放攻擊動畫
	player.update_flip()
	player.anim_sprite.play(anim_name)
	
	# 🔴 核心調整：同步傷害觸發
	# 假設 8 影格的動畫中，第 3-4 幀是砍下去的瞬間
	# 我們用計時器精確控制傷害爆發點，對齊石頭的震動
	await get_tree().create_timer(0.12).timeout # 這裡的數值可微調
	trigger_damage_logic()
	
	# 3. 等待劈砍動畫播完
	await player.anim_sprite.animation_finished
	
	# 4. 🔴 進入「喘息/待機」階段
	var idle_anim = "idle_" + player.get_dir_string()
	player.anim_sprite.play(idle_anim)
	
	# 在這裡停頓一段時間，讓玩家「收招」
	await get_tree().create_timer(recovery_time).timeout
	
	is_swinging = false
	
	# 5. 判斷是否要繼續下一擊 (如果有目標且沒移動逃跑)
	if player.current_enemy or player.current_target:
		combo_index = (combo_index % 5) + 1
		start_attack_sequence()
	else:
		# 沒目標了，is_swinging = false 會讓狀態機在下一幀把我們切回 Move
		combo_index = 1

func trigger_damage_logic() -> void:
	# 觸發採集
	if player.current_target:
		player.current_target.start_harvest()
	
	# 觸發假人傷害
	if player.current_enemy and player.current_enemy.has_method("take_damage"):
		player.current_enemy.take_damage(10)
