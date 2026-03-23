# res://src腳本/components積木/SealingComponent.gd
extends Node2D

@export_group("封印參數")
@export var base_seal_time: float = 2.5     # 壓制所需秒數 (長壓多久會滿)
@export var decay_rate: float = 0.7         # 沒按壓或移動時的進度倒退速度

var current_progress: float = 0.0
var is_active: bool = false
var struggle_tween: Tween

@onready var monster: MonsterBase = get_parent()
@onready var health: HealthComponent = monster.get_node("HealthComponent")
@onready var magic_circle: AnimatedSprite2D = get_parent().get_node_or_null("MagicCircle") 

func _ready() -> void:
	# 初始確保法陣隱藏
	if magic_circle:
		magic_circle.hide()
		magic_circle.z_index = -1 # 確保在怪身後/下方

func start_struggle():
	is_active = true
	current_progress = 0.0
	print("[Sealing] 開始按壓期，目標怪物: ", monster.name)
	
	if magic_circle:
		magic_circle.show()
		magic_circle.play("idle")
		magic_circle.modulate.a = 0
		create_tween().tween_property(magic_circle, "modulate:a", 1.0, 0.3)
	else:
		# 🔴 如果沒法陣，噴一個警告但讓邏輯繼續跑，不然你會卡死
		push_warning("警告：怪物 " + monster.name + " 身上找不到 MagicCircle 節點！")

func _process(delta: float):
	if not is_active: return
	
	var manager = get_tree().get_first_node_in_group("seal_manager")
	var player = get_tree().get_first_node_in_group("player")
	
	if not manager or not player: return

	# --- 懲罰判定規範 ---
	# 1. 移動中 (走太快會導致分心，封印不穩)
	var is_moving = player.velocity.length() > 60
	# 2. 受擊硬直中 (被其他怪打到)
	var is_hit = player.get("is_hit_stun") == true
	
	# --- 邏輯判定 ---
	if manager.is_pressing_target and not (is_moving or is_hit):
		# [成功壓制中]
		current_progress += delta
		
		# 同步主角封印動畫 (世界演員模式)
		var dir = player.get_dir_string()
		if player.anim_sprite.animation != "seal_" + dir:
			player.anim_sprite.play("seal_" + dir)
		
		play_struggle_fx()
		
		# 檢查是否讀條完成
		if current_progress >= base_seal_time:
			is_active = false
			check_result()
	else:
		# [壓制中斷：處罰倒退]
		current_progress = max(0, current_progress - delta * decay_rate)
		stop_struggle_fx()
		
		# 主角若因為移動或中斷按壓，恢復正常動畫
		if player.get("is_seal_mode") == true and not is_hit:
			var dir = player.get_dir_string()
			var prefix = "run_" if is_moving else "idle_"
			player.anim_sprite.play(prefix + dir)

# --- 視覺演出區 ---

func play_struggle_fx():
	# 怪物掙扎：播放受擊動畫並彈跳
	if monster.anim.animation != "hit":
		monster.anim.play("hit")
	
	if struggle_tween == null or not struggle_tween.is_running():
		struggle_tween = create_tween().set_loops()
		# 快速抖動縮放感
		struggle_tween.tween_property(monster.anim, "scale", Vector2(1.15, 0.85), 0.08)
		struggle_tween.tween_property(monster.anim, "scale", Vector2(0.9, 1.1), 0.08)

func stop_struggle_fx():
	if struggle_tween: 
		struggle_tween.kill()
		struggle_tween = null
	# 緩慢恢復原始大小
	var t = create_tween()
	t.tween_property(monster.anim, "scale", Vector2.ONE, 0.2)

# --- 結算區 ---

func check_result():
	stop_struggle_fx()
	
	# 成功率公式：SuccessRate = BaseRate(50%) * (1.0 + (1.0 - HP_Percentage))
	# 如果怪物剩 10% 血，機率 = 0.5 * (1 + 0.9) = 95% 
	var hp_pct = float(health.current_hp) / health.max_hp
	var success_rate = 0.5 * (1.0 + (1.0 - hp_pct)) 
	
	var is_success = randf() <= success_rate
	
	# 1. 播放法陣結算動畫
	if magic_circle:
		if is_success:
			magic_circle.play("success")
		else:
			magic_circle.play("broke")
	
	# 2. 通知 SealManager 執行主角結算 (跳字 Got you/Fail 與 開心/難過動畫)
	var manager = get_tree().get_first_node_in_group("seal_manager")
	if manager:
		manager.resolve_sealing(is_success)
	
	# 3. 實體處理
	if is_success:
		_execute_capture_fx()
	else:
		_execute_fail_fx()

func _execute_capture_fx():
	# 封印成功：怪物縮小旋轉消失
	# 關閉碰撞避免干擾
	monster.set_collision_layer_value(2, false)
	monster.set_collision_mask_value(1, false)
	
	var t = create_tween().set_parallel(true)
	# 核心演繹：吸入法陣感
	t.tween_property(monster, "scale", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(monster, "rotation", deg_to_rad(720), 0.6)
	t.tween_property(monster, "modulate:a", 0.0, 0.5)
	
	await t.finished
	monster.queue_free()

func _execute_fail_fx():
	# 封印失敗：法陣破碎，怪物恢復自由
	is_active = false
	await get_tree().create_timer(1.0).timeout
	if magic_circle: 
		var t = create_tween()
		t.tween_property(magic_circle, "modulate:a", 0.0, 0.3)
		await t.finished
		magic_circle.hide()
