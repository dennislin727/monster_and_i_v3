# res://src腳本/states狀態機/PlayerAttackState.gd
extends Node

# --- 1. 引用與變數 ---
var player: PlayerController
var combo_index: int = 1
var is_swinging: bool = false      # 🔴 動畫鎖定：揮刀中
var has_hit_this_swing: bool = false # 🔴 傷害鎖定：防止單次揮刀重複傷害

# 調整攻擊間的「喘息時間」
@export var recovery_time: float = 0.2 

# --- 2. 狀態切換接口 ---

func enter() -> void:
	is_swinging = false
	_execute_combo()

func exit() -> void:
	is_swinging = false
	combo_index = 1 # 離開戰鬥範圍後重置連招
	print("[AttackState] 停止戰鬥，重置連招")

func _process(_delta: float) -> void:
	if not player: return
	
	# 🔴 核心自動化：如果揮完一刀，且目標還在，就自動啟動下一段
	if not is_swinging:
		if player.current_enemy or player.current_target:
			_execute_combo()
		else:
			# 如果沒目標了，is_swinging 為 false 會讓狀態機在下一影格切換回 Move
			pass

# --- 3. 核心戰鬥邏輯 ---

func _execute_combo() -> void:
	if is_swinging: return
	is_swinging = true
	has_hit_this_swing = false
	
	# A. 決定動畫名稱
	var dir = player.get_dir_string()
	var anim_name = "attack_%s_%d" % [dir, combo_index]
	
	# B. 動畫存在檢查 (如果畫了 3 段，第 4 段會自動跳回第 1 段)
	if not player.anim_sprite.sprite_frames.has_animation(anim_name):
		combo_index = 1
		anim_name = "attack_%s_1" % dir
	
	# C. 執行視覺表現
	player.update_flip()
	player.anim_sprite.play(anim_name)
	# print("[AttackState] 執行連招: ", anim_name)
	
	# D. 🔴 自動傷害判定 (保險絲)
	# 即使動畫沒加標籤，0.15 秒後也會自動判定一次傷害
	get_tree().create_timer(0.15).timeout.connect(func():
		if is_swinging and not has_hit_this_swing:
			_trigger_damage()
	)
	
	# E. 等待動畫播完
	if player.anim_sprite.is_playing():
		await player.anim_sprite.animation_finished
	
	# F. 🔴 增加「收刀喘息」：讓攻擊不要像電風扇一樣快
	# 播放對應方向的 idle 動畫
	player.anim_sprite.play("idle_" + dir)
	await get_tree().create_timer(recovery_time).timeout
	
	# G. 解鎖，準備下一段
	is_swinging = false
	combo_index = (combo_index % 5) + 1

# 🔴 統一傷害觸發點
func _trigger_damage() -> void:
	if has_hit_this_swing: return
	has_hit_this_swing = true
	
	# 呼叫 Controller 裡的判定邏輯
	if player.has_method("hit_current_target"):
		player.hit_current_target()

# --- 4. 動畫影格回傳 (選配) ---
# 如果你在動畫裡有加 Method Track 呼叫此函數，會比保險絲更精準
func hit_event() -> void:
	_trigger_damage()
