# res://src腳本/entities/homestead/HomesteadStationVisualController.gd
extends Node

const _AGENT_SCENE := preload("res://scenes場景/entities主角_怪物_寵物/homestead/HomesteadPetStationAgent.tscn")
const DEBUG_HOMESTEAD_STATION_LOG := false
const _RECALL_FADE_SEC := 0.16

@export var markers_path: NodePath
@export_range(1, 24, 1) var active_agents_cap: int = 12
@export var lod_active_distance_px: float = 320.0
@export var light_tick_interval_sec: float = 0.45
@export var min_agent_spacing_px: float = 24.0

var _refresh_requested: bool = false
var _agents: Array[Node2D] = []


func _ready() -> void:
	if SignalBus:
		if not SignalBus.homestead_station_visuals_refresh.is_connected(_schedule_refresh):
			SignalBus.homestead_station_visuals_refresh.connect(_schedule_refresh)
		if not SignalBus.pet_roster_changed.is_connected(_schedule_refresh):
			SignalBus.pet_roster_changed.connect(_schedule_refresh)
	call_deferred("_refresh")


func _process(_delta: float) -> void:
	_update_lod_for_agents()


func _schedule_refresh() -> void:
	if _refresh_requested:
		return
	_refresh_requested = true
	call_deferred("_refresh")


func _refresh() -> void:
	_refresh_requested = false
	if not is_inside_tree():
		return
	if HomeManager:
		HomeManager.flush_homestead_agent_runtime_from_scene()
	var frame_tag := Engine.get_process_frames()
	var markers := get_node_or_null(markers_path)
	if markers == null or PetManager == null:
		push_warning("[StationVisual] skip spawn: markers or PetManager missing")
		return
	var tree := get_tree()
	var lc: Node = tree.get_first_node_in_group("level_container") if tree != null else null
	var list := PetManager.get_stationed_pets_ordered()
	var raw_stationed_count := PetManager.stationed_instance_order.size() if PetManager != null else 0
	if DEBUG_HOMESTEAD_STATION_LOG:
		print("[StationVisual] refresh frame=%d staged=%d resolved=%d markers=%d captured=%d" % [
			frame_tag, raw_stationed_count, list.size(), markers.get_child_count(), PetManager.captured_pets.size()
		])
	var mks := markers.get_children()
	if list.is_empty() and raw_stationed_count > 0:
		# 保底：即使解析不到 PetResource，也先以占位寵生成站點，避免靜默無顯示。
		for sid in PetManager.stationed_instance_order:
			var fake := PetResource.new()
			fake.instance_id = str(sid)
			fake.pet_id = "slime_green"
			fake.pet_name = "看家寵物"
			list.append(fake)
			if list.size() >= mks.size():
				break
		if DEBUG_HOMESTEAD_STATION_LOG:
			print("[StationVisual] fallback placeholders spawned=%d" % list.size())
	var roam_points: Array[Vector2] = []
	for mk in mks:
		if mk is Node2D:
			roam_points.append((mk as Node2D).global_position)
	var spawn_points := _build_spawn_points(roam_points, list.size())
	var offline_elapsed_sec := 0
	if HomeManager:
		offline_elapsed_sec = HomeManager.consume_homestead_agents_offline_elapsed_sec()
	var existing_by_iid := _collect_existing_agents_by_instance_id()
	var wanted_ids: Dictionary = {}
	for p in list:
		if p == null:
			continue
		var iid := p.instance_id.strip_edges()
		if iid.is_empty():
			continue
		wanted_ids[iid] = true
	for iid in existing_by_iid.keys():
		if wanted_ids.has(str(iid)):
			continue
		var gone: Node = existing_by_iid[iid] as Node
		if gone != null and is_instance_valid(gone):
			if gone.has_method("fade_out_and_queue_free"):
				gone.call("fade_out_and_queue_free", _RECALL_FADE_SEC)
			else:
				gone.queue_free()
	for i in list.size():
		var pet: PetResource = list[i]
		if pet == null:
			continue
		var pet_iid := pet.instance_id.strip_edges()
		if not pet_iid.is_empty() and existing_by_iid.has(pet_iid):
			continue
		var agent: Node = _AGENT_SCENE.instantiate()
		agent.name = "StationPet_%d_f%d" % [i, frame_tag]
		agent.add_to_group("homestead_station_visual")
		agent.set_meta("station_controller_path", get_path())
		var gp := spawn_points[i] if i < spawn_points.size() else _fallback_spawn_point(roam_points, i)
		if lc != null:
			lc.add_child(agent)
		else:
			add_child(agent)
		if agent is Node2D:
			var n2 := agent as Node2D
			n2.global_position = gp
			_agents.append(n2)
		if agent.has_method("setup"):
			agent.call("setup", pet)
		if agent.has_method("setup_runtime"):
			agent.call("setup_runtime", roam_points, min_agent_spacing_px)
		if HomeManager and agent.has_method("apply_runtime_save_snapshot"):
			var rt: Dictionary = HomeManager.get_homestead_agent_runtime_for_instance(pet.instance_id)
			if not rt.is_empty():
				agent.call("apply_runtime_save_snapshot", rt, offline_elapsed_sec)
		if DEBUG_HOMESTEAD_STATION_LOG:
			print("[StationVisual] spawned idx=%d iid=%s at=%s" % [i, pet.instance_id, str(gp)])
	_rebuild_agents_cache()
	_update_lod_for_agents()


