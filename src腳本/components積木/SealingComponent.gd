# res://src腳本/components積木/SealingComponent.gd
extends Node2D

@export_group("封印參數")
@export var base_seal_time: float = 2.5     # 壓制所需秒數
@export var decay_rate: float = 0.7         # 沒按壓時的進度倒退速度
@export var max_seal_dist: float = 400.0   # 玩家走太遠的失敗距離
@export var idle_max_time: float = 5.0     # 🔴 玩家「圈而不壓」的最大忍受秒數

var current_progress: float = 0.0
var current_idle_timer: float = 0.0         # 🔴 閒置計時器
var is_active: bool = false
var struggle_time: float = 0.0              # 用於計算收縮波形時間軸
var hint_label: Label = null

@onready var monster: MonsterBase = get_parent()
@onready var health: HealthComponent = monster.get_node("HealthComponent")
@onready var magic_circle: AnimatedSprite2D = get_parent().get_node_or_null("MagicCircle") 

func _ready() -> void:
	# 🔴 同步上帝撥盤的數值
	if GlobalBalance:
		base_seal_time = GlobalBalance.SEAL_BASE_TIME
		decay_rate = GlobalBalance.SEAL_DECAY_RATE
	
	if magic_circle:
		magic_circle.hide()
		magic_circle.z_index = -1
	
	# 🟢 核心修正：監聽按鈕重置信號，處理手動取消時的文字殘留
	SignalBus.seal_button_reset_requested.connect(_on_button_canceled)

# --- 階段 B：啟動壓制 ---

