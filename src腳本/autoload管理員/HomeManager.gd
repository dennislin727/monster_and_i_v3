# res://src腳本/autoload管理員/HomeManager.gd
extends Node
## Phase 10：家園場景切換、採收模式狀態，與滑掃採收同幀上限（業務邏輯集中於此，非 SignalBus）。

const _LAKE_LEVEL := preload("res://scenes場景/levels/lake_side/LakeSideLevel.tscn")
const _HOMESTEAD_LEVEL := preload("res://scenes場景/levels/homestead/HomesteadLevel.tscn")
const _TOWN_LEVEL := preload("res://scenes場景/levels/town/FallenLeafTown.tscn")
const _MATURE_SCAN_LIMIT := 10
const _HARVEST_DONE_PAYLOAD: Dictionary = {
	"instant_text": "採收完畢...辛苦了!",
	"hold_sec": 2.0,
	"fade_out_sec": 0.65,
}
const _MATURE_REMINDER_PAYLOAD: Dictionary = {
	"instant_text": "有作物已成熟，開採收模式即可收割～",
	"hold_sec": 3.2,
	"fade_out_sec": 0.55,
}
const _HARVEST_CROP_MOD_BRIGHT := Color(1.22, 1.24, 1.14, 1.0)

var in_homestead: bool = false
## 進家園區時是否顯示「○○的家園」標題（步行進區為 true；日後切關後可改由關卡腳本呼叫 request_area_title）
@export var show_homestead_banner_on_enter: bool = true
var harvest_active: bool = false

var _dialogue_blocked: bool = false
var _harvest_cap_frame: int = -1
var _harvest_remaining_this_frame: int = 0
var _last_local_unix_sec: int = 0
var _pending_soil_snapshot: Dictionary = {}
## instance_id -> 看家寵巡遊／翻土冷卻等執行期快照（與土格、駐留名單分語意；離開家園區前會從場景合併）
var _homestead_agents_runtime: Dictionary = {}
## 與 `homestead_agents` 一併存檔：上次寫入快照的 Unix 秒；用於離線衰減冷卻／待機計時。
var _homestead_agents_saved_unix: int = 0
## 本次進家園是否已播過「有成熟作物」的一次性漸隱提醒
var _homestead_enter_mature_reminder_shown: bool = false


func _ready() -> void:
	_last_local_unix_sec = int(Time.get_unix_time_from_system())
	if SignalBus:
		SignalBus.harvest_mode_toggled.connect(_on_harvest_mode_toggled)
		SignalBus.dialogue_blocking_changed.connect(_on_dialogue_blocking_changed)
		SignalBus.seal_mode_toggled.connect(_on_seal_mode_toggled)
		SignalBus.item_collected.connect(_on_item_collected_homestead_hint)
		SignalBus.harvest_mode_changed.connect(_on_harvest_mode_changed_crop_highlight)


func set_player_in_homestead(value: bool, show_banner: bool = true) -> void:
	if in_homestead == value:
		return
	var was_inside := in_homestead
	if was_inside and not value:
		_merge_homestead_agent_runtime_from_scene()
	in_homestead = value
	if in_homestead and not was_inside:
		_homestead_enter_mature_reminder_shown = false
	if was_inside and not in_homestead and PetManager:
		PetManager.on_first_leave_homestead_if_needed()
	if not in_homestead and harvest_active:
		_set_harvest_active(false)
	if SignalBus:
		SignalBus.player_in_homestead_changed.emit(in_homestead)
		if in_homestead and show_banner and show_homestead_banner_on_enter:
			SignalBus.area_title_show_requested.emit(homestead_banner_title(), -1.0)
		elif not in_homestead:
			SignalBus.area_title_hide_requested.emit()
		if in_homestead:
			call_deferred("_apply_pending_soil_snapshot")
			call_deferred("_apply_offline_growth_on_enter")
			call_deferred("_sync_homestead_player_hints")
			if SignalBus:
				SignalBus.homestead_station_visuals_refresh.emit()
		elif SignalBus:
			SignalBus.player_world_hint_changed.emit("", false, null)
	_last_local_unix_sec = int(Time.get_unix_time_from_system())


