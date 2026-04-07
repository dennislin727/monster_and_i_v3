# res://src腳本/components積木/EffectManager.gd
extends Node2D

const ITEM_SLOT_POS = Vector2(50, 590)
const PET_SLOT_POS = Vector2(140, 590)
const SKILL_FX_RESOURCE_PATH := "res://resources身分證/skill_fx_templates/SkillFxResource.gd"
const FX_TEMPLATE_LIBRARY_PATH := "res://resources身分證/skill_fx_templates/FxTemplateLibrary.gd"
const PROCEDURAL_FX_NODE_PATH := "res://src腳本/components積木/ProceduralFxNode.gd"
const LINE_SWEEP_AOE_SCRIPT_PATH := "res://src腳本/components積木/LineSweepAoE.gd"
const GROUND_SLAM_AOE_SCRIPT_PATH := "res://src腳本/components積木/GroundSlamAoE.gd"

var _active_skill_fx_nodes: Array[Node2D] = []


## 使用 **世界座標** 的 Node2D FX 必須掛在與主角同一層（如 `level_container`）。  
## 若掛在 `UILayer`／`CanvasLayer` 下，數值會變成視窗空間，相機捲動／zoom 後與場上單位脫勾（落石、線掃、地板警示會飄走）。
func _world_space_fx_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return self
	var lc := tree.get_first_node_in_group("level_container")
	if lc is Node:
		return lc
	var cs: Node = tree.current_scene
	if cs is Node:
		return cs
	return self


func _ready() -> void:
	add_to_group("effect_manager")
	SignalBus.request_effect_collect.connect(_on_collect_effect)
	SignalBus.damage_spawned.connect(_on_damage_spawned)
	# 🔴 核心改動：將封印文字信號導向專用處理函數
	SignalBus.popup_text.connect(_on_seal_popup)
	SignalBus.heal_spawned.connect(_on_heal_spawned)
	
	if SignalBus.has_signal("seal_orb_fly"):
		SignalBus.seal_orb_fly.connect(_on_seal_orb_fly)
	if SignalBus.has_signal("dialogue_reward_vfx_requested"):
		SignalBus.dialogue_reward_vfx_requested.connect(_on_dialogue_reward_vfx_requested)

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


func _on_dialogue_reward_vfx_requested(world_pos: Vector2) -> void:
	var orb_frames = load("res://assets圖片_字體_音效/主角/seal/light/soul_orb_frames.tres")
	if orb_frames == null:
		return
	var anim_sprite := AnimatedSprite2D.new()
	anim_sprite.sprite_frames = orb_frames
	anim_sprite.play("default")
	var screen_start := get_viewport().get_canvas_transform() * world_pos
	var vr := get_viewport().get_visible_rect()
	var screen_end := Vector2(vr.position.x + vr.size.x * 0.5, vr.position.y + vr.size.y + 72.0)
	_setup_dialogue_reward_orb(anim_sprite, screen_start, screen_end)


func _setup_dialogue_reward_orb(node: Node2D, screen_start: Vector2, screen_end: Vector2) -> void:
	node.top_level = true
	node.z_index = 100
	node.set_script(load("res://src腳本/components積木/CollectEffect.gd"))
	add_child(node)
	if node.has_method("start_flying_dialogue_reward_arc"):
		node.start_flying_dialogue_reward_arc(screen_start, screen_end)

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
	var use_screen: bool = bool(fx_resource.get("use_screen_space"))
	var host: Node
	if use_screen:
		host = parent_node if parent_node != null else self
	else:
		host = _world_space_fx_parent()
	host.add_child(root)
	_active_skill_fx_nodes.append(root)
	root.global_position = world_pos if not use_screen else (get_viewport().get_canvas_transform() * world_pos)
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
	var attach_parent: Node = _world_space_fx_parent()
	# 預設參數為 EffectManager（self）；與舊行為一致仍掛世界 FX 層。若傳入其他父節點則跟隨該層級。
	if is_instance_valid(parent_node) and parent_node != self:
		attach_parent = parent_node
	attach_parent.add_child(fx_node)
	_active_skill_fx_nodes.append(fx_node)
	fx_node.global_position = world_pos
	if fx_node.has_method("setup"):
		fx_node.setup(template_resource, facing)