func start_struggle():
	is_active = true
	current_progress = 0.0
	struggle_time = 0.0
	current_idle_timer = idle_max_time
	
	monster.velocity = Vector2.ZERO
	monster.set_physics_process(false) 

	if magic_circle:
		magic_circle.show()
		magic_circle.play("idle")
		magic_circle.modulate.a = 0
		magic_circle.scale = Vector2(0.1, 0.1) # 🟢 1. 初始縮得很小，準備彈跳
		
		# 🔴 移除原本的 set_parallel(true)，改用預設的「排隊模式」
		var t = create_tween()
		
		# 2. 優雅綻放：0.1 放大到 2.0 (耗時 0.5 秒)
		# 使用 .set_trans(Tween.TRANS_SINE) 讓它看起來很滑順
		t.tween_property(magic_circle, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# 💡 用 .parallel() 讓「透明度」跟著上面的放大動作同時跑，不影響排隊
		t.parallel().tween_property(magic_circle, "modulate:a", 1.0, 0.2)
		
		# 因為沒加 parallel，這行會等上面放大的 0.5 秒跑完才開始
		t.tween_property(magic_circle, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# 🟢 3. 關鍵：等上面的動畫演完，再噴出提示文字
		t.set_parallel(false) # 關閉並行模式
		t.tween_callback(func(): 
			SignalBus.popup_text.emit(monster, "長壓幫助封印!!", Color.WHITE)
		)


	if magic_circle:
		magic_circle.show()
		magic_circle.play("idle")
		magic_circle.modulate.a = 0
		var t = create_tween()
		t.tween_property(magic_circle, "modulate:a", 1.0, 0.3)

func _process(delta: float):
	if not is_active: return
	
	var manager = get_tree().get_first_node_in_group("seal_manager")
	var player = get_tree().get_first_node_in_group("player")
	if not manager or not player: return

	# [判定1] 距離檢測
	var dist = monster.global_position.distance_to(player.global_position)
	if dist > max_seal_dist:
		_on_fail_exit() 
		return

	# [判定2] 玩家狀態
	var is_moving = player.velocity.length() > 120
	var is_hit = player.get("is_hit_stun") == true
	
	# 🔴 [判定3] 閒置超時邏輯
	if not manager.is_pressing_target:
		current_idle_timer -= delta
		if current_idle_timer <= 0:
			print("[Sealing] 玩家太久沒按壓，法陣破碎！")
			_on_fail_exit()
			return
	else:
		# 只要玩家一按壓，就重置計時器
		current_idle_timer = idle_max_time

	# --- 邏輯演算區 ---
	
	if manager.is_pressing_target and not (is_moving or is_hit):
		# [成功壓制中]
		var seal_speed_mult = 1.0
		var hp_pct = float(health.current_hp) / health.max_hp
		
		if hp_pct <= GlobalBalance.SEAL_WEAK_THRESHOLD:
			seal_speed_mult = GlobalBalance.SEAL_WEAK_SPEED_BONUS
		
		current_progress += delta * seal_speed_mult
		struggle_time += delta
		
		# 視覺 1：靈魂轉換
		var alpha = clamp(1.0 - (current_progress / base_seal_time) * 0.6, 0.4, 1.0)
		monster.anim.modulate.a = alpha
		
		# 視覺 2：動態收縮
		_apply_dynamic_struggle(delta)
		
		# 🏁 檢查是否封印完成
		if current_progress >= base_seal_time:
			is_active = false 
			check_result()
	else:
		# [🔴 停止壓制]
		current_progress = max(0, current_progress - delta * decay_rate)
		struggle_time += delta * 0.5 
		
		monster.anim.modulate.a = lerp(monster.anim.modulate.a, 1.0, delta * 2.0)
		monster.anim.scale = monster.anim.scale.move_toward(Vector2.ONE, delta * 2.0)
		
		if monster.anim.animation == "hit_down":
			if monster.anim.sprite_frames.has_animation("run_down"):
				monster.anim.play("run_down")
			else:
				monster.anim.play("idle_down")

func _apply_dynamic_struggle(_delta):
	if monster.anim.sprite_frames.has_animation("hit_down"):
		if monster.anim.animation != "hit_down":
			monster.anim.play("hit_down")
	
	var progress_pct = current_progress / base_seal_time
	var freq = lerp(8.0, 20.0, progress_pct) 
	var amp = lerp(0.12, 0.05, progress_pct) 
	var base_scale = lerp(1.0, 0.4, progress_pct)
	
	var s = base_scale + sin(struggle_time * freq) * amp
	monster.anim.scale = Vector2(s, s)

# --- 階段 C：結算演繹 ---

func check_result():
	# 🟢 結算開始，文字消失
	if is_instance_valid(hint_label):
		hint_label.dismiss()
		hint_label = null
		
	var hp_pct = float(health.current_hp) / health.max_hp
	var success_rate = monster.data.capture_rate * (1.0 + (1.0 - hp_pct))
	var is_success = randf() <= success_rate
	
	if magic_circle:
		magic_circle.play("success" if is_success else "broke")
	
	var manager = get_tree().get_first_node_in_group("seal_manager")
	if manager: manager.resolve_sealing(is_success)
	
	if is_success:
		_execute_capture_fx()
	else:
		_execute_fail_fx()

func _execute_capture_fx():
	monster.set_collision_layer_value(2, false)
	monster.set_collision_mask_value(1, false)
	
	var t = create_tween().set_parallel(true)
	t.tween_property(monster.anim, "scale", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(monster.anim, "rotation", deg_to_rad(720), 0.6)
	t.tween_property(monster.anim, "modulate:a", 0.0, 0.5)
	
	await t.finished
	monster.queue_free()

func _execute_fail_fx():
	is_active = false 
	
	var burst_t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst_t.tween_property(monster.anim, "scale", Vector2(1.5, 1.5), 0.15) 
	burst_t.tween_property(monster.anim, "modulate:a", 1.0, 0.1)          
	monster.anim.modulate = Color(2.5, 2.5, 2.5) 
	
	burst_t.chain().set_parallel(true).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	burst_t.tween_property(monster.anim, "scale", Vector2.ONE, 0.5)
	burst_t.tween_property(monster.anim, "modulate", Color.WHITE, 0.3)
	
	if monster.anim.sprite_frames.has_animation("attack_down"):
		monster.anim.play("attack_down")
	
	if magic_circle:
		create_tween().tween_property(magic_circle, "modulate:a", 0.0, 0.4).set_delay(0.2)
	
	await get_tree().create_timer(0.2).timeout
	_restore_ai_control()

func _restore_ai_control():
	monster.set_physics_process(true)
	if monster.has_node("StateMachine"):
		var sm = monster.get_node("StateMachine")
		sm.set_physics_process(true)
		if sm.has_method("change_to"):
			sm.change_to("Chase")

func _on_fail_exit():
	is_active = false
	# 🟢 異常中斷，文字消失
	if is_instance_valid(hint_label):
		hint_label.dismiss()
		hint_label = null
	
	if magic_circle: magic_circle.play("broke")
	var manager = get_tree().get_first_node_in_group("seal_manager")
	if manager: manager.resolve_sealing(false)
	_execute_fail_fx()

# 🟢 新增：聽電台，處理手動取消封印時的 UI 清理
func _on_button_canceled():
	if is_active:
		if is_instance_valid(hint_label):
			hint_label.dismiss()
			hint_label = null
