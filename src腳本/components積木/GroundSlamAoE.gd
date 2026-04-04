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


func setup(
		skill: SkillResource,
		caster: Node2D,
		hurt_player_side: bool,
		impact_world: Vector2
	) -> void:
	_skill = skill
	_caster = caster
	_hurt_player_side = hurt_player_side
	_impact_world = impact_world
	_duration = maxf(0.05, skill.trigger_delay)
	_radius = maxf(10.0, skill.aoe_sweep_hit_radius)
	_power = maxi(1, skill.power)
	_warn_col = skill.warning_color
	_ground_telegraph_y_scale = clampf(skill.ground_telegraph_y_scale, 0.12, 1.0)
	_arc_height = clampf(_radius * 2.2, 72.0, 200.0)
	global_position = _impact_world
	z_index = 95
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	var p: float = clampf(_elapsed / _duration, 0.0, 1.0)
	if p >= 1.0 and not _hit_done:
		_hit_done = true
		_apply_impact()
		set_process(false)
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
	var pulse: float = 0.55 + 0.45 * sin(_elapsed * TAU * 2.2)
	var fill_a: float = _warn_col.a * lerp(0.22, 0.42, p) * pulse
	var ring_a: float = _warn_col.a * lerp(0.35, 0.75, p) * pulse
	var fill: Color = Color(_warn_col.r, _warn_col.g, _warn_col.b, fill_a)
	var ring: Color = Color(_warn_col.r, _warn_col.g * 0.85, _warn_col.b * 0.85, ring_a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, _ground_telegraph_y_scale))
	draw_circle(Vector2.ZERO, _radius, fill)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 56, ring, 3.5, true)
	draw_arc(Vector2.ZERO, _radius * 0.45, 0.0, TAU, 32, Color(ring.r, ring.g, ring.b, ring_a * 0.55), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_instance_valid(_caster):
		var rock_t: float = clampf(p * 1.08, 0.0, 1.0)
		var rg: Vector2 = _rock_global_pos(rock_t)
		var lp: Vector2 = to_local(rg)
		var rock_r: float = 16.0
		draw_circle(lp, rock_r, Color(0.42, 0.36, 0.3, 0.96))
		draw_arc(lp, rock_r + 5.0, 0.0, TAU, 20, Color(0.22, 0.2, 0.17, 0.45), 2.5, true)
