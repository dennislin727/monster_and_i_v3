# res://src腳本/states狀態機/PlayerAttackState.gd
extends Node

var player: PlayerController
var combo_index: int = 1
var is_swinging: bool = false      # 🔴 只控制「動畫鎖定」，決定能不能移動
var is_cooling_down: bool = false  # 🔴 控制「攻速冷卻」，決定能不能出下一刀

@export var recovery_time: float = 0.4 # 這裡設定你的攻速（秒）

func enter() -> void:
	# 🔴 核心修復：進入的一瞬間就設為 true，不要等下一幀
	is_swinging = true
	is_cooling_down = true 
	_execute_combo()

func exit() -> void:
	is_swinging = false
	is_cooling_down = false
	combo_index = 1

func _process(_delta: float) -> void:
	if not player: return
	
	# 只有在「沒在揮刀」且「冷卻結束」時，才准自動下一刀
	if not is_swinging and not is_cooling_down:
		var target_valid = false
		
		# 檢查怪物的有效性 (新增判斷)
		if is_instance_valid(player.current_enemy):
			var monster = player.current_enemy.get_parent()
			if monster.has_method("is_targetable") and monster.is_targetable():
				target_valid = true
			else:
				player.current_enemy = null # 目標已死，清除引用
		
		# 檢查採集物的有效性
		elif is_instance_valid(player.current_target):
			target_valid = true
		
		# 如果目標有效，才執行連段
		if target_valid:
			_execute_combo()
		else:
			# 若無有效目標，且沒在揮刀，則考慮回到移動狀態
			pass

func _execute_combo() -> void:
	is_swinging = true
	is_cooling_down = true # 開始攻擊的同時，也進入冷卻鎖定
	
	var dir = player.get_dir_string()
	var anim_name = "attack_%s_%d" % [dir, combo_index]
	
	if not player.anim_sprite.sprite_frames.has_animation(anim_name):
		combo_index = 1
		anim_name = "attack_%s_1" % dir
	
	player.update_flip()
	player.anim_sprite.play(anim_name)
	
	# 傷害判定
	get_tree().create_timer(0.15).timeout.connect(func():
		if is_swinging: player.hit_current_target()
	)
	
	# 等待動畫播完
	if player.anim_sprite.is_playing():
		await player.anim_sprite.animation_finished
	
	# 🔴 動畫一結束，立刻解除移動鎖定！
	is_swinging = false 
	
	# 播放 idle 喘息，並等待冷卻時間
	player.anim_sprite.play("idle_" + dir)
	await get_tree().create_timer(recovery_time).timeout
	
	# 🔴 冷卻時間到，解除冷卻鎖，準備下一刀
	is_cooling_down = false
	combo_index = (combo_index % 3) + 1