## 與步行進區、日後切關後浮字共用；duration_sec≤0 則 UI 使用 GlobalBalance 預設節奏。
func request_area_title(title: String, duration_sec: float = -1.0) -> void:
	if SignalBus:
		SignalBus.area_title_show_requested.emit(title, duration_sec)


func homestead_banner_title() -> String:
	var n := GlobalBalance.PLAYER_DISPLAY_NAME.strip_edges()
	if n.is_empty():
		n = "冠冠"
	return "%s的家園" % n


## 土格成熟／採光回收後刷新家園提示（不暴露內部 _sync 細節）。
func request_homestead_hints_refresh() -> void:
	call_deferred("_sync_homestead_player_hints")


## 保留：日後若仍有整張關卡切換，可在換場完成後呼叫 request_area_title。
func switch_to_homestead(spawn_marker: String = "PlayerSpawn") -> void:
	_swap_level(_HOMESTEAD_LEVEL, spawn_marker)


func switch_to_lake(spawn_marker: String = "PlayerSpawn") -> void:
	_swap_level(_LAKE_LEVEL, spawn_marker)


func switch_to_town(spawn_marker: String = "PlayerSpawn_Bed") -> void:
	_swap_level(_TOWN_LEVEL, spawn_marker)


func switch_to_homestead_async(spawn_marker: String = "PlayerSpawn") -> void:
	await _swap_level(_HOMESTEAD_LEVEL, spawn_marker)


func switch_to_lake_async(spawn_marker: String = "PlayerSpawn") -> void:
	await _swap_level(_LAKE_LEVEL, spawn_marker)


func switch_to_town_async(spawn_marker: String = "PlayerSpawn_Bed") -> void:
	await _swap_level(_TOWN_LEVEL, spawn_marker)


func try_harvest_swipe_world(world_pos: Vector2) -> void:
	if not harvest_active:
		return
	var f := Engine.get_process_frames()
	if f != _harvest_cap_frame:
		_harvest_cap_frame = f
		_harvest_remaining_this_frame = GlobalBalance.HARVEST_MAX_ITEMS_PER_FRAME
	if _harvest_remaining_this_frame <= 0:
		return
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("homestead_crop"):
		if not is_instance_valid(node):
			continue
		if node.has_method("try_harvest_at") and bool(node.call("try_harvest_at", world_pos)):
			_bump_homestead_swipe_tutorial_if_needed()
			_harvest_remaining_this_frame -= 1
			if _harvest_remaining_this_frame <= 0:
				return


func _swap_level(packed: PackedScene, spawn_marker: String = "PlayerSpawn") -> void:
	if packed == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var lc := tree.get_first_node_in_group("level_container")
	if lc == null:
		push_warning("[HomeManager] level_container group missing on LevelContainer")
		return
	var overlay := tree.get_first_node_in_group("level_transition_overlay")
	var fade_out_sec := GlobalBalance.LEVEL_TRANSITION_FADE_OUT_SEC if GlobalBalance else 0.38
	var fade_in_sec := GlobalBalance.LEVEL_TRANSITION_FADE_IN_SEC if GlobalBalance else 0.42
	if overlay != null and overlay.has_method("run_fade"):
		await overlay.call("run_fade", true, fade_out_sec)
	_merge_homestead_agent_runtime_from_scene()
	for c in lc.get_children():
		if c.is_in_group("loaded_level"):
			c.queue_free()
	await tree.process_frame
	await tree.process_frame
	_purge_level_container_transients(lc)
	await tree.process_frame
	var inst := packed.instantiate()
	lc.add_child(inst)
	_warp_player_to_spawn(inst, spawn_marker)
	var p := tree.get_first_node_in_group("player")
	if p != null and p.has_method("snap_camera_after_warp"):
		p.call("snap_camera_after_warp")
	await tree.process_frame
	_request_area_title_for_swapped_level(packed)
	call_deferred("_resync_field_pets_after_warp")
	# 換關後 `HomesteadStationVisualController` 可能早於資料就緒 `_refresh`；補一次訊號，避免看家寵只存在資料卻不重生。
	if packed == _TOWN_LEVEL or packed == _HOMESTEAD_LEVEL:
		call_deferred("_emit_homestead_station_visuals_refresh_deferred")
	if overlay != null and overlay.has_method("run_fade"):
		await overlay.call("run_fade", false, fade_in_sec)