## 滾石類 AOE：沿視窗對角掃過；`hurt_player_side` true＝怪物施放（傷主角＋寵物），false＝寵物施放（傷怪物）。
func play_line_sweep_aoe_from_skill(skill: SkillResource, caster: Node2D, hurt_player_side: bool) -> void:
	if skill == null or caster == null or not is_instance_valid(caster):
		return
	_trim_dead_fx_nodes()
	if _active_skill_fx_nodes.size() >= GlobalBalance.FX_MAX_ACTIVE_SKILL_FX:
		return
	var seg := _compute_aoe_sweep_segment(skill, caster)
	var a := seg[0] as Vector2
	var b := seg[1] as Vector2
	var root := Node2D.new()
	root.name = "LineSweepAoE"
	_world_space_fx_parent().add_child(root)
	_active_skill_fx_nodes.append(root)
	var scr: Script = load(LINE_SWEEP_AOE_SCRIPT_PATH) as Script
	if scr:
		root.set_script(scr)
	if root.has_method("setup"):
		root.call("setup", skill, caster, hurt_player_side, a, b)


## 落地圈 AOE：鎖定 `impact_world`（通常為施法瞬間的主角座標），`trigger_delay` 內警示，結束時圓形範圍結算。
func play_ground_slam_aoe_from_skill(skill: SkillResource, caster: Node2D, hurt_player_side: bool, impact_world: Vector2) -> void:
	if skill == null or caster == null or not is_instance_valid(caster):
		return
	_trim_dead_fx_nodes()
	if _active_skill_fx_nodes.size() >= GlobalBalance.FX_MAX_ACTIVE_SKILL_FX:
		return
	var root := Node2D.new()
	root.name = "GroundSlamAoE"
	_world_space_fx_parent().add_child(root)
	_active_skill_fx_nodes.append(root)
	var scr: Script = load(GROUND_SLAM_AOE_SCRIPT_PATH) as Script
	if scr:
		root.set_script(scr)
	if root.has_method("setup"):
		root.call("setup", skill, caster, hurt_player_side, impact_world, false)


## 手動指揮：僅警示圈、跟隨瞄準；施放確認後請 `queue_free` 並改呼叫 `play_ground_slam_aoe_from_skill`。
func spawn_ground_slam_preview(skill: SkillResource, caster: Node2D, impact_world: Vector2) -> Node2D:
	if skill == null or caster == null or not is_instance_valid(caster):
		return null
	if not skill.aoe_use_ground_target:
		return null
	_trim_dead_fx_nodes()
	var root := Node2D.new()
	root.name = "GroundSlamAoEPreview"
	_world_space_fx_parent().add_child(root)
	var scr: Script = load(GROUND_SLAM_AOE_SCRIPT_PATH) as Script
	if scr:
		root.set_script(scr)
	if root.has_method("setup"):
		root.call("setup", skill, caster, false, impact_world, true)
	return root


func _compute_aoe_sweep_segment(skill: SkillResource, caster: Node2D) -> Array:
	var vp := get_viewport()
	var cam: Camera2D = vp.get_camera_2d()
	var center: Vector2 = caster.global_position
	if not skill.aoe_sweep_anchor_on_caster and cam != null:
		center = cam.get_screen_center_position()
	var margin: float = skill.aoe_sweep_margin_world
	if cam == null:
		return [center + Vector2(380, -280), center + Vector2(-380, 280)]
	var z: Vector2 = cam.zoom
	var vw: float = vp.get_visible_rect().size.x / maxf(0.001, z.x)
	var vh: float = vp.get_visible_rect().size.y / maxf(0.001, z.y)
	var start := center + Vector2(vw * 0.5 + margin, -vh * 0.5 - margin)
	var end := center + Vector2(-vw * 0.5 - margin, vh * 0.5 + margin)
	return [start, end]
