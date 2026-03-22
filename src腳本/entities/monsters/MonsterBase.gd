# res://src腳本/entities/monsters/MonsterBase.gd
@tool
class_name MonsterBase
extends CharacterBody2D

# --- 1. 數據驅動中心 (The Vessel) ---
@export var data: MonsterResource:
	set(value):
		data = value
		if Engine.is_editor_hint():
			update_visuals()

@export_group("工具")
@export var force_refresh: bool = false:
	set(_v): update_visuals()

# --- 2. 組件引用 (神經末梢) ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var state_machine: MonsterStateMachine = $StateMachine
# 確保路徑與你的場景樹一致
@onready var health_bar: TextureProgressBar = get_node_or_null("UIAnchor/HealthBar")
@onready var accessory_point: Marker2D = get_node_or_null("AccessoryPoint")

# --- 3. 共享數據庫 (供所有狀態讀寫) ---
var target_player: PlayerController = null
var skill_cds: Dictionary = {}    # 格式: {SkillResource: float}
var last_dir_str: String = "down" # 記憶方向
var is_dead: bool = false
var attack_counter: int = 0 # 🔴 紀錄普攻次數

# --- 4. 初始化 ---

func _ready() -> void:
	update_visuals()
	
	if Engine.is_editor_hint(): return 
	
	add_to_group("monsters")
	
	# 初始化生命值
	if data and health:
		health.max_hp = data.max_hp
		health.current_hp = data.max_hp
		health.died.connect(_on_died)
		if health_bar:
			health_bar.setup(health)
	
	# 🔴 核心變動：啟動狀態機並傳遞自己
	if state_machine:
		state_machine.init(self)
	else:
		push_error("[MonsterBase] 警告：找不到 StateMachine 節點！")

# --- 5. 物理與 UI 循環 (僅處理身體，不處理大腦) ---

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_dead: return
	
	# A. 更新技能冷卻 (這屬於物理層級的倒數)
	for s in skill_cds.keys():
		if skill_cds[s] > 0: skill_cds[s] -= delta
		
	# B. 執行移動 (由當前狀態決定 velocity)
	move_and_slide()
	
	# C. 處理血條顯示 (這屬於視覺層級的自動淡入淡出)
	_update_health_bar_visibility(delta)

# --- 6. 狀態機專用工具函數 (行為積木的工具箱) ---

## 統一的動畫播放器：處理「方向後綴」與「退路機制」
func play_monster_animation(anim_prefix: String):
	if not anim or not anim.sprite_frames: return
	
	var dir = get_dir_string()
	var target_anim = anim_prefix + "_" + dir
	
	# 如果找不到帶方向的動畫 (如 attack_down)，嘗試找不帶方向的 (如 attack)
	if not anim.sprite_frames.has_animation(target_anim):
		if anim.sprite_frames.has_animation(anim_prefix):
			target_anim = anim_prefix
		else:
			# 最後退路：播 idle_down 確保不報錯
			target_anim = "idle_down"

	if anim.animation != target_anim or not anim.is_playing():
		anim.play(target_anim)
		# 處理側面翻轉
		if dir == "side":
			_handle_side_flip()

## 獲取目前的朝向字串
func get_dir_string() -> String:
	var ref_vector = velocity
	# 如果正在追人或施法，方向以玩家位置為準
	if target_player and (velocity.length() < 10):
		ref_vector = target_player.global_position - global_position
	
	if ref_vector.length() < 2: return last_dir_str
	
	var x = abs(ref_vector.x)
	var y = abs(ref_vector.y)
	
	if y > x * 1.3:
		last_dir_str = "down" if ref_vector.y > 0 else "up"
	else:
		last_dir_str = "side"
	return last_dir_str

## 尋找目前可用的技能
func get_available_skill() -> SkillResource:
	if not data or data.skills.is_empty(): return null
	var hp_pct = float(health.current_hp) / health.max_hp
	for s in data.skills:
		if s and skill_cds.get(s, 0) <= 0 and hp_pct <= s.max_hp_pct:
			return s
	return null

# --- 7. 內部視覺與事件處理 ---

func _handle_side_flip():
	var look_dir = velocity.x
	if target_player:
		look_dir = target_player.global_position.x - global_position.x
	
	if look_dir != 0:
		anim.flip_h = (look_dir > 0)

func _update_health_bar_visibility(delta: float):
	if not health_bar: return
	# 如果有目標玩家，血條顯現；否則淡出
	var target_alpha = 1.0 if target_player != null else 0.0
	health_bar.modulate.a = move_toward(health_bar.modulate.a, target_alpha, delta * 2.0)

func update_visuals():
	var s = get_node_or_null("AnimatedSprite2D")
	if s and data and data.sprite_frames:
		s.sprite_frames = data.sprite_frames
		if s.sprite_frames.has_animation("idle_down"):
			s.play("idle_down")
	if has_node("AccessoryPoint") and data:
		$AccessoryPoint.position = data.accessory_offset

## 當被打時，由 HealthComponent 調用
func play_hit_animation(_is_final: bool):
	if is_dead: return
	# 🔴 核心修復：被打時強行命令狀態機切換到 Hurt 狀態
	if state_machine:
		state_machine.change_state(state_machine.get_node("Hurt"))

func _on_died():
	is_dead = true
	# 🔴 命令狀態機進入死亡狀態 (處理動畫與掉落)
	if state_machine:
		state_machine.change_state(state_machine.get_node("Die"))

# 供奧義狀態使用的瞬移工具
func perform_ghost_dash(dist: float):
	if not target_player: return
	var dash_dir = (global_position - target_player.global_position).normalized().rotated(randf_range(-0.5, 0.5))
	var target_pos = global_position + dash_dir * dist
	
	var t = create_tween().set_parallel(true)
	t.tween_property(anim, "scale", Vector2(1.8, 0.1), 0.15)
	t.tween_property(anim, "modulate:a", 0.0, 0.15)
	await t.finished
	global_position = target_pos
	var t2 = create_tween().set_parallel(true)
	t2.tween_property(anim, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)
	t2.tween_property(anim, "modulate:a", 1.0, 0.1)
	await t2.finished

# 繪製警告圈的邏輯 (簡單版)
func show_indicator(radius: float, duration: float):
	var circle = Line2D.new()
	add_child(circle)
	# 畫一個圓形路徑... (代碼略)
	# 或者簡單用一個預製的 Sprite 縮放
	var t = create_tween()
	# 這裡可以實作一個圓形進度條，倒數 1 秒後消失
	await t.finished
	circle.queue_free()
