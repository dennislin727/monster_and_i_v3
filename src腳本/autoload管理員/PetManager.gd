extends Node

const PARTY_SLOT_COUNT := 3
const DEBUG_HOMESTEAD_STATION_LOG := false

var captured_pets: Array[PetResource] = []
var active_pet: PetResource = null
## 出戰三槽，索引 0..2；空槽為 null。新出戰一律填第一個空槽，不遞補。
var party_slots: Array = []
var _instance_id_counter: int = 0
## 開局寵物包（新路徑可多列同檔，方便三槽同種測手感）；已存在存檔時不會執行種子
const STARTER_PET_PATHS: Array[String] = [
	"res://resources身分證/pet/slime_green_pet.tres",
	"res://resources身分證/pet/slime_green_pet.tres",
	"res://resources身分證/pet/slime_green_pet.tres",
]
const DUDU_PET_TEMPLATE := "res://resources身分證/pet/dudu_pet.tres"
const BABY_BIRD_PET_TEMPLATE := "res://resources身分證/pet/baby_bird_pet.tres"
## 僅本機測試：開局強制塞一隻寶寶鳥進背包。**正式給玩家務必維持 false**（封印／取得管道另接）。
const DEBUG_ENSURE_BABY_BIRD_FOR_TEST := true

## 首次從家園區域離開後取得嘟嘟（僅一次）；存檔載入還原。
var first_homestead_depart_dudu_done: bool = false

## 家園內「放置」寵物：順序對應場上站位；勿與編隊並存同一隻。
var stationed_instance_order: Array[String] = []
## instance_id -> PackedStringArray of item_id（種子佇列）
var stationed_seed_queues: Dictionary = {}

var is_deployed: bool:
	get:
		return _first_filled_party_slot_index() >= 0


var deployed_pet: PetResource:
	get:
		var i := _first_filled_party_slot_index()
		return party_slots[i] as PetResource if i >= 0 else null


func _ready() -> void:
	_init_party_slots_empty()
	if SignalBus and not SignalBus.seal_attempt_finished.is_connected(_on_seal_attempt_finished):
		SignalBus.seal_attempt_finished.connect(_on_seal_attempt_finished)
	if SignalBus and not SignalBus.pet_active_requested.is_connected(_on_pet_active_requested):
		SignalBus.pet_active_requested.connect(_on_pet_active_requested)
	if SignalBus and not SignalBus.pet_deploy_requested.is_connected(_on_pet_deploy_requested):
		SignalBus.pet_deploy_requested.connect(_on_pet_deploy_requested)
	if SignalBus and not SignalBus.pet_recall_requested.is_connected(_on_pet_recall_requested):
		SignalBus.pet_recall_requested.connect(_on_pet_recall_requested)
	if SignalBus and not SignalBus.pet_party_slot_recall_requested.is_connected(_on_party_slot_recall_requested):
		SignalBus.pet_party_slot_recall_requested.connect(_on_party_slot_recall_requested)
	if SignalBus and not SignalBus.pet_release_requested.is_connected(_on_pet_release_requested):
		SignalBus.pet_release_requested.connect(_on_pet_release_requested)
	if SignalBus and not SignalBus.pet_nickname_change_requested.is_connected(_on_pet_nickname_change_requested):
		SignalBus.pet_nickname_change_requested.connect(_on_pet_nickname_change_requested)
	if SignalBus and not SignalBus.pet_homestead_station_requested.is_connected(_on_pet_homestead_station_requested):
		SignalBus.pet_homestead_station_requested.connect(_on_pet_homestead_station_requested)
	if SignalBus and not SignalBus.pet_sent_to_home_requested.is_connected(_on_pet_sent_to_home_requested):
		SignalBus.pet_sent_to_home_requested.connect(_on_pet_sent_to_home_requested)
	if SignalBus and not SignalBus.pet_evolution_requested.is_connected(_on_pet_evolution_requested):
		SignalBus.pet_evolution_requested.connect(_on_pet_evolution_requested)
	if SaveGameManager != null and SaveGameManager.has_pending_save():
		# 寵物清單須等 SaveGameManager.apply_save_snapshot() 還原後再處理；見 apply_save_snapshot 末尾。
		return
	_seed_starter_pets()
	_repair_missing_pet_instance_ids()
	_ensure_debug_baby_bird_for_test()


