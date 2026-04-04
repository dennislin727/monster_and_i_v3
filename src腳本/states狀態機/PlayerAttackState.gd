# res://src腳本/states狀態機/PlayerAttackState.gd
extends Node

var player: PlayerController
var combo_index: int = 1
var is_swinging: bool = false
var is_cooling_down: bool = false
## exit() 時中止進行中的 _execute_combo，避免換狀態後仍結算普攻
var _strike_aborted: bool = false

# 🔴 1. 這裡把 @export 拿掉，變成一般變數
var recovery_time: float = 0.4 

# 🔴 2. 新增這個 _ready 函數（如果原本沒有的話）
func _ready() -> void:
	# 💡 這裡就是「接通電源」！
	# 讓 recovery_time 直接等於我們在 GlobalBalance 設好的數值
	if GlobalBalance:
		recovery_time = GlobalBalance.PLAYER_ATTACK_RECOVERY
	
	# 順便印出來確認一下，這對除錯很有幫助
	print("[系統] 攻擊冷卻已與上帝撥盤同步：", recovery_time)

func enter() -> void:
	# 🔴 這裡維持原樣，不需要改動
	is_swinging = true
	is_cooling_down = true 
	_execute_combo()

func exit() -> void:
	_strike_aborted = true
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
	_strike_aborted = false
	is_swinging = true
	is_cooling_down = true # 開始攻擊的同時，也進入冷卻鎖定
	
	var dir = player.get_dir_string()
	var anim_name = "attack_%s_%d" % [dir, combo_index]
	
	if not player.anim_sprite.sprite_frames.has_animation(anim_name):
		combo_index = 1
		anim_name = "attack_%s_1" % dir
	
	player.update_flip()
	player.anim_sprite.play(anim_name)
	# 揮刀瞬間鎖定目標，避免判定幀時已走出 InteractionDetector 導致主角與寵物都打空
	var strike_hurtbox: HurtboxComponent = player.current_enemy
	# 傷害判定：勿用 create_timer +「依賴 is_swinging」——若攻擊動畫比 0.15s 短，
	# animation_finished 會先跑並把 is_swinging 設 false，導致這一刀（與寵物協攻）永遠不結算。
	await get_tree().create_timer(0.15).timeout
	if not _strike_aborted and is_instance_valid(player):
		# 結算幀晚於揮刀：怪可能已死並釋放 Hurtbox；不可把已釋放參考傳進具型別參數（會在進入函式前報錯）
		var hb: HurtboxComponent = null
		if is_instance_valid(strike_hurtbox):
			hb = strike_hurtbox
		player.hit_current_target(hb)
	
	# 等待動畫播完
	if player.anim_sprite.is_playing():
		await player.anim_sprite.animation_finished
	
	# 🔴 動畫一結束，立刻解除移動鎖定！
	is_swinging = false 
	
	# 播放 idle 喘息，並等待冷卻時間（與 Move 相同：斜向 → 四向 → 裸名）
	player.anim_sprite.play(player.resolve_directional_animation_name("idle_", player.last_direction))
	await get_tree().create_timer(recovery_time).timeout
	
	# 🔴 冷卻時間到，解除冷卻鎖，準備下一刀
	is_cooling_down = false
	combo_index = (combo_index % 3) + 1
