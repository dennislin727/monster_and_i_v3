# res://src腳本/components積木/EffectManager.gd
extends Node2D

const ITEM_SLOT_POS = Vector2(50, 590)
const PET_SLOT_POS = Vector2(140, 590)

func _ready() -> void:
	SignalBus.request_effect_collect.connect(_on_collect_effect)
	SignalBus.damage_spawned.connect(_on_damage_spawned)
	# 🔴 核心改動：將封印文字信號導向專用處理函數
	SignalBus.popup_text.connect(_on_seal_popup)
	SignalBus.heal_spawned.connect(_on_heal_spawned)
	
	if SignalBus.has_signal("seal_orb_fly"):
		SignalBus.seal_orb_fly.connect(_on_seal_orb_fly)

# 🟢 [專用入口] 模仿補血模式：處理封印文字 (白色、標準化)
func _on_seal_popup(target: Node2D, msg: String, _color: Color) -> void:
	if not is_instance_valid(target): return
	
	# 🟢 保險：如果怪物身上已經有舊的字，先把它弄掉
	if target.has_node("SealingComponent"):
		var old_comp = target.get_node("SealingComponent")
		if is_instance_valid(old_comp.hint_label):
			old_comp.hint_label.dismiss()
	
	var label = Label.new()
	label.set_script(load("res://src腳本/components積木/FloatingNumber.gd"))
	# 🔴 必須先 add_child，top_level 才會生效
	add_child(label)
	label.top_level = true
	label.z_index = 100
	
	if "長壓" in msg:
		label.start_persistent_hint(target, msg)
		if target.has_node("SealingComponent"):
			target.get_node("SealingComponent").hint_label = label
	else:
		# 🟢 這裡會呼叫修正後的 start_seal_text，文字就會出現了！
		label.start_seal_text(target, msg)

# --- 以下為標準化後的各類跳字 ---

func _on_damage_spawned(world_pos: Vector2, value: int, _is_player: bool) -> void:
	var label = _create_base_label(world_pos)
	label.start(value, Color.WHITE)

func _on_heal_spawned(world_pos: Vector2, value: int) -> void:
	var label = _create_base_label(world_pos)
	label.start_heal(value)

# 🟢 內部工具：統一標籤生成邏輯，解決座標偏移與層級問題
func _create_base_label(world_pos: Vector2) -> Label:
	var label = Label.new()
	label.set_script(load("res://src腳本/components積木/FloatingNumber.gd"))
	add_child(label)
	
	# 置頂與映射
	label.top_level = true
	label.z_index = 100
	
	# 🔴 座標精準映射：世界轉螢幕
	var canvas_transform = get_viewport().get_canvas_transform()
	var screen_pos = canvas_transform * world_pos
	label.global_position = screen_pos
	return label

# --- 收集特效 (修正版：區分動畫與圖片) ---

# 這是石頭採集用的 (傳入 Texture2D)
func _on_collect_effect(world_pos: Vector2, texture: Texture2D) -> void:
	if texture == null: return
	var sprite = Sprite2D.new()
	sprite.texture = texture
	_setup_and_fly(sprite, world_pos, ITEM_SLOT_POS)

# 這是靈魂球用的 (傳入 SpriteFrames)
func _on_seal_orb_fly(world_pos: Vector2) -> void:
	var orb_frames = load("res://assets圖片_字體_音效/主角/seal/light/soul_orb_frames.tres") 
	if orb_frames == null: return
	
	var anim_sprite = AnimatedSprite2D.new()
	anim_sprite.sprite_frames = orb_frames
	anim_sprite.play("default") # 讓它開始播動畫
	_setup_and_fly(anim_sprite, world_pos, PET_SLOT_POS)

# 統一處理：掛載腳本並啟動飛行
func _setup_and_fly(node: Node2D, world_pos: Vector2, target_pos: Vector2):
	node.top_level = true
	node.z_index = 100
	# 掛載你的飛行腳本
	node.set_script(load("res://src腳本/components積木/CollectEffect.gd"))
	add_child(node)
	
	# 座標轉換
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	if node.has_method("start_flying"):
		node.start_flying(screen_pos, target_pos)