func _init_party_slots_empty() -> void:
	party_slots.clear()
	for __i in PARTY_SLOT_COUNT:
		party_slots.append(null)


func _first_filled_party_slot_index() -> int:
	for i in party_slots.size():
		if party_slots[i] != null:
			return i
	return -1


func find_party_slot_for_pet(pet_data: PetResource) -> int:
	if pet_data == null:
		return -1
	for i in party_slots.size():
		var slot_p: PetResource = party_slots[i] as PetResource
		if slot_p == null:
			continue
		if slot_p == pet_data:
			return i
		if not pet_data.instance_id.strip_edges().is_empty() and slot_p.instance_id == pet_data.instance_id:
			return i
	return -1


func is_pet_on_party(pet_data: PetResource) -> bool:
	return find_party_slot_for_pet(pet_data) >= 0


func find_first_empty_party_slot() -> int:
	for i in party_slots.size():
		if party_slots[i] == null:
			return i
	return -1


## HealthComponent.get_instance_id()：其他寵物詠唱中、尚未結算的回復量預約（避免多隻同選最低比而溢補）
var _party_heal_pending: Dictionary = {}


func party_heal_pending_for(hc: HealthComponent) -> int:
	if hc == null or not is_instance_valid(hc):
		return 0
	var id := hc.get_instance_id()
	return int(_party_heal_pending.get(id, 0))


func party_heal_pending_add(hc: HealthComponent, amount: int) -> void:
	if hc == null or amount <= 0 or not is_instance_valid(hc):
		return
	var id := hc.get_instance_id()
	_party_heal_pending[id] = int(_party_heal_pending.get(id, 0)) + amount


func party_heal_pending_remove_by_id(instance_id: int, amount: int) -> void:
	if instance_id == 0 or amount <= 0:
		return
	var v := int(_party_heal_pending.get(instance_id, 0)) - amount
	if v <= 0:
		_party_heal_pending.erase(instance_id)
	else:
		_party_heal_pending[instance_id] = v


func _emit_party_state() -> void:
	if not SignalBus:
		return
	SignalBus.pet_deployed_changed.emit(is_deployed)
	SignalBus.pet_party_changed.emit()


func _on_seal_attempt_finished(success: bool, data: Resource, sealed_body: Node) -> void:
	if not success:
		return

	var monster_data := data as MonsterResource
	if monster_data == null:
		return
	if monster_data.pet_data != null and monster_data.pet_data.pet_id == "baby_bird":
		if not monster_data.participates_in_combat and ProgressionManager != null:
			if sealed_body != null and sealed_body.has_method("get_lake_ambient_save_slot"):
				ProgressionManager.register_lake_ambient_baby_bird_slot_cleared(sealed_body.get_lake_ambient_save_slot())

	var pet_template: PetResource = monster_data.pet_data
	var pet_data: PetResource
	if pet_template == null:
		pet_data = _make_pet_from_monster(monster_data)
	else:
		# 封印入庫時一定要做「個體化」：同一個 .tres 可能被捕捉多次，不能共用同一個 Resource 參考
		pet_data = pet_template.duplicate(true) as PetResource
		_ensure_pet_inherits_monster_visual(pet_data, monster_data)
		if pet_data.nickname.strip_edges() == "":
			pet_data.nickname = pet_data.pet_name
	_assign_pet_instance_id_if_missing(pet_data)

	captured_pets.append(pet_data)
	if active_pet == null:
		_set_active_pet(pet_data)

	if SignalBus:
		SignalBus.pet_captured.emit(pet_data)
		SignalBus.pet_roster_changed.emit()


func _make_pet_from_monster(monster_data: MonsterResource) -> PetResource:
	var pet := PetResource.new()
	pet.pet_id = _make_pet_id(monster_data)
	_assign_pet_instance_id_if_missing(pet)
	pet.pet_name = monster_data.monster_name
	pet.icon = null
	pet.sprite_frames = monster_data.sprite_frames
	return pet


