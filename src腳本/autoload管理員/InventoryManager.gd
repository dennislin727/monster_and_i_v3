extends Node
## 玩家背包（簡易版）：聚合採集與之後取得的 ItemResource；UI 依分類顯示。

signal inventory_changed

## 金幣與道具分離，單一真相（UI 顯示於背包副標列）。
var gold: int = 0

## item_id -> { "resource": ItemResource, "count": int }
var _stacks: Dictionary = {}
## headwear_id -> owner key（player:main / pet:<instance_id>）
var _headwear_owner_by_id: Dictionary = {}
const PLAYER_BINDING_KEY := "player:main"
const STARTER_HEADWEAR_PATHS: Array[String] = [
	"res://resources身分證/headwear/slime_hat.tres"
]

## 暫時測試：開局塞入多種測試道具（背包格／捲動視覺）。上線前改 false 或刪除此區與 _seed_debug_test_items。
const DEBUG_SEED_TEST_ITEMS := true
const DEBUG_TEST_ITEM_PATHS: Array[String] = [
	"res://resources身分證/items/test_1.tres",
	"res://resources身分證/items/test_2.tres",
	"res://resources身分證/items/test_3.tres",
	"res://resources身分證/items/test_4.tres",
	"res://resources身分證/items/test_5.tres",
	"res://resources身分證/items/test_6.tres",
	"res://resources身分證/items/test_7.tres",
	"res://resources身分證/items/test_8.tres",
	"res://resources身分證/items/test_9.tres",
	"res://resources身分證/items/test_10.tres",
	"res://resources身分證/items/test_11.tres",
	"res://resources身分證/items/test_12.tres",
	"res://resources身分證/items/test_13.tres",
	"res://resources身分證/items/test_14.tres",
	"res://resources身分證/items/test_15.tres",
	"res://resources身分證/items/test_16.tres",
	"res://resources身分證/items/test_17.tres",
	"res://resources身分證/items/test_18.tres",
]

func _ready() -> void:
	if SignalBus and not SignalBus.item_collected.is_connected(_on_item_collected):
		SignalBus.item_collected.connect(_on_item_collected)
	if SignalBus and not SignalBus.inventory_grant_requested.is_connected(_on_inventory_grant_requested):
		SignalBus.inventory_grant_requested.connect(_on_inventory_grant_requested)
	if SaveGameManager != null and SaveGameManager.has_pending_save():
		return
	_seed_starter_headwear()
	_seed_debug_test_items()


func _on_item_collected(item_data: Resource) -> void:
	if not (item_data is ItemResource):
		return
	var ir := item_data as ItemResource
	if _stacks.has(ir.item_id):
		var entry: Dictionary = _stacks[ir.item_id]
		entry["count"] = int(entry["count"]) + 1
	else:
		_stacks[ir.item_id] = {"resource": ir, "count": 1}
	inventory_changed.emit()


func _on_inventory_grant_requested(item_id: String, amount: int) -> void:
	grant_item_stack_by_id(item_id, amount)


## 非採集途徑入庫（NPC／任務等）；使用 DataManager 模板堆疊
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	inventory_changed.emit()


func get_gold() -> int:
	return gold


func try_consume_item_by_id(item_id: String, amount: int) -> bool:
	var clean_id := item_id.strip_edges()
	if clean_id.is_empty() or amount <= 0:
		return false
	if not _stacks.has(clean_id):
		return false
	var entry: Dictionary = _stacks[clean_id]
	var c := int(entry.get("count", 0))
	if c < amount:
		return false
	c -= amount
	if c <= 0:
		_stacks.erase(clean_id)
	else:
		entry["count"] = c
	inventory_changed.emit()
	return true


## 種子／is_seed 道具列表（家園給寵物用）。
func get_seed_stack_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in _stacks.keys():
		var entry: Dictionary = _stacks[k]
		var r: Resource = entry.get("resource") as Resource
		if r == null or not (r is ItemResource):
			continue
		var ir := r as ItemResource
		if not ir.is_seed:
			continue
		out.append(entry)
	return out


func grant_item_stack_by_id(item_id: String, amount: int) -> void:
	var clean_id := item_id.strip_edges()
	if clean_id.is_empty() or amount <= 0:
		return
	var ir: ItemResource = DataManager.get_item(clean_id)
	if ir == null:
		push_warning("[InventoryManager] grant_item_stack_by_id: unknown item_id %s" % clean_id)
		return
	if _stacks.has(ir.item_id):
		var entry: Dictionary = _stacks[ir.item_id]
		entry["count"] = int(entry["count"]) + int(amount)
	else:
		_stacks[ir.item_id] = {"resource": ir, "count": int(amount)}
	inventory_changed.emit()

