# res://src腳本/components積木/LineSweepAoE.gd
# 線段掃掠 AOE：沿 _start→_end 移動視覺錨點，並對「路徑附近」目標各造成一次傷害。
extends Node2D

var _skill: SkillResource
var _caster: Node2D
## true：怪物施放，傷害玩家與 deployed_pet；false：寵物施放，傷害 monsters（含 Hurtbox）
var _hurt_player_side: bool = true
var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO
var _duration: float = 0.9
var _radius: float = 40.0
var _power: int = 20
var _elapsed: float = 0.0
var _hit_ids: Dictionary = {}


func setup(
		skill: SkillResource,
		caster: Node2D,
		hurt_player_side: bool,
		seg_start: Vector2,
		seg_end: Vector2
	) -> void:
	_skill = skill
	_caster = caster
	_hurt_player_side = hurt_player_side
	_start = seg_start
	_end = seg_end
	_duration = maxf(0.05, skill.aoe_sweep_duration_sec)
	_radius = maxf(8.0, skill.aoe_sweep_hit_radius)
	_power = maxi(1, skill.power)
	global_position = seg_start
	z_index = 95
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	var p: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var tip: Vector2 = _start.lerp(_end, p)
	global_position = tip
	queue_redraw()
	_scan_hits(tip)
	if p >= 1.0:
		set_process(false)
		queue_free()


func _dist_sq_to_sweep(p: Vector2, tip: Vector2) -> float:
	var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, _start, tip)
	return p.distance_squared_to(c)


func _scan_hits(tip: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if _hurt_player_side:
		_try_hit_player_side(tree, tip)
	else:
		_try_hit_monsters(tree, tip)


func _try_hit_player_side(tree: SceneTree, tip: Vector2) -> void:
	var r2: float = (_radius + 28.0)
	r2 *= r2
	var party_took_hp_loss := false
	var player := tree.get_first_node_in_group("player") as Node2D
	if player and is_instance_valid(player):
		var pid: int = player.get_instance_id()
		if not _hit_ids.has(pid) and _dist_sq_to_sweep(player.global_position, tip) <= r2:
			_hit_ids[pid] = true
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
		var pid2: int = p2.get_instance_id()
		if _hit_ids.has(pid2):
			continue
		if not p2.has_method("take_damage_from_monster"):
			continue
		var hc: Node = p2.get_node_or_null("HealthComponent")
		if hc is HealthComponent and (hc as HealthComponent).current_hp <= 0:
			continue
		if _dist_sq_to_sweep(p2.global_position, tip) <= r2:
			_hit_ids[pid2] = true
			var hcp := hc as HealthComponent
			var pet_hp_before := hcp.current_hp
			p2.take_damage_from_monster(_power)
			if hcp.current_hp < pet_hp_before:
				party_took_hp_loss = true
	_emit_party_damaged_by_monster_if_needed(party_took_hp_loss)


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


func _try_hit_monsters(tree: SceneTree, tip: Vector2) -> void:
	var r2: float = (_radius + 24.0)
	r2 *= r2
	for m in tree.get_nodes_in_group("monsters"):
		if not m is Node2D:
			continue
		var node := m as Node2D
		if not is_instance_valid(node):
			continue
		if node == _caster:
			continue
		var mid: int = node.get_instance_id()
		if _hit_ids.has(mid):
			continue
		if node.has_method("is_dead") and node.get("is_dead") == true:
			continue
		var hb: Node = node.get_node_or_null("HurtboxComponent")
		var test_pos: Vector2 = node.global_position
		if hb is Node2D:
			test_pos = (hb as Node2D).global_position
		if _dist_sq_to_sweep(test_pos, tip) > r2:
			continue
		_hit_ids[mid] = true
		if hb is HurtboxComponent:
			(hb as HurtboxComponent).take_damage(_power)


func _draw() -> void:
	# 占位視覺：滾石本體（日後可換圖）；塵土用半透明圓
	var rock_r: float = 22.0
	draw_circle(Vector2.ZERO, rock_r, Color(0.45, 0.38, 0.32, 0.95))
	draw_arc(Vector2.ZERO, rock_r + 6.0, 0.0, TAU, 24, Color(0.25, 0.22, 0.2, 0.5), 3.0, true)
	draw_circle(Vector2(-10, 6), 8.0, Color(0.35, 0.3, 0.26, 0.75))