## `MarkersPropSpawner`／`ForegroundCanopyHoist`／看家寵視覺等會把實例掛到 `level_container`，
## 僅 `queue_free` `loaded_level` 無法清掉；換關時剷除殘留，避免怪物／石頭／樹跟到另一張地圖。
func _purge_level_container_transients(lc: Node) -> void:
	if lc == null:
		return
	for c in lc.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if _is_level_container_persistent_child(c):
			continue
		c.queue_free()


func _is_level_container_persistent_child(c: Node) -> bool:
	if c.is_in_group("player"):
		return true
	if str(c.name) == "PetCompanionSpawner":
		return true
	if c.is_in_group("deployed_pet"):
		return true
	return false


func _resync_field_pets_after_warp() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var lc := tree.get_first_node_in_group("level_container") as Node
	if lc == null:
		return
	var sp := lc.get_node_or_null(NodePath("PetCompanionSpawner"))
	if sp != null and sp.has_method("_sync_party"):
		sp.call("_sync_party")


func warp_player_to_spawn_marker(level_root: Node, spawn_marker: String = "PlayerSpawn") -> void:
	_warp_player_to_spawn(level_root, spawn_marker)


func _warp_player_to_spawn(level_root: Node, spawn_marker: String = "PlayerSpawn") -> void:
	var marker: Node = level_root.find_child(spawn_marker, true, false)
	if marker == null and spawn_marker != "PlayerSpawn":
		marker = level_root.find_child("PlayerSpawn", true, false)
	var p := get_tree().get_first_node_in_group("player")
	if marker is Node2D and p is Node2D:
		(p as Node2D).global_position = (marker as Node2D).global_position


func _request_area_title_for_swapped_level(packed: PackedScene) -> void:
	if packed == _HOMESTEAD_LEVEL:
		return
	if packed == _LAKE_LEVEL:
		request_area_title("史萊姆湖畔", -1.0)
	elif packed == _TOWN_LEVEL:
		request_area_title("落葉鎮", -1.0)


## 土格在成長時會重設作物 `modulate`，採收提亮須由此乘算；關閉採收時傳入 `base` 即最終色。
func apply_crop_harvest_highlight_modulate(base: Color) -> Color:
	if not harvest_active:
		return base
	return Color(
		base.r * _HARVEST_CROP_MOD_BRIGHT.r,
		base.g * _HARVEST_CROP_MOD_BRIGHT.g,
		base.b * _HARVEST_CROP_MOD_BRIGHT.b,
		base.a
	)


func _on_harvest_mode_changed_crop_highlight(_active: bool) -> void:
	refresh_homestead_soil_crop_modulates()


## 依每格土當前狀態重算作物顏色（採收中則維持提亮直到關閉採收或狀態變更）。
func refresh_homestead_soil_crop_modulates() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("homestead_soil_plot"):
		if n != null and is_instance_valid(n) and n.has_method("reapply_crop_modulate_for_harvest_mode"):
			n.call("reapply_crop_modulate_for_harvest_mode")


func _bump_homestead_swipe_tutorial_if_needed() -> void:
	if ProgressionManager == null:
		return
	if ProgressionManager.bump_homestead_swipe_tutorial_pick() and SignalBus:
		SignalBus.player_world_hint_changed.emit(PlayerHintCatalog.HINT_HOMESTEAD_SWIPE, false, null)


func _on_dialogue_blocking_changed(blocked: bool) -> void:
	_dialogue_blocked = blocked
	if blocked and harvest_active:
		_set_harvest_active(false)


func _on_seal_mode_toggled(enabled: bool) -> void:
	if enabled and harvest_active:
		_set_harvest_active(false)


func _on_harvest_mode_toggled(enabled: bool) -> void:
	if enabled:
		if not in_homestead or _dialogue_blocked or _is_seal_busy():
			if SignalBus:
				SignalBus.harvest_mode_changed.emit(harvest_active)
			return
		_set_harvest_active(true)
	else:
		_set_harvest_active(false)


func _set_harvest_active(active: bool) -> void:
	if harvest_active == active:
		return
	harvest_active = active
	if SignalBus:
		SignalBus.harvest_mode_changed.emit(harvest_active)
	call_deferred("_sync_homestead_player_hints")