func _seed_starter_headwear() -> void:
	var changed := false
	for p in STARTER_HEADWEAR_PATHS:
		if not ResourceLoader.exists(p):
			continue
		var hr := load(p) as HeadwearResource
		if hr == null or hr.headwear_id.strip_edges().is_empty():
			continue
		if not _stacks.has(hr.headwear_id):
			_stacks[hr.headwear_id] = {"resource": hr, "count": 1}
			changed = true
	if changed:
		inventory_changed.emit()


func _seed_debug_test_items() -> void:
	if not DEBUG_SEED_TEST_ITEMS:
		return
	var changed := false
	for i in DEBUG_TEST_ITEM_PATHS.size():
		var p: String = DEBUG_TEST_ITEM_PATHS[i]
		if not ResourceLoader.exists(p):
			continue
		var ir := load(p) as ItemResource
		if ir == null or ir.item_id.strip_edges().is_empty():
			continue
		var add_count: int = (i % 9) + 1
		if _stacks.has(ir.item_id):
			var entry: Dictionary = _stacks[ir.item_id]
			entry["count"] = int(entry["count"]) + add_count
		else:
			_stacks[ir.item_id] = {"resource": ir, "count": add_count}
		changed = true
	if DEBUG_SEED_TEST_ITEMS:
		grant_item_stack_by_id("homestead_crop_demo", 10)
		changed = true
	if changed:
		inventory_changed.emit()


## 道具分頁：非 EQUIPMENT（材料、消耗品、任務、封印工具等）
func get_item_tab_entries() -> Array[Dictionary]:
	return _filter_entries(false)


## 頭飾分頁：ItemType.EQUIPMENT（日後可細分頭飾專用 Resource）
func get_headwear_tab_entries() -> Array[Dictionary]:
	return _filter_entries(true)