func _repair_missing_pet_instance_ids() -> void:
	for pet in captured_pets:
		_assign_pet_instance_id_if_missing(pet)


func _assign_pet_instance_id_if_missing(pet_data: PetResource) -> void:
	if pet_data == null:
		return
	if not pet_data.instance_id.strip_edges().is_empty():
		return
	_instance_id_counter += 1
	var unix_s := Time.get_unix_time_from_system()
	pet_data.instance_id = "pet_%s_%04d" % [str(unix_s), _instance_id_counter]


func _seed_starter_pets() -> void:
	var changed := false
	var path_ord: Dictionary = {}
	for p in STARTER_PET_PATHS:
		if not ResourceLoader.exists(p):
			continue
		var template := load(p) as PetResource
		if template == null:
			continue
		var source_id := template.pet_id.strip_edges()
		if source_id.is_empty():
			continue
		var dup_count := STARTER_PET_PATHS.count(p)
		if dup_count <= 1 and _has_pet_with_id(source_id):
			continue
		var seeded := template.duplicate(true) as PetResource
		if seeded == null:
			continue
		_assign_pet_instance_id_if_missing(seeded)
		if seeded.nickname.strip_edges() == "":
			seeded.nickname = seeded.pet_name
		if dup_count > 1:
			var k: int = int(path_ord.get(p, 0)) + 1
			path_ord[p] = k
			var base_nick := seeded.nickname.strip_edges()
			seeded.nickname = "%s·%d" % [base_nick, k]
		captured_pets.append(seeded)
		if active_pet == null:
			active_pet = seeded
		changed = true
	if changed and SignalBus:
		SignalBus.pet_roster_changed.emit()
		SignalBus.pet_active_changed.emit(active_pet)


func _has_pet_with_id(pet_id: String) -> bool:
	var clean_id := pet_id.strip_edges()
	if clean_id.is_empty():
		return false
	for p in captured_pets:
		if p == null:
			continue
		if p.pet_id == clean_id:
			return true
	return false


func _ensure_debug_baby_bird_for_test() -> void:
	if not DEBUG_ENSURE_BABY_BIRD_FOR_TEST:
		return
	if _roster_has_pet_id("baby_bird"):
		return
	if not ResourceLoader.exists(BABY_BIRD_PET_TEMPLATE):
		push_warning("[PetManager] baby_bird 測試模板不存在：%s" % BABY_BIRD_PET_TEMPLATE)
		return
	var tpl := load(BABY_BIRD_PET_TEMPLATE) as PetResource
	if tpl == null:
		push_warning("[PetManager] baby_bird 測試模板載入失敗：%s" % BABY_BIRD_PET_TEMPLATE)
		return
	var bb := tpl.duplicate(true) as PetResource
	if bb == null:
		return
	_assign_pet_instance_id_if_missing(bb)
	if bb.nickname.strip_edges() == "":
		bb.nickname = bb.pet_name if bb.pet_name.strip_edges() != "" else "寶寶鳥"
	captured_pets.append(bb)
	if active_pet == null:
		_set_active_pet(bb)
	if SignalBus:
		SignalBus.pet_captured.emit(bb)
		SignalBus.pet_roster_changed.emit()


func get_deployed_pet_binding_key() -> String:
	if not is_deployed:
		return ""
	var i0 := _first_filled_party_slot_index()
	if i0 < 0:
		return ""
	var p: PetResource = party_slots[i0] as PetResource
	if p == null:
		return ""
	if p.instance_id.strip_edges().is_empty():
		_assign_pet_instance_id_if_missing(p)
	return "pet:%s" % p.instance_id


