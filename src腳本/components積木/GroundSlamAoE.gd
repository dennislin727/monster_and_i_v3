# res://src腳本/components積木/GroundSlamAoE.gd
# 落地圈 AOE：鎖定施法當下之世界座標，警示期間可走位；結算時圓形範圍一次傷害。可選拋物線落點演出。
extends Node2D

var _skill: SkillResource
var _caster: Node2D
var _hurt_player_side: bool = true
var _impact_world: Vector2 = Vector2.ZERO
var _duration: float = 0.7
var _radius: float = 48.0
var _power: int = 20
var _elapsed: float = 0.0
var _hit_done: bool = false
var _warn_col: Color = Color(1, 0.22, 0.14, 0.42)
var _arc_height: float = 96.0
## 預警圖 Y 向縮放（等距貼地）；命中仍用世界座標圓形，僅視覺為橢圓。
var _ground_telegraph_y_scale: float = 0.52
## true：僅顯示落地圈、不結算；由外部每幀 `set_preview_impact_world` 更新位置，直至 `queue_free`。
var _preview_mode: bool = false

var _rock_sprite: AnimatedSprite2D
var _flight_anim_name: String = "flight"
var _impact_anim_name: String = "impact"
var _spin_turns: float = 2.5
var _impact_offset: Vector2 = Vector2.ZERO
var _impact_auto_center: bool = true
var _impact_auto_center_frac: float = 0.28


func setup(
		skill: SkillResource,
		caster: Node2D,
		hurt_player_side: bool,
		impact_world: Vector2,
		preview_mode: bool = false
	) -> void:
	_skill = skill
	_caster = caster
	_hurt_player_side = hurt_player_side
	_impact_world = impact_world
	_preview_mode = preview_mode
	_duration = maxf(0.05, skill.trigger_delay)
	_radius = maxf(10.0, skill.aoe_sweep_hit_radius)
	_power = maxi(1, skill.power)
	_warn_col = skill.warning_color
	_ground_telegraph_y_scale = clampf(skill.ground_telegraph_y_scale, 0.12, 1.0)
	_arc_height = clampf(_radius * 2.2, 72.0, 200.0)
	global_position = _impact_world
	z_index = 95
	_hit_done = false
	_elapsed = 0.0
	if skill:
		_flight_anim_name = skill.ground_slam_flight_anim.strip_edges()
		if _flight_anim_name.is_empty():
			_flight_anim_name = "flight"
		_impact_anim_name = skill.ground_slam_impact_anim.strip_edges()
		if _impact_anim_name.is_empty():
			_impact_anim_name = "impact"
		_spin_turns = skill.ground_slam_flight_spin_turns
		_impact_offset = skill.ground_slam_impact_visual_offset
		_impact_auto_center = skill.ground_slam_impact_auto_center_in_telegraph
		_impact_auto_center_frac = clampf(skill.ground_slam_impact_auto_center_frac_of_height, 0.0, 0.55)
	if not _preview_mode:
		_setup_rock_sprite_if_needed()
	set_process(true)


func set_preview_impact_world(p: Vector2) -> void:
	_impact_world = p
	global_position = p


func _setup_rock_sprite_if_needed() -> void:
	if _skill == null:
		return
	var sf: SpriteFrames = _skill.ground_slam_rock_sprite_frames
	if sf == null:
		return
	if not sf.has_animation(_flight_anim_name):
		push_warning("GroundSlamAoE: SpriteFrames 缺少飛行動畫 '%s'，改用程式圓石。" % _flight_anim_name)
		return
	var rs := AnimatedSprite2D.new()
	rs.name = "RockSprite"
	rs.sprite_frames = sf
	rs.centered = true
	rs.z_index = 2
	add_child(rs)
	_rock_sprite = rs
	rs.play(_flight_anim_name)


func _process(delta: float) -> void:
	if _preview_mode:
		_elapsed += delta
		queue_redraw()
		return

	_elapsed += delta
	queue_redraw()
	var p: float = clampf(_elapsed / _duration, 0.0, 1.0)
	_update_rock_flight_visual(p)
	if p >= 1.0 and not _hit_done:
		_hit_done = true
		_apply_impact()
		if _rock_sprite != null and _sprite_has_impact_animation():
			set_process(false)
			_begin_impact_visual()
		else:
			set_process(false)
			queue_free()


func _sprite_has_impact_animation() -> bool:
	if _rock_sprite == null or _rock_sprite.sprite_frames == null:
		return false
	var sf: SpriteFrames = _rock_sprite.sprite_frames
	if not sf.has_animation(_impact_anim_name):
		return false
	return sf.get_frame_count(_impact_anim_name) > 0


func _update_rock_flight_visual(p: float) -> void:
	if _rock_sprite == null or not is_instance_valid(_caster):
		return
	var rock_t: float = clampf(p * 1.08, 0.0, 1.0)
	var rg: Vector2 = _rock_global_pos(rock_t)
	_rock_sprite.global_position = rg
	_rock_sprite.rotation = rock_t * TAU * _spin_turns


func _impact_auto_vertical_offset() -> Vector2:
	if not _impact_auto_center or _rock_sprite == null:
		return Vector2.ZERO
	var sf: SpriteFrames = _rock_sprite.sprite_frames
	if sf == null or not sf.has_animation(_impact_anim_name):
		return Vector2.ZERO
	var n: int = sf.get_frame_count(_impact_anim_name)
	if n < 1:
		return Vector2.ZERO
	var tex: Texture2D = sf.get_frame_texture(_impact_anim_name, 0)
	if tex == null:
		return Vector2.ZERO
	var h: float = tex.get_height()
	return Vector2(0.0, -h * _impact_auto_center_frac)


