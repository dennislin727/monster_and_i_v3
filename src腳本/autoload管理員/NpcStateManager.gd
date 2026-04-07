# res://src腳本/autoload管理員/NpcStateManager.gd
extends Node

## NPC 好感與對話一次性發放旗標（執行期狀態；存檔可日後接同一字典）。
## 業務不在 SignalBus：此 Manager 集中寫入，並廣播結果型訊號。

func get_affinity(npc_id: String) -> int:
	var id := npc_id.strip_edges()
	if id.is_empty():
		return 0
	return int(_affinity.get(id, 0))


func add_affinity(npc_id: String, delta: int) -> void:
	var id := npc_id.strip_edges()
	if id.is_empty() or delta == 0:
		return
	var v: int = clampi(int(_affinity.get(id, 0)) + int(delta), 0, 999999)
	_affinity[id] = v
	if SignalBus:
		SignalBus.npc_affinity_changed.emit(id, v)


func is_grant_once_done(npc_id: String, grant_id: String) -> bool:
	var g := grant_id.strip_edges()
	if g.is_empty():
		return false
	return bool(_grants_done.get(_grant_key(npc_id, g), false))


func mark_grant_once_done(npc_id: String, grant_id: String) -> void:
	var g := grant_id.strip_edges()
	if g.is_empty():
		return
	_grants_done[_grant_key(npc_id, g)] = true


func resolve_prompt_line(npc: NpcResource) -> String:
	if npc == null:
		return ""
	var th: int = npc.prompt_affinity_threshold
	if th >= 0 and not npc.prompt_line_high_affinity.strip_edges().is_empty():
		if get_affinity(npc.npc_id) >= th:
			return npc.prompt_line_high_affinity
	return npc.prompt_line


var _affinity: Dictionary = {}
var _grants_done: Dictionary = {}


func get_save_snapshot() -> Dictionary:
	return {
		"affinity": _affinity.duplicate(true),
		"grants_done": _grants_done.duplicate(true),
	}


func apply_save_snapshot(data: Dictionary) -> void:
	_affinity.clear()
	_grants_done.clear()
	var aff: Variant = data.get("affinity", {})
	if aff is Dictionary:
		for k in (aff as Dictionary).keys():
			_affinity[str(k)] = int((aff as Dictionary)[k])
	var gd: Variant = data.get("grants_done", {})
	if gd is Dictionary:
		for k in (gd as Dictionary).keys():
			_grants_done[str(k)] = bool((gd as Dictionary)[k])


func _grant_key(npc_id: String, grant_id: String) -> String:
	return "%s|%s" % [npc_id.strip_edges(), grant_id.strip_edges()]
