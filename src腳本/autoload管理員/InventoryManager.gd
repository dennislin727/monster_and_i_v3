extends Node
## 玩家背包（簡易版）：聚合採集與之後取得的 ItemResource；UI 依分類顯示。

signal inventory_changed

## item_id -> { "resource": ItemResource, "count": int }
var _stacks: Dictionary = {}

func _ready() -> void:
	if SignalBus and not SignalBus.item_collected.is_connected(_on_item_collected):
		SignalBus.item_collected.connect(_on_item_collected)


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
		var r: ItemResource = entry.get("resource") as ItemResource
		if r == null:
			continue
		var is_equipment := r.type == ItemResource.ItemType.EQUIPMENT
		if is_equipment == want_equipment:
			out.append(entry)
	return out