func _build_spawn_points(roam_points: Array[Vector2], count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count <= 0:
		return out
	if roam_points.is_empty():
		for i in count:
			out.append(_fallback_spawn_point(roam_points, i))
		return out
	for i in count:
		var base := roam_points[i % roam_points.size()]
		var jitter := Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 14.0))
		out.append(base + jitter)
	return out


func _fallback_spawn_point(roam_points: Array[Vector2], idx: int) -> Vector2:
	if roam_points.is_empty():
		return Vector2(22.0 * float(idx), 0.0)
	var center := Vector2.ZERO
	for p in roam_points:
		center += p
	center /= float(roam_points.size())
	var ring := int(idx / max(1, roam_points.size()))
	var angle := float(idx) * 0.85
	var radius := 26.0 + 24.0 * float(ring)
	return center + Vector2.from_angle(angle) * radius


func _update_lod_for_agents() -> void:
	if _agents.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var sortable: Array[Dictionary] = []
	for n in _agents:
		if n == null or not is_instance_valid(n):
			continue
		sortable.append({
			"node": n,
			"dist2": n.global_position.distance_squared_to(player.global_position),
		})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("dist2", INF)) < float(b.get("dist2", INF))
	)
	for i in sortable.size():
		var node := sortable[i].get("node") as Node
		if node == null:
			continue
		var d2 := float(sortable[i].get("dist2", INF))
		var within := d2 <= lod_active_distance_px * lod_active_distance_px
		var active := i < active_agents_cap and within
		if node.has_method("set_lod_mode"):
			node.call("set_lod_mode", active, light_tick_interval_sec)


func _collect_existing_agents_by_instance_id() -> Dictionary:
	var out: Dictionary = {}
	var tree := get_tree()
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("homestead_station_visual"):
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get_meta("station_controller_path", "")) != str(get_path()):
			continue
		if not n.has_method("get_pet_instance_id"):
			continue
		var iid := str(n.call("get_pet_instance_id")).strip_edges()
		if iid.is_empty():
			continue
		out[iid] = n
	return out


func _rebuild_agents_cache() -> void:
	_agents.clear()
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("homestead_station_visual"):
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get_meta("station_controller_path", "")) != str(get_path()):
			continue
		if n is Node2D:
			_agents.append(n as Node2D)


func _clear_spawned_agents() -> void:
	_agents.clear()
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("homestead_station_visual"):
		if not is_instance_valid(n):
			continue
		if str(n.get_meta("station_controller_path", "")) != str(get_path()):
			continue
		n.queue_free()