func _begin_impact_visual() -> void:
	if _rock_sprite == null:
		queue_free()
		return
	_rock_sprite.rotation = 0.0
	_rock_sprite.offset = Vector2.ZERO
	_rock_sprite.position = _impact_offset + _impact_auto_vertical_offset()
	if _rock_sprite.sprite_frames.has_animation(_impact_anim_name):
		_rock_sprite.play(_impact_anim_name)
	else:
		queue_free()
		return
	_rock_sprite.animation_finished.connect(_on_rock_impact_finished, CONNECT_ONE_SHOT)


func _on_rock_impact_finished() -> void:
	if is_instance_valid(self):
		queue_free()


func _rock_global_pos(t: float) -> Vector2:
	if not is_instance_valid(_caster):
		return _impact_world
	var a: Vector2 = _caster.global_position
	var b: Vector2 = _impact_world
	var pos: Vector2 = a.lerp(b, t)
	pos.y -= sin(t * PI) * _arc_height
	return pos


func _apply_impact() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var r: float = _radius + 28.0
	var r2: float = r * r
	if _hurt_player_side:
		var party_took_hp_loss := false
		var player := tree.get_first_node_in_group("player") as Node2D
		if player and is_instance_valid(player):
			if player.global_position.distance_squared_to(_impact_world) <= r2:
				if player.has_method("take_damage"):
					var phealth: HealthComponent = player.health if player.get("health") else null
					var hp_before := phealth.current_hp if phealth else -999999
					player.take_damage(_power)
					if phealth != null and phealth.current_hp < hp_before:
						party_took_hp_loss = true
		for pet in tree.get_nodes_in_group("deployed_pet"):
			if not pet is Node2D:
				continue
			var p2 := pet as Node2D
			if not is_instance_valid(p2):
				continue
			if not p2.has_method("take_damage_from_monster"):
				continue
			var hc: Node = p2.get_node_or_null("HealthComponent")
			if hc is HealthComponent and (hc as HealthComponent).current_hp <= 0:
				continue
			if p2.global_position.distance_squared_to(_impact_world) <= r2:
				var hcp := hc as HealthComponent
				var pet_hp_before := hcp.current_hp
				p2.take_damage_from_monster(_power)
				if hcp.current_hp < pet_hp_before:
					party_took_hp_loss = true
		_emit_party_damaged_by_monster_if_needed(party_took_hp_loss)
	else:
		for m in tree.get_nodes_in_group("monsters"):
			if not m is Node2D:
				continue
			var node := m as Node2D
			if not is_instance_valid(node):
				continue
			if node == _caster:
				continue
			if node.has_method("is_dead") and node.get("is_dead") == true:
				continue
			var test_pos: Vector2 = node.global_position
			var hb: Node = node.get_node_or_null("HurtboxComponent")
			if hb is Node2D:
				test_pos = (hb as Node2D).global_position
			if test_pos.distance_squared_to(_impact_world) > r2:
				continue
			if hb is HurtboxComponent:
				(hb as HurtboxComponent).take_damage(_power)


## 與 `MonsterAttackState` 近戰一致：隊伍實際扣血後廣播，供寵物還手鎖敵（遠程 AOE 亦需施法者 Hurtbox）。
func _emit_party_damaged_by_monster_if_needed(party_took_hp_loss: bool) -> void:
	if not party_took_hp_loss:
		return
	if SignalBus == null:
		return
	if not is_instance_valid(_caster):
		return
	var attacker_hb: HurtboxComponent = _caster.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if attacker_hb == null or not is_instance_valid(attacker_hb):
		return
	SignalBus.party_damaged_by_monster.emit(attacker_hb)


func _draw() -> void:
	var p: float = clampf(_elapsed / _duration, 0.0, 1.0)
	# 整體略加深（怪物／寵物共用同一節點）
	var base: Color = Color(
		_warn_col.r * 0.9,
		_warn_col.g * 0.86,
		_warn_col.b * 0.82,
		clampf(_warn_col.a * 1.14, 0.14, 0.96)
	)
	var t_fill: float = ease(p, -1.35)
	var inner_start: float = maxf(3.0, _radius * 0.06)
	var fill_r: float = lerpf(inner_start, _radius, t_fill)
	var fill_a: float = base.a * lerp(0.38, 0.62, p)
	var ring_a: float = base.a * lerp(0.48, 0.88, p)
	var fill: Color = Color(base.r, base.g, base.b, fill_a)
	var ring: Color = Color(base.r * 0.98, base.g * 0.9, base.b * 0.88, ring_a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, _ground_telegraph_y_scale))
	draw_circle(Vector2.ZERO, fill_r, fill)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 56, ring, 3.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _preview_mode:
		return
	if _rock_sprite != null:
		return
	if not is_instance_valid(_caster):
		return
	var rock_t: float = clampf(p * 1.08, 0.0, 1.0)
	var rg: Vector2 = _rock_global_pos(rock_t)
	var lp: Vector2 = to_local(rg)
	var rock_r: float = 16.0
	draw_circle(lp, rock_r, Color(0.42, 0.36, 0.3, 0.96))
	draw_arc(lp, rock_r + 5.0, 0.0, TAU, 20, Color(0.22, 0.2, 0.17, 0.45), 2.5, true)
