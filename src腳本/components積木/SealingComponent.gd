# res://src腳本/components積木/SealingComponent.gd
extends Node2D

@export var base_seal_time: float = 2.5 # 壓制所需秒數
var current_progress: float = 0.0
var is_active: bool = false
var struggle_tween: Tween

@onready var monster = get_parent()
@onready var health = monster.get_node("HealthComponent")
# 假設怪物場景中有一個名為 MagicCircle 的 AnimatedSprite2D
@onready var magic_circle = monster.get_node_or_null("MagicCircle") 

func start_struggle():
	is_active = true
	current_progress = 0.0
	if magic_circle:
		magic_circle.show()
		magic_circle.play("idle") # 法陣預設循環

func _process(delta: float):
	if not is_active: return
	
	var manager = get_tree().get_first_node_in_group("seal_manager")
	var player = get_tree().get_first_node_in_group("player")
	
	# 懲罰判定：移動中或被擊中
	var is_moving = player.velocity.length() > 60
	var is_hit = player.get("is_hit_stun") == true
	
	if manager.is_pressing_target and not (is_moving or is_hit):
		# 正常封印：進度累積 + 播放真實主角的 seal_方向 動畫
		current_progress += delta
		var dir = player.get_dir_string()
		player.anim_sprite.play("seal_" + dir)
		
		play_struggle_fx()
		
		if current_progress >= base_seal_time:
			is_active = false
			check_result()
	else:
		# 處罰：進度衰減
		current_progress = max(0, current_progress - delta * 0.7)
		stop_struggle_fx()
		
		# 主角若沒被按壓則恢復 idle
		if player.get("is_seal_mode") == true and not is_hit:
			player.anim_sprite.play("idle_" + player.get_dir_string())

func play_struggle_fx():
	# 怪物掙扎：隨機播 hit 幀並微幅縮放
	monster.anim.play("hit")
	if struggle_tween == null or not struggle_tween.is_running():
		struggle_tween = monster.create_tween().set_loops()
		struggle_tween.tween_property(monster.anim, "scale", Vector2(1.1, 0.9), 0.1)
		struggle_tween.tween_property(monster.anim, "scale", Vector2(0.95, 1.05), 0.1)

func stop_struggle_fx():
	if struggle_tween: struggle_tween.kill()
	monster.anim.scale = Vector2.ONE

func check_result():
	stop_struggle_fx()
	
	# 計算成功率：Base 50% + 血量損失加成
	var hp_pct = float(health.current_hp) / health.max_hp
	var success_rate = 0.5 * (1.0 + (1.0 - hp_pct)) 
	
	var is_success = randf() <= success_rate
	
	# 法陣結算動畫
	if magic_circle:
		magic_circle.play("success" if is_success else "broke")
	
	# 通知 Manager 觸發真實主角的結算演繹
	var manager = get_tree().get_first_node_in_group("seal_manager")
	manager.resolve_sealing(is_success)
	
	if is_success:
		_execute_capture_fx()
	else:
		_execute_fail_fx()

func _execute_capture_fx():
	# 怪物被吸入效果：縮小旋轉
	var t = create_tween().set_parallel(true)
	t.tween_property(monster, "scale", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(monster, "rotation", deg_to_rad(360), 0.6)
	await t.finished
	monster.queue_free()

func _execute_fail_fx():
	# 封印失敗：法陣消失，怪物恢復戰鬥
	is_active = false
	await get_tree().create_timer(1.0).timeout
	if magic_circle: magic_circle.hide()