func get_party_slot_binding_key(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= party_slots.size():
		return ""
	var p: PetResource = party_slots[slot_index] as PetResource
	if p == null:
		return ""
	if p.instance_id.strip_edges().is_empty():
		_assign_pet_instance_id_if_missing(p)
	return "pet:%s" % p.instance_id


func get_deployed_party_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in party_slots.size():
		var p: PetResource = party_slots[i] as PetResource
		if p == null:
			continue
		out.append({"slot": i, "pet": p})
	return out


func get_party_slot_index_for_instance_id(iid: String) -> int:
	if iid.strip_edges().is_empty():
		return -1
	for i in party_slots.size():
		var p: PetResource = party_slots[i] as PetResource
		if p != null and p.instance_id == iid:
			return i
	return -1


func find_pet_by_instance_id(iid: String) -> PetResource:
	return _find_pet_by_instance_id(iid)


func is_pet_stationed(pet_data: PetResource) -> bool:
	if pet_data == null or pet_data.instance_id.strip_edges().is_empty():
		return false
	return stationed_instance_order.has(pet_data.instance_id)


func get_stationed_pets_ordered() -> Array[PetResource]:
	var out: Array[PetResource] = []
	for iid in stationed_instance_order:
		var p := _find_pet_by_instance_id(iid)
		if p == null:
			var parts := str(iid).split("_")
			var tail := parts[parts.size() - 1] if parts.size() > 0 else ""
			if not tail.is_empty():
				for cp in captured_pets:
					if cp == null:
						continue
					var cparts := cp.instance_id.split("_")
					var ctail := cparts[cparts.size() - 1] if cparts.size() > 0 else ""
					if ctail == tail:
						p = cp
						break
		if p != null:
			out.append(p)
	return out


func try_station_pet(pet_data: PetResource) -> bool:
	if pet_data == null or HomeManager == null:
		push_warning("[PetManager][station] rejected: pet or HomeManager is null")
		return false
	if not HomeManager.in_homestead:
		push_warning("[PetManager][station] rejected: player not in homestead")
		return false
	if not _is_on_roster(pet_data):
		push_warning("[PetManager][station] rejected: pet not on roster")
		return false
	var party_i := find_party_slot_for_pet(pet_data)
	if party_i >= 0:
		party_slots[party_i] = null
		_emit_party_state()
	if is_pet_stationed(pet_data):
		push_warning("[PetManager][station] rejected: pet already stationed %s" % pet_data.instance_id)
		return false
	if pet_data.instance_id.strip_edges().is_empty():
		_assign_pet_instance_id_if_missing(pet_data)
	var iid := pet_data.instance_id
	stationed_instance_order.append(iid)
	if not stationed_seed_queues.has(iid):
		stationed_seed_queues[iid] = PackedStringArray()
	if DEBUG_HOMESTEAD_STATION_LOG:
		print("[PetManager][station] stationed iid=%s stationed_count=%d" % [iid, stationed_instance_order.size()])
	if active_pet == pet_data:
		var next: PetResource = null
		for p in captured_pets:
			if p == null or is_pet_stationed(p):
				continue
			next = p
			break
		_set_active_pet(next)
	if SignalBus:
		SignalBus.pet_roster_changed.emit()
		_emit_home_station_state()
	return true


func unstation_pet(instance_id: String) -> void:
	var iid := instance_id.strip_edges()
	if iid.is_empty():
		return
	var idx := stationed_instance_order.find(iid)
	if idx >= 0:
		stationed_instance_order.remove_at(idx)
	stationed_seed_queues.erase(iid)
	if SignalBus:
		SignalBus.pet_roster_changed.emit()
		_emit_home_station_state()


## 家園收回語意：從駐留回背包視為重新入列，回到 captured_pets 尾端。
## 僅供家園收回流程呼叫；不影響出戰「休息」語意。
func unstation_pet_to_roster_tail(instance_id: String) -> void:
	var iid := instance_id.strip_edges()
	if iid.is_empty():
		return
	var pet := _find_pet_by_instance_id(iid)
	unstation_pet(iid)
	if pet == null:
		return
	var idx := captured_pets.find(pet)
	if idx < 0:
		return
	if idx == captured_pets.size() - 1:
		return
	captured_pets.remove_at(idx)
	captured_pets.append(pet)
	if SignalBus:
		SignalBus.pet_roster_changed.emit()


func get_seed_queue_item_ids(instance_id: String) -> PackedStringArray:
	var iid := instance_id.strip_edges()
	if stationed_seed_queues.has(iid):
		return stationed_seed_queues[iid]
	return PackedStringArray()


func append_seed_to_station_queue(instance_id: String, item_id: String) -> void:
	var iid := instance_id.strip_edges()
	var seed_id := item_id.strip_edges()
	if iid.is_empty() or seed_id.is_empty():
		return
	if InventoryManager == null or not InventoryManager.try_consume_item_by_id(seed_id, 1):
		return
	if not stationed_seed_queues.has(iid):
		stationed_seed_queues[iid] = PackedStringArray()
	var q: PackedStringArray = stationed_seed_queues[iid]
	q.append(seed_id)
	stationed_seed_queues[iid] = q
	if SignalBus:
		_emit_home_station_state()


func _emit_home_station_state() -> void:
	if not SignalBus:
		return
	SignalBus.pet_home_roster_changed.emit()
	SignalBus.homestead_station_visuals_refresh.emit()


func on_first_leave_homestead_if_needed() -> void:
	if first_homestead_depart_dudu_done:
		return
	first_homestead_depart_dudu_done = true
	if _roster_has_pet_id("dudu"):
		return
	if not ResourceLoader.exists(DUDU_PET_TEMPLATE):
		push_warning("[PetManager] 嘟嘟模板不存在：%s" % DUDU_PET_TEMPLATE)
		return
	var tpl := load(DUDU_PET_TEMPLATE) as PetResource
	if tpl == null:
		return
	var dudu := tpl.duplicate(true) as PetResource
	if dudu == null:
		return
	_assign_pet_instance_id_if_missing(dudu)
	if dudu.nickname.strip_edges() == "":
		dudu.nickname = dudu.pet_name
	captured_pets.append(dudu)
	if active_pet == null:
		active_pet = dudu
	if DiaryManager:
		DiaryManager.try_unlock_career("career_first_pet_dudu")
	if SignalBus:
		SignalBus.pet_captured.emit(dudu)
		SignalBus.pet_roster_changed.emit()
		SignalBus.pet_active_changed.emit(active_pet)


func _roster_has_pet_id(pet_id: String) -> bool:
	var clean := pet_id.strip_edges()
	for p in captured_pets:
		if p != null and p.pet_id == clean:
			return true
	return false


func get_owner_key_slot_label(owner_key: String) -> String:
	if not owner_key.begins_with("pet:"):
		return ""
	var iid := owner_key.substr(4)
	var s := get_party_slot_index_for_instance_id(iid)
	if s < 0:
		return "出戰寵物"
	return "槽%d" % (s + 1)


func get_party_luck_bonus_rate() -> float:
	var bonus := 0.0
	for p in party_slots:
		var pet := p as PetResource
		if pet == null:
			continue
		bonus += clampf(pet.luck_bonus_rate, 0.0, 1.0)
	return clampf(bonus, 0.0, 1.0)


## .tres 裡的 PetResource 常只填 icon 而沒有 sprite_frames，出戰會變透明
func _ensure_pet_inherits_monster_visual(pet_data: PetResource, monster_data: MonsterResource) -> void:
	if pet_data == null or monster_data == null:
		return
	if pet_data.sprite_frames != null:
		return
	if monster_data.sprite_frames != null:
		pet_data.sprite_frames = monster_data.sprite_frames


func _make_pet_id(monster_data: MonsterResource) -> String:
	if monster_data.resource_path != "":
		return monster_data.resource_path.get_file().get_basename()
	return monster_data.monster_name.to_lower().replace(" ", "_")


func _on_pet_active_requested(pet_data: PetResource) -> void:
	if pet_data == null:
		return
	if not captured_pets.has(pet_data):
		return
	_set_active_pet(pet_data)


func _on_pet_deploy_requested(pet_data: PetResource) -> void:
	if pet_data == null:
		return
	if is_pet_stationed(pet_data):
		push_warning("[PetManager] 出戰遭拒：寵物正放置於家園。")
		return
	if not _is_on_roster(pet_data):
		push_warning("[PetManager] 出戰遭拒：寵物不在 captured_pets（或 pet_id 對不到）。")
		return
	if find_party_slot_for_pet(pet_data) >= 0:
		return
	var slot := find_first_empty_party_slot()
	if slot < 0:
		push_warning("[PetManager] 出戰槽已滿（最多 %d 隻）。" % PARTY_SLOT_COUNT)
		return
	party_slots[slot] = pet_data
	_set_active_pet(pet_data)
	_emit_party_state()


func _is_on_roster(pet_data: PetResource) -> bool:
	if captured_pets.has(pet_data):
		return true
	if pet_data.pet_id.is_empty():
		return false
	for p in captured_pets:
		if p != null and p.pet_id == pet_data.pet_id:
			return true
	return false


func _clear_party_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= party_slots.size():
		return
	party_slots[slot_index] = null
	_emit_party_state()


func _on_pet_recall_requested() -> void:
	if active_pet == null:
		return
	var slot := find_party_slot_for_pet(active_pet)
	if slot < 0:
		return
	_clear_party_slot(slot)


func _on_party_slot_recall_requested(slot_index: int) -> void:
	_clear_party_slot(slot_index)


func _on_pet_release_requested(pet_data: PetResource) -> void:
	if pet_data == null:
		return
	if is_pet_stationed(pet_data):
		unstation_pet(pet_data.instance_id)
	var idx := captured_pets.find(pet_data)
	if idx < 0:
		return
	for i in party_slots.size():
		var sp: PetResource = party_slots[i] as PetResource
		if sp != null and (sp == pet_data or (
			not pet_data.instance_id.strip_edges().is_empty()
			and sp.instance_id == pet_data.instance_id
		)):
			party_slots[i] = null
	_emit_party_state()
	captured_pets.remove_at(idx)
	if active_pet == pet_data:
		active_pet = captured_pets[0] if captured_pets.size() > 0 else null
		if SignalBus:
			SignalBus.pet_active_changed.emit(active_pet)
	if SignalBus:
		SignalBus.pet_roster_changed.emit()


func _set_active_pet(pet_data: PetResource) -> void:
	if active_pet == pet_data:
		return
	active_pet = pet_data
	if SignalBus:
		SignalBus.pet_active_changed.emit(active_pet)


func _on_pet_nickname_change_requested(pet_data: PetResource, nickname: String) -> void:
	if pet_data == null or not captured_pets.has(pet_data):
		return
	var n := nickname.strip_edges()
	if n.length() > 12:
		n = n.substr(0, 12)
	if n.is_empty():
		pet_data.nickname = pet_data.pet_name if pet_data.pet_name.strip_edges() != "" else pet_data.pet_id
	else:
		pet_data.nickname = n
	if SignalBus:
		SignalBus.pet_nickname_changed.emit(pet_data)
		SignalBus.pet_roster_changed.emit()
		if active_pet == pet_data:
			SignalBus.pet_active_changed.emit(active_pet)
		SignalBus.pet_party_changed.emit()


func _on_pet_homestead_station_requested(pet_data: PetResource) -> void:
	try_station_pet(pet_data)


func _on_pet_sent_to_home_requested(pet_data: PetResource) -> void:
	# 敘事語意入口，暫與 station 同邏輯；未來可在此加演出/任務分流。
	try_station_pet(pet_data)


func _on_pet_evolution_requested(pet_data: PetResource) -> void:
	if pet_data == null:
		return
	push_warning("[PetManager] 進化系統尚未實作，已接收請求：%s" % pet_data.instance_id)


func get_save_snapshot() -> Dictionary:
	var arr: Array = []
	for p in captured_pets:
		if p != null:
			arr.append(_serialize_pet(p))
	var aid := ""
	if active_pet != null:
		aid = active_pet.instance_id
	var party_ids: Array[String] = []
	for i in PARTY_SLOT_COUNT:
		var pp: PetResource = party_slots[i] as PetResource if i < party_slots.size() else null
		if pp != null and not pp.instance_id.strip_edges().is_empty():
			party_ids.append(pp.instance_id)
		else:
			party_ids.append("")
	return {
		"pets": arr,
		"active_instance_id": aid,
		"party_instance_ids": party_ids,
		"id_counter": _instance_id_counter,
		"first_homestead_depart_dudu_done": first_homestead_depart_dudu_done,
	}


func apply_save_snapshot(data: Dictionary) -> void:
	captured_pets.clear()
	active_pet = null
	_init_party_slots_empty()
	_instance_id_counter = int(data.get("id_counter", 0))
	first_homestead_depart_dudu_done = bool(data.get("first_homestead_depart_dudu_done", false))
	var arr: Variant = data.get("pets", [])
	if arr is Array:
		for item in arr as Array:
			if item is Dictionary:
				var pd := _pet_from_dict(item as Dictionary)
				if pd != null:
					captured_pets.append(pd)
	var aid := str(data.get("active_instance_id", ""))
	active_pet = _find_pet_by_instance_id(aid)
	var pids: Variant = data.get("party_instance_ids", [])
	if pids is Array and (pids as Array).size() >= PARTY_SLOT_COUNT:
		for i in PARTY_SLOT_COUNT:
			var sid := str((pids as Array)[i])
			party_slots[i] = _find_pet_by_instance_id(sid) if not sid.strip_edges().is_empty() else null
	else:
		var legacy := str(data.get("deployed_instance_id", ""))
		if not legacy.strip_edges().is_empty():
			var dp := _find_pet_by_instance_id(legacy)
			if dp != null:
				party_slots[0] = dp
	_repair_missing_pet_instance_ids()
	_ensure_debug_baby_bird_for_test()
	_emit_party_state()
	if SignalBus:
		SignalBus.homestead_station_visuals_refresh.emit()


func get_home_save_snapshot() -> Dictionary:
	var seeds_ser: Dictionary = {}
	for k in stationed_seed_queues.keys():
		var ps: PackedStringArray = stationed_seed_queues[k]
		var serial: Array = []
		for s in ps:
			serial.append(str(s))
		seeds_ser[str(k)] = serial
	return {
		"stationed_order": stationed_instance_order.duplicate(),
		"stationed_seeds": seeds_ser,
	}


func apply_home_save_snapshot(data: Dictionary) -> void:
	stationed_instance_order.clear()
	var so: Variant = data.get("stationed_order", [])
	if so is Array:
		for x in so as Array:
			var iid := str(x).strip_edges()
			if iid.is_empty():
				continue
			var found := _find_pet_by_instance_id(iid)
			if found != null:
				stationed_instance_order.append(iid)
				continue
			# 容錯：舊存檔或格式差異時，嘗試以尾段序號對齊（pet_xxx_0001）
			var parts := iid.split("_")
			var tail := parts[parts.size() - 1] if parts.size() > 0 else ""
			if tail.is_empty():
				continue
			for p in captured_pets:
				if p == null:
					continue
				var pid := p.instance_id.strip_edges()
				if pid.is_empty():
					continue
				var pparts := pid.split("_")
				var ptail := pparts[pparts.size() - 1] if pparts.size() > 0 else ""
				if ptail == tail:
					stationed_instance_order.append(pid)
					break
	stationed_seed_queues.clear()
	var ssd: Variant = data.get("stationed_seeds", {})
	if ssd is Dictionary:
		for kk in (ssd as Dictionary).keys():
			var iid2 := str(kk).strip_edges()
			if iid2.is_empty():
				continue
			if not stationed_instance_order.has(iid2):
				continue
			var sq: PackedStringArray = PackedStringArray()
			var av: Variant = (ssd as Dictionary)[kk]
			if av is Array:
				for item in av as Array:
					sq.append(str(item))
			stationed_seed_queues[iid2] = sq
	if SignalBus:
		_emit_home_station_state()


func _find_pet_by_instance_id(iid: String) -> PetResource:
	if iid.strip_edges().is_empty():
		return null
	for p in captured_pets:
		if p != null and p.instance_id == iid:
			return p
	return null


func _serialize_pet(p: PetResource) -> Dictionary:
	var skills: Array = []
	for e in p.skills:
		if e is PetSkillEntry:
			var pe := e as PetSkillEntry
			if pe.skill != null and pe.skill.resource_path != "":
				skills.append({"path": pe.skill.resource_path, "level": pe.skill_level})
	var tpl := ""
	if p.resource_path != "" and ResourceLoader.exists(p.resource_path):
		tpl = p.resource_path
	else:
		for sp in STARTER_PET_PATHS:
			if not ResourceLoader.exists(sp):
				continue
			var t := load(sp) as PetResource
			if t != null and t.pet_id == p.pet_id:
				tpl = sp
				break
		# 執行期 duplicate 的寵物常無 resource_path；STARTER 只有史萊姆，baby_bird 會變成 template 空字串 → 讀檔後無圖集、退回史萊姆。
		if tpl == "" and p.pet_id == "baby_bird" and ResourceLoader.exists(BABY_BIRD_PET_TEMPLATE):
			tpl = BABY_BIRD_PET_TEMPLATE
	return {
		"template_path": tpl,
		"pet_id": p.pet_id,
		"instance_id": p.instance_id,
		"nickname": p.nickname,
		"pet_name": p.pet_name,
		"level": p.level,
		"experience": p.experience,
		"story": p.story,
		"max_hp": p.max_hp,
		"heal_amount": p.heal_amount,
		"heal_cooldown": p.heal_cooldown,
		"luck_bonus_rate": p.luck_bonus_rate,
		"follow_distance": p.follow_distance,
		"follow_speed_mult": p.follow_speed_mult,
		"skills": skills,
	}


func _pet_from_dict(d: Dictionary) -> PetResource:
	var p: PetResource = null
	var tpl: String = str(d.get("template_path", ""))
	if tpl != "" and ResourceLoader.exists(tpl):
		var t := load(tpl) as PetResource
		if t != null:
			p = t.duplicate(true) as PetResource
	if p == null:
		p = PetResource.new()
	p.pet_id = str(d.get("pet_id", ""))
	p.instance_id = str(d.get("instance_id", ""))
	p.nickname = str(d.get("nickname", ""))
	p.pet_name = str(d.get("pet_name", ""))
	p.level = int(d.get("level", 1))
	p.experience = int(d.get("experience", 0))
	p.story = str(d.get("story", ""))
	p.max_hp = int(d.get("max_hp", 0))
	p.heal_amount = int(d.get("heal_amount", 15))
	p.heal_cooldown = float(d.get("heal_cooldown", 10.0))
	p.luck_bonus_rate = float(d.get("luck_bonus_rate", 0.0))
	p.follow_distance = float(d.get("follow_distance", 60.0))
	p.follow_speed_mult = float(d.get("follow_speed_mult", 1.1))
	p.skills.clear()
	var sk: Variant = d.get("skills", [])
	if sk is Array:
		for s in sk as Array:
			if s is Dictionary:
				var path := str((s as Dictionary).get("path", ""))
				if path.is_empty() or not ResourceLoader.exists(path):
					continue
				var skr := load(path)
				if not (skr is SkillResource):
					continue
				var entry := PetSkillEntry.new()
				entry.skill = skr
				entry.skill_level = int((s as Dictionary).get("level", 1))
				p.skills.append(entry)
	_rehydrate_pet_sprite_frames_if_missing(p)
	return p


## 舊存檔或 template_path 為空時，PetResource 可能沒有 sprite_frames；出戰會誤用史萊姆後備圖。
func _rehydrate_pet_sprite_frames_if_missing(p: PetResource) -> void:
	if p == null or p.sprite_frames != null:
		return
	if p.pet_id == "baby_bird":
		if ResourceLoader.exists(BABY_BIRD_PET_TEMPLATE):
			var tpet := load(BABY_BIRD_PET_TEMPLATE) as PetResource
			if tpet != null and tpet.sprite_frames != null:
				p.sprite_frames = tpet.sprite_frames
				return
		const MPATH := "res://resources身分證/monster/baby_bird_monster.tres"
		if ResourceLoader.exists(MPATH):
			var m := load(MPATH) as MonsterResource
			if m != null and m.sprite_frames != null:
				p.sprite_frames = m.sprite_frames
