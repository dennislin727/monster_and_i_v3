# res://src腳本/entities/PlayerController.gd
class_name PlayerController
extends CharacterBody2D

# --- 1. 導出參數 (可在編輯器微調) ---
@export_group("移動參數")
@export var move_speed: float = 200.0
@export var dash_distance: float = 150.0
@export var dash_duration: float = 0.4

@export_group("戰鬥手感")
@export var lunge_distance: float = 45.0   # 🔴 攻擊時向前踏步的距離
@export var invincible_time: float = 0.8    # 🔴 受傷後的無敵時間
@export var hit_stun_duration: float = 0.4 # 🔴 受擊動畫鎖定時間 (4幀/10FPS)

# --- 2. 節點引用 ---
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: Node = $StateMachine
@onready var health: HealthComponent = $HealthComponent
@onready var interaction_detector: Area2D = $InteractionDetector

# --- 3. 內部狀態標記 ---
var last_direction: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var is_seal_mode: bool = false
var is_hit_stun: bool = false   # 受擊動畫鎖
var is_invincible: bool = false # 無敵狀態鎖

# 目標鎖定
var current_target: InteractableComponent = null
var current_enemy: HurtboxComponent = null

# --- 4. 初始化 ---

func _ready() -> void:
	# 連結電台
	if SignalBus.has_signal("dash_requested"):
		SignalBus.dash_requested.connect(perform_dash)
	
	add_to_group("player")
	
	# 初始化狀態機
	for state in state_machine.get_children():
		state.player = self
	
	# 初始化血量 (假設 Resource 沒給，這裡給預設值)
	if health:
		health.max_hp = 100
		health.current_hp = 100
	
	SignalBus.seal_mode_toggled.connect(func(enabled: bool): is_seal_mode = enabled)
	update_animation_by_dir("idle_")

# --- 5. 物理循環 ---

func _physics_process(_delta: float) -> void:
	# 🔴 瞬移期間鎖死所有控制
	if is_dashing: return 
	
	# A. 獲取輸入 (即便在受擊硬直中也允許獲取，實現「邊走邊痛」)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if Engine.time_scale < 1.0:
		velocity = Vector2.ZERO # 劃圓封印時原地立定
	else:
		if input_dir != Vector2.ZERO:
			last_direction = input_dir.normalized()
			velocity = input_dir * move_speed
		else:
			# 增加摩擦力感
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 0.2)
	
	move_and_slide()
	
	# B. 動畫管理
	_manage_animations()

func _manage_animations() -> void:
	# 🔴 核心優先級：如果正在受擊硬直，Controller 不准更新移動動畫
	if is_hit_stun: return 
	
	# 只有在狀態機處於 Move 狀態時，才由這裡更新跑/待機動畫
	if state_machine.current_state and state_machine.current_state.name == "Move":
		update_animation_by_dir("idle_" if velocity.length() < 5 else "run_")

# --- 6. 戰鬥與受傷接口 ---

## 🔴 核心受擊邏輯
func take_damage(amount: int):
	# 無敵中或瞬移中不扣血
	if is_invincible or is_dashing: return
	
	# 1. 啟動狀態鎖
	is_hit_stun = true
	is_invincible = true
	
	# 2. 扣血與飄字
	if health:
		health.take_damage(amount)
	SignalBus.damage_spawned.emit(global_position, amount, true) # 通知電台噴出橘色數字
	
	# 3. 強制播放受擊動畫
	anim_sprite.stop()
	anim_sprite.play("hit")
	
	# 4. 執行受擊閃爍效果 (Tween)
	var t = create_tween().set_loops(int(invincible_time / 0.2))
	t.tween_property(anim_sprite, "modulate:a", 0.2, 0.1)
	t.tween_property(anim_sprite, "modulate:a", 1.0, 0.1)
	
	# 5. 等待受擊硬直結束 (允許恢復動畫切換)
	await get_tree().create_timer(hit_stun_duration).timeout
	is_hit_stun = false
	
	# 6. 等待無敵時間完全結束
	await get_tree().create_timer(invincible_time - hit_stun_duration).timeout
	is_invincible = false
	anim_sprite.modulate.a = 1.0 # 確保恢復不透明

## 🔴 供 AttackState 呼叫：攻擊踏步位移
func perform_attack_lunge():
	# 向前小跨步，增加打擊感
	var target_pos = global_position + (last_direction * lunge_distance)
	var t = create_tween()
	t.tween_property(self, "global_position", target_pos, 0.15).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

## 🔴 核心傷害判定 (由動畫影格或保險絲觸發)
func hit_current_target() -> void:
	if current_enemy:
		# 擊中怪物
		current_enemy.take_damage(10)
		# 通知電台在怪物位置噴出黃色數字
		SignalBus.damage_spawned.emit(current_enemy.global_position, 10, false)
	elif current_target:
		# 擊中資源
		current_target.start_harvest()

# --- 7. 輔助工具 ---

func update_animation_by_dir(prefix: String) -> void:
	update_flip()
	var anim_name = prefix + get_dir_string()
	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)

func update_flip() -> void:
	if last_direction.x != 0:
		anim_sprite.flip_h = (last_direction.x > 0)

func get_dir_string() -> String:
	var x = abs(last_direction.x); var y = abs(last_direction.y)
	if y > x * 1.5: return "down" if last_direction.y > 0 else "up"
	return "side"

func perform_dash() -> void:
	if is_dashing or is_hit_stun: return
	is_dashing = true
	
	var target_pos = global_position + (last_direction * dash_distance)
	var dash_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	dash_tween.tween_property(self, "global_position", target_pos, 0.5)
	
	anim_sprite.pause() 
	var jump_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(anim_sprite, "position:y", -80.0, 0.25)
	jump_tween.chain().set_ease(Tween.EASE_IN).tween_property(anim_sprite, "position:y", 0.0, 0.25)
	
	await dash_tween.finished
	is_dashing = false
	anim_sprite.play()

# --- 8. 偵測器 ---

func _on_interaction_detector_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent: current_enemy = area
	elif area is InteractableComponent: current_target = area

func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if area == current_enemy: current_enemy = null
	elif area == current_target: current_target = null
