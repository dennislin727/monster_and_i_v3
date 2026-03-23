# res://src腳本/components積木/EffectManager.gd
extends Node2D

# 座標常數設定 (根據你的 UI 四格位置)
const ITEM_SLOT_POS = Vector2(50, 590)  # 左一：物品
const PET_SLOT_POS = Vector2(140, 590) # 左二：寵物

func _ready() -> void:
	SignalBus.request_effect_collect.connect(_on_collect_effect)
	SignalBus.damage_spawned.connect(_on_damage_spawned)
	SignalBus.popup_text.connect(_on_popup_text)
	
	# 監聽封印成功的光球飛行
	if SignalBus.has_signal("seal_orb_fly"):
		SignalBus.seal_orb_fly.connect(_on_seal_orb_fly)

# 處理一般傷害數字
func _on_damage_spawned(world_pos: Vector2, value: int, is_player: bool) -> void:
	var label = _create_popup_label(world_pos)
	var color = Color.ORANGE if is_player else Color.YELLOW
	label.start(value, color)

# 處理通用文字跳轉 (Got you / Fail / 長壓提示)
func _on_popup_text(world_pos: Vector2, msg: String, color: Color) -> void:
	var label = _create_popup_label(world_pos)
	label.start_with_text(msg, color)

# 內部輔助：建立 Label 並轉換座標
func _create_popup_label(world_pos: Vector2) -> Label:
	var label = Label.new()
	label.set_script(load("res://src腳本/components積木/FloatingNumber.gd"))
	add_child(label)
	
	# 將世界座標轉為螢幕座標，並稍微往上偏一點避免遮擋模型
	var screen_pos = get_viewport().get_canvas_transform() * (world_pos + Vector2(0, -20))
	label.global_position = screen_pos
	return label

# 處理物品收集動畫 (飛向第一格)
func _on_collect_effect(world_pos: Vector2, texture: Texture2D) -> void:
	_spawn_flying_icon(world_pos, texture, ITEM_SLOT_POS)

# 處理寵物收容動畫 (飛向第二格)
func _on_seal_orb_fly(world_pos: Vector2) -> void:
	# 這裡可以用一個發光球體的圖示，或者暫時用 icon.svg 替代測試
	var orb_texture = load("res://icon.svg") 
	_spawn_flying_icon(world_pos, orb_texture, PET_SLOT_POS)

# 內部輔助：生成飛行圖示邏輯
func _spawn_flying_icon(world_pos: Vector2, texture: Texture2D, target_ui_pos: Vector2) -> void:
	if texture == null: return
	
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.z_index = 100 
	sprite.scale = Vector2(0.5, 0.5) # 初始噴發大小
	sprite.set_script(load("res://src腳本/components積木/CollectEffect.gd"))
	add_child(sprite)
	
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	sprite.global_position = screen_pos
	
	# 呼叫噴發動畫 (飛往指定 UI 格位)
	sprite.start_flying(screen_pos, target_ui_pos)