func _count_mature_homestead_crops() -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	var n := 0
	for node in tree.get_nodes_in_group("homestead_crop"):
		if not is_instance_valid(node):
			continue
		if node.has_method("counts_as_mature_available") and bool(node.call("counts_as_mature_available")):
			n += 1
			if n >= _MATURE_SCAN_LIMIT:
				break
	return n


func _apply_offline_growth_on_enter() -> void:
	var now_unix := int(Time.get_unix_time_from_system())
	var elapsed := maxi(0, now_unix - _last_local_unix_sec)
	_last_local_unix_sec = now_unix
	if elapsed <= 0:
		return
	var tree := get_tree()
	if tree == null:
		return
	var matured_budget := _MATURE_SCAN_LIMIT
	for node in tree.get_nodes_in_group("homestead_soil_plot"):
		if matured_budget <= 0:
			break
		if not is_instance_valid(node):
			continue
		if not node.has_method("apply_offline_growth_seconds"):
			continue
		var consumed := int(node.call("apply_offline_growth_seconds", elapsed, matured_budget))
		if consumed > 0:
			matured_budget = maxi(0, matured_budget - consumed)


func _sync_homestead_player_hints() -> void:
	if not in_homestead or SignalBus == null or PlayerHintCatalog == null:
		return
	var m := _count_mature_homestead_crops()
	if harvest_active:
		if m > 0:
			if ProgressionManager != null and not ProgressionManager.homestead_harvest_swipe_tutorial_done:
				SignalBus.player_world_hint_changed.emit(PlayerHintCatalog.HINT_HOMESTEAD_SWIPE, true, null)
		else:
			SignalBus.player_world_hint_changed.emit(
				PlayerHintCatalog.HINT_HOMESTEAD_NO_CROPS, true, _HARVEST_DONE_PAYLOAD
			)
			_exit_harvest_mode_without_deferred_resync()
	else:
		if m > 0:
			if not _homestead_enter_mature_reminder_shown:
				SignalBus.player_world_hint_changed.emit("homestead_mature_reminder", true, _MATURE_REMINDER_PAYLOAD)
				_homestead_enter_mature_reminder_shown = true
		else:
			SignalBus.player_world_hint_changed.emit("", false, null)


## 採光成熟作物後：關採收模式並廣播 HUD／移動鎖，但不 call_deferred _sync（否則 m==0 會立刻把「汗QQ」提示清掉）
func _exit_harvest_mode_without_deferred_resync() -> void:
	if not harvest_active:
		return
	harvest_active = false
	if SignalBus:
		SignalBus.harvest_mode_changed.emit(false)


func _on_item_collected_homestead_hint(_item: Resource) -> void:
	if not in_homestead or not harvest_active:
		return
	call_deferred("_sync_homestead_player_hints")


func _is_seal_busy() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var sm := tree.get_first_node_in_group("seal_manager")
	if sm != null and sm.has_method("is_seal_ritual_active") and bool(sm.is_seal_ritual_active()):
		return true
	var p := tree.get_first_node_in_group("player")
	if p != null and p.get("is_seal_mode") == true:
		return true
	return false


func get_save_snapshot() -> Dictionary:
	if in_homestead:
		_merge_homestead_agent_runtime_from_scene()
	_prune_homestead_agents_not_stationed()
	var pet_station: Dictionary = {}
	if PetManager and PetManager.has_method("get_home_save_snapshot"):
		pet_station = PetManager.get_home_save_snapshot()
	var soil := _capture_soil_snapshot()
	var now_agents_unix := int(Time.get_unix_time_from_system())
	_homestead_agents_saved_unix = now_agents_unix
	return {
		"last_local_unix_sec": _last_local_unix_sec,
		"pet_station": pet_station,
		"soil": soil,
		"homestead_agents": _homestead_agents_runtime.duplicate(true),
		"homestead_agents_unix": now_agents_unix,
	}


func _emit_homestead_station_visuals_refresh_deferred() -> void:
	if SignalBus:
		SignalBus.homestead_station_visuals_refresh.emit()