func _filter_entries(want_equipment: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in _stacks:
		var entry: Dictionary = _stacks[k]
		var r: Resource = entry.get("resource") as Resource
		if r == null:
			continue
		var is_headwear := false
		if r is HeadwearResource:
			is_headwear = true
		elif r is ItemResource:
			is_headwear = (r as ItemResource).type == ItemResource.ItemType.EQUIPMENT
		if is_headwear == want_equipment:
			out.append(entry)
	return out

func get_resource_by_id(resource_id: String) -> Resource:
	if resource_id.strip_edges().is_empty():
		return null
	if not _stacks.has(resource_id):
		return null
	var entry: Dictionary = _stacks[resource_id]
	return entry.get("resource") as Resource

func get_headwear_owner_key(headwear_id: String) -> String:
	if headwear_id.strip_edges().is_empty():
		return ""
	return str(_headwear_owner_by_id.get(headwear_id, ""))

func get_headwear_by_owner_key(owner_key: String) -> HeadwearResource:
	var clean_owner_key := owner_key.strip_edges()
	if clean_owner_key.is_empty():
		return null
	for headwear_id in _headwear_owner_by_id.keys():
		if str(_headwear_owner_by_id.get(headwear_id, "")) != clean_owner_key:
			continue
		return get_resource_by_id(str(headwear_id)) as HeadwearResource
	return null

func equip_headwear_to_owner(headwear: HeadwearResource, owner_key: String) -> bool:
	if headwear == null:
		return false
	var headwear_id := headwear.headwear_id.strip_edges()
	var clean_owner_key := owner_key.strip_edges()
	if headwear_id.is_empty() or clean_owner_key.is_empty():
		return false
	var current_owner := get_headwear_owner_key(headwear_id)
	# toggle：同一目標再點一次 -> 卸下
	if current_owner == clean_owner_key:
		unequip_headwear_by_id(headwear_id)
		return true
	if not _apply_headwear_to_owner(clean_owner_key, headwear):
		return false
	if not current_owner.is_empty():
		_clear_headwear_from_owner(current_owner, headwear)
	_headwear_owner_by_id[headwear_id] = clean_owner_key
	inventory_changed.emit()
	return true

func unequip_headwear_by_id(headwear_id: String) -> void:
	var clean_id := headwear_id.strip_edges()
	if clean_id.is_empty():
		return
	var owner_key := get_headwear_owner_key(clean_id)
	if owner_key.is_empty():
		return
	var headwear := get_resource_by_id(clean_id) as HeadwearResource
	_clear_headwear_from_owner(owner_key, headwear)
	_headwear_owner_by_id.erase(clean_id)
	inventory_changed.emit()

func _apply_headwear_to_owner(owner_key: String, headwear: HeadwearResource) -> bool:
	var target := _resolve_owner_node(owner_key)
	if target == null:
		return false
	target.set("equipped_headwear", headwear)
	if target.has_method("_update_headwear_visual"):
		target.call("_update_headwear_visual", true)
	return true

func _clear_headwear_from_owner(owner_key: String, expected_headwear: HeadwearResource = null) -> void:
	var target := _resolve_owner_node(owner_key)
	if target == null:
		return
	if expected_headwear != null:
		var equipped = target.get("equipped_headwear")
		if equipped != expected_headwear:
			return
	target.set("equipped_headwear", null)
	if target.has_method("_update_headwear_visual"):
		target.call("_update_headwear_visual", true)

func get_save_snapshot() -> Dictionary:
	var stacks: Dictionary = {}
	for k in _stacks.keys():
		var entry: Dictionary = _stacks[k]
		var r: Resource = entry.get("resource") as Resource
		var rp := ""
		if r != null:
			rp = r.resource_path
		stacks[str(k)] = {"count": int(entry.get("count", 1)), "res_path": rp}
	return {
		"stacks": stacks,
		"headwear_owners": _headwear_owner_by_id.duplicate(true),
		"gold": gold,
	}


func apply_save_snapshot(inv: Dictionary) -> void:
	_stacks.clear()
	_headwear_owner_by_id.clear()
	gold = maxi(0, int(inv.get("gold", 0)))
	var stacks: Variant = inv.get("stacks", {})
	if stacks is Dictionary:
		for k in (stacks as Dictionary).keys():
			var id := str(k)
			var ent: Variant = (stacks as Dictionary)[k]
			var count := 1
			var rp := ""
			if ent is Dictionary:
				count = int((ent as Dictionary).get("count", 1))
				rp = str((ent as Dictionary).get("res_path", ""))
			elif ent is int or ent is float:
				count = int(ent)
			var res: Resource = null
			if DataManager:
				res = DataManager.get_item(id) as Resource
			if res == null and not rp.is_empty() and ResourceLoader.exists(rp):
				res = load(rp) as Resource
			if res == null:
				push_warning("[InventoryManager] 存檔略過未知道具：%s" % id)
				continue
			_stacks[id] = {"resource": res, "count": count}
	var ho: Variant = inv.get("headwear_owners", {})
	if ho is Dictionary:
		for kk in (ho as Dictionary).keys():
			_headwear_owner_by_id[str(kk)] = str((ho as Dictionary)[kk])
	apply_saved_equipment_to_world()
	inventory_changed.emit()


func apply_saved_equipment_to_world() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var pl := tree.get_first_node_in_group("player")
	if pl:
		pl.set("equipped_headwear", null)
		if pl.has_method("_update_headwear_visual"):
			pl.call("_update_headwear_visual", true)
	for dep in tree.get_nodes_in_group("deployed_pet"):
		dep.set("equipped_headwear", null)
		if dep.has_method("_update_headwear_visual"):
			dep.call("_update_headwear_visual", true)
	for hw_id in _headwear_owner_by_id.keys():
		var owner_key := str(_headwear_owner_by_id[hw_id])
		var hr := get_resource_by_id(str(hw_id)) as HeadwearResource
		if hr == null:
			continue
		var target := _resolve_owner_node(owner_key)
		if target:
			target.set("equipped_headwear", hr)
			if target.has_method("_update_headwear_visual"):
				target.call("_update_headwear_visual", true)


func _resolve_owner_node(owner_key: String) -> Node:
	if owner_key == PLAYER_BINDING_KEY:
		return get_tree().get_first_node_in_group("player")
	if owner_key.begins_with("pet:"):
		for deployed in get_tree().get_nodes_in_group("deployed_pet"):
			if not deployed.has_method("get_headwear_binding_key"):
				continue
			var deployed_key := str(deployed.call("get_headwear_binding_key"))
			if deployed_key == owner_key:
				return deployed
		return null
	return null
