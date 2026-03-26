# res://src腳本/components積木/EffectManager.gd
extends Node2D

const ITEM_SLOT_POS = Vector2(50, 590)
const PET_SLOT_POS = Vector2(140, 590)
const SKILL_FX_RESOURCE_PATH := "res://src腳本/resources身分證/SkillFxResource.gd"
const FX_TEMPLATE_LIBRARY_PATH := "res://src腳本/resources身分證/skill_fx_templates/FxTemplateLibrary.gd"
const PROCEDURAL_FX_NODE_PATH := "res://src腳本/components積木/ProceduralFxNode.gd"

var _active_skill_fx_nodes: Array[Node2D] = []

func _ready() -> void:
	add_to_group("effect_manager")
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

# -----------------------------
# Skill FX (MVP pipeline)
# -----------------------------
func play_skill_fx(
		fx_resource: Resource,
		world_pos: Vector2,
		parent_node: Node = self,
		force_low_lod: bool = false
	) -> void:
	if fx_resource == null:
		return
	if not fx_resource.get_script() or str(fx_resource.get_script().resource_path) != SKILL_FX_RESOURCE_PATH:
		push_warning("[EffectManager] play_skill_fx 需要 SkillFxResource。")
		return
	_trim_dead_fx_nodes()
	if _active_skill_fx_nodes.size() >= GlobalBalance.FX_MAX_ACTIVE_SKILL_FX:
		return
	var lod_name := _resolve_lod_name(fx_resource, force_low_lod)
	var root := Node2D.new()
	root.name = "SkillFx_" + str(fx_resource.get("fx_id"))
	(parent_node if parent_node else self).add_child(root)
	_active_skill_fx_nodes.append(root)
	root.global_position = world_pos if not bool(fx_resource.get("use_screen_space")) else (get_viewport().get_canvas_transform() * world_pos)
	call_deferred("_run_skill_fx_pipeline", root, fx_resource, lod_name)

func _run_skill_fx_pipeline(root: Node2D, fx_resource: Resource, lod_name: String) -> void:
	if not is_instance_valid(root):
		return
	# 1) Telegraph
	var telegraph_frames = fx_resource.get("telegraph_frames")
	var telegraph_duration := float(fx_resource.get("telegraph_duration"))
	if telegraph_frames != null and telegraph_duration > 0.0:
		var tele = _spawn_fx_anim(root, telegraph_frames, fx_resource.get("telegraph_color"))
		if tele:
			await get_tree().create_timer(telegraph_duration).timeout
			if is_instance_valid(tele):
				tele.queue_free()
	# 2) Cast
	var cast_frames = fx_resource.get("cast_frames")
	var cast_duration := float(fx_resource.get("cast_duration"))
	if cast_frames != null and cast_duration > 0.0:
		var cast = _spawn_fx_anim(root, cast_frames, fx_resource.get("tint"))
		if cast:
			await get_tree().create_timer(cast_duration).timeout
			if is_instance_valid(cast):
				cast.queue_free()
	# 3) Impact
	var impact_frames = fx_resource.get("impact_frames")
	var impact_duration := float(fx_resource.get("impact_duration"))
	if impact_frames != null and impact_duration > 0.0:
		var impact = _spawn_fx_anim(root, impact_frames, fx_resource.get("tint"))
		if impact:
			_apply_lod_tweak(impact, lod_name)
			await get_tree().create_timer(impact_duration).timeout
			if is_instance_valid(impact):
				impact.queue_free()
	if is_instance_valid(root):
		root.queue_free()
	_trim_dead_fx_nodes()

func _spawn_fx_anim(parent_node: Node2D, frames: SpriteFrames, tint: Color) -> AnimatedSprite2D:
	if parent_node == null or frames == null:
		return null
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.modulate = tint
	anim.z_index = 90
	parent_node.add_child(anim)
	var names := frames.get_animation_names()
	if names.size() > 0:
		anim.play(names[0])
	return anim

func _apply_lod_tweak(anim: AnimatedSprite2D, lod_name: String) -> void:
	if anim == null:
		return
	if lod_name == "low":
		anim.modulate.a *= 0.75
		anim.scale *= 0.9
	elif lod_name == "medium":
		anim.modulate.a *= 0.9

func _resolve_lod_name(fx_resource: Resource, force_low_lod: bool) -> String:
	if force_low_lod:
		return "low"
	var lod: int = int(fx_resource.get("mobile_lod_level"))
	var estimated_particles: int = int(fx_resource.get("estimated_particles"))
	if estimated_particles > GlobalBalance.FX_PARTICLE_SOFT_CAP:
		return "low"
	if lod <= 0:
		return "high"
	if lod == 1:
		return "medium"
	return "low"

func _trim_dead_fx_nodes() -> void:
	_active_skill_fx_nodes = _active_skill_fx_nodes.filter(func(n): return is_instance_valid(n))

# -----------------------------
# Procedural FX templates
# -----------------------------
func play_template_fx_by_id(
		template_id: String,
		world_pos: Vector2,
		parent_node: Node = self,
		facing: Vector2 = Vector2.RIGHT
	) -> void:
	if template_id.strip_edges().is_empty():
		return
	var library = load(FX_TEMPLATE_LIBRARY_PATH)
	if library == null:
		return
	var template = library.make_template(template_id)
	if template == null:
		push_warning("[EffectManager] 未找到 FX 模板: %s" % template_id)
		return
	play_template_fx(template, world_pos, parent_node, facing)

func play_template_fx(
		template_resource: Resource,
		world_pos: Vector2,
		parent_node: Node = self,
		facing: Vector2 = Vector2.RIGHT
	) -> void:
	if template_resource == null:
		return
	_trim_dead_fx_nodes()
	if _active_skill_fx_nodes.size() >= GlobalBalance.FX_MAX_ACTIVE_SKILL_FX:
		return
	var fx_node := Node2D.new()
	fx_node.set_script(load(PROCEDURAL_FX_NODE_PATH))
	(parent_node if parent_node else self).add_child(fx_node)
	_active_skill_fx_nodes.append(fx_node)
	fx_node.global_position = world_pos
	if fx_node.has_method("setup"):
		fx_node.setup(template_resource, facing)