func apply_save_snapshot(data: Dictionary) -> void:
	_last_local_unix_sec = int(data.get("last_local_unix_sec", int(Time.get_unix_time_from_system())))
	var ps: Variant = data.get("pet_station", {})
	# 舊／手刻 JSON 可能把 stationed_order 放在 home 頂層而無 pet_station 包一層，會讀成空 {} 而清空駐留。
	if ps is Dictionary:
		var dps: Dictionary = ps as Dictionary
		if dps.is_empty() and (data.has("stationed_order") or data.has("stationed_seeds")):
			ps = {
				"stationed_order": data.get("stationed_order", []),
				"stationed_seeds": data.get("stationed_seeds", {}),
			}
	if PetManager and ps is Dictionary and PetManager.has_method("apply_home_save_snapshot"):
		PetManager.apply_home_save_snapshot(ps as Dictionary)
	var ha: Variant = data.get("homestead_agents", {})
	_homestead_agents_runtime = (ha as Dictionary).duplicate(true) if ha is Dictionary else {}
	_homestead_agents_saved_unix = int(data.get("homestead_agents_unix", 0))
	_prune_homestead_agents_not_stationed()
	var soil: Variant = data.get("soil", {})
	_pending_soil_snapshot = soil as Dictionary if soil is Dictionary else {}
	call_deferred("_apply_pending_soil_snapshot")


func get_homestead_agent_runtime_for_instance(instance_id: String) -> Dictionary:
	var iid := instance_id.strip_edges()
	if iid.is_empty():
		return {}
	var v: Variant = _homestead_agents_runtime.get(iid, null)
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


## 看家寵批次生成時呼叫一次：回傳「自上次存檔寫入時間」起經過的整數秒，並把錨點設為現在（同一段連續遊玩不重複扣）。
func consume_homestead_agents_offline_elapsed_sec() -> int:
	var now := int(Time.get_unix_time_from_system())
	if _homestead_agents_saved_unix <= 0:
		return 0
	var e := maxi(0, now - _homestead_agents_saved_unix)
	_homestead_agents_saved_unix = now
	return e


## 重建看家視覺（refresh）前呼叫：把目前場上 agent 寫入快取，避免新實例套用過期快照。
func flush_homestead_agent_runtime_from_scene() -> void:
	_merge_homestead_agent_runtime_from_scene()


func _merge_homestead_agent_runtime_from_scene() -> void:
	var captured := _capture_homestead_agent_runtime()
	for k in captured.keys():
		_homestead_agents_runtime[str(k)] = captured[k]


func _prune_homestead_agents_not_stationed() -> void:
	if PetManager == null:
		return
	var keep := {}
	for x in PetManager.stationed_instance_order:
		keep[str(x).strip_edges()] = true
	for k in _homestead_agents_runtime.keys():
		if not keep.has(str(k)):
			_homestead_agents_runtime.erase(k)


func _capture_homestead_agent_runtime() -> Dictionary:
	var out: Dictionary = {}
	var tree := get_tree()
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("homestead_station_visual"):
		if not is_instance_valid(n):
			continue
		if not n.has_method("get_runtime_save_snapshot"):
			continue
		var snap: Variant = n.call("get_runtime_save_snapshot")
		if snap is Dictionary:
			var d := snap as Dictionary
			var iid := str(d.get("instance_id", "")).strip_edges()
			if not iid.is_empty():
				out[iid] = d.duplicate(true)
	return out


func _capture_soil_snapshot() -> Dictionary:
	var out: Dictionary = {}
	var tree := get_tree()
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("homestead_soil_plot"):
		if not is_instance_valid(n):
			continue
		if not n.has_method("get_home_save_snapshot"):
			continue
		out[str((n as Node).get_path())] = n.call("get_home_save_snapshot")
	return out


func _apply_pending_soil_snapshot() -> void:
	if _pending_soil_snapshot.is_empty():
		return
	var tree := get_tree()
	if tree == null:
		return
	var applied_keys: Array[String] = []
	for n in tree.get_nodes_in_group("homestead_soil_plot"):
		if not is_instance_valid(n):
			continue
		if not n.has_method("apply_home_save_snapshot"):
			continue
		var key := str((n as Node).get_path())
		if not _pending_soil_snapshot.has(key):
			continue
		var payload: Variant = _pending_soil_snapshot.get(key, {})
		if payload is Dictionary:
			n.call("apply_home_save_snapshot", payload)
			applied_keys.append(key)
	for k in applied_keys:
		_pending_soil_snapshot.erase(k)
