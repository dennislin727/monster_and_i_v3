# res://src腳本/components積木/EffectManager.gd
extends Node2D

const ITEM_SLOT_POS = Vector2(50, 590)
const PET_SLOT_POS = Vector2(140, 590)

func _ready() -> void:
	SignalBus.request_effect_collect.connect(_on_collect_effect)
	SignalBus.damage_spawned.connect(_on_damage_spawned)
	SignalBus.popup_text.connect(_on_popup_text)
	# 🔴 核心修復：連接補血訊號
	SignalBus.heal_spawned.connect(_on_heal_spawned)
	
	if SignalBus.has_signal("seal_orb_fly"):
		SignalBus.seal_orb_fly.connect(_on_seal_orb_fly)

# 處理補血跳字
func _on_heal_spawned(world_pos: Vector2, value: int) -> void:
	var label = Label.new()
	label.set_script(load("res://src腳本/components積木/FloatingNumber.gd"))
	add_child(label)
	
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	label.global_position = screen_pos
	label.start_heal(value) # 呼叫補血專用動畫

# 傷害數字 (白字)
func _on_damage_spawned(world_pos: Vector2, value: int, _is_player: bool) -> void:
	var label = _create_popup_label(world_pos)
	label.start(value, Color.WHITE)

# 通用文字 (白字)
func _on_popup_text(world_pos: Vector2, msg: String, _color: Color) -> void:
	var label = _create_popup_label(world_pos)
	label.start_with_text(msg, Color.WHITE)

func _create_popup_label(world_pos: Vector2) -> Label:
	var label = Label.new()
	label.set_script(load("res://src腳本/components積木/FloatingNumber.gd"))
	add_child(label)
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	label.global_position = screen_pos
	return label

# --- 收集特效 ---
func _on_collect_effect(world_pos: Vector2, texture: Texture2D) -> void:
	_spawn_flying_icon(world_pos, texture, ITEM_SLOT_POS)

func _on_seal_orb_fly(world_pos: Vector2) -> void:
	var orb_texture = load("res://icon.svg") 
	_spawn_flying_icon(world_pos, orb_texture, PET_SLOT_POS)

func _spawn_flying_icon(world_pos: Vector2, texture: Texture2D, target_ui_pos: Vector2) -> void:
	if texture == null: return
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.z_index = 100 
	sprite.scale = Vector2(0.6, 0.6)
	sprite.set_script(load("res://src腳本/components積木/CollectEffect.gd"))
	add_child(sprite)
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	sprite.global_position = screen_pos
	sprite.start_flying(screen_pos, target_ui_pos)
