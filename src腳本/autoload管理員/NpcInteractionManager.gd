# res://src腳本/autoload管理員/NpcInteractionManager.gd
extends Node

## 多 NPC 仲裁：npc_id -> {prompt, anchor}
var _proximity_pool: Dictionary = {}
var _active_npc_id: String = ""
var _dialogue_suppresses_prompt: bool = false
## 對話關閉後：須先離開目前註冊的互動區再進入，才再度顯示提示（避免關窗瞬間又跳出）
var _require_proximity_exit_before_prompt: bool = false


func _ready() -> void:
	if SignalBus:
		SignalBus.dialogue_blocking_changed.connect(_on_dialogue_blocking_changed)
		SignalBus.harvest_mode_changed.connect(_on_harvest_mode_changed)


func _on_dialogue_blocking_changed(blocked: bool) -> void:
	_dialogue_suppresses_prompt = blocked
	if blocked:
		_require_proximity_exit_before_prompt = true
		_clear_prompt_signal()
		return
	# 解除封鎖時不立刻恢復提示；等 clear_proximity_if_match（離開範圍）後再進入才會顯示


func _on_harvest_mode_changed(_active: bool) -> void:
	_resolve_and_emit_best_prompt()


func _harvest_suppresses_npc_prompt() -> bool:
	return HomeManager != null and HomeManager.harvest_active


## NpcFieldAgent：進入互動範圍時呼叫
func set_active_proximity(npc_id: String, prompt_text: String, anchor_global: Vector2) -> void:
	var id := npc_id.strip_edges()
	if id.is_empty():
		return
	_proximity_pool[id] = {
		"prompt": prompt_text,
		"anchor": anchor_global,
	}
	if _dialogue_suppresses_prompt:
		return
	if _require_proximity_exit_before_prompt:
		return
	_resolve_and_emit_best_prompt()


## 離開範圍時呼叫
func clear_proximity_if_match(npc_id: String) -> void:
	var id := npc_id.strip_edges()
	if id.is_empty():
		return
	_proximity_pool.erase(id)
	if _active_npc_id == id:
		_active_npc_id = ""
	_require_proximity_exit_before_prompt = false
	_resolve_and_emit_best_prompt()


func _emit_prompt(visible: bool) -> void:
	if SignalBus == null:
		return
	if not visible:
		SignalBus.npc_interaction_prompt_changed.emit(false, "", "", Vector2.ZERO)
		return
	var info: Dictionary = _proximity_pool.get(_active_npc_id, {})
	SignalBus.npc_interaction_prompt_changed.emit(
		true,
		_active_npc_id,
		str(info.get("prompt", "")),
		info.get("anchor", Vector2.ZERO) as Vector2
	)


func _clear_prompt_signal() -> void:
	if SignalBus:
		SignalBus.npc_interaction_prompt_changed.emit(false, "", "", Vector2.ZERO)


func _resolve_and_emit_best_prompt() -> void:
	if _proximity_pool.is_empty():
		_active_npc_id = ""
		_emit_prompt(false)
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var best_id := ""
	var best_d2 := INF
	for id in _proximity_pool.keys():
		var info: Dictionary = _proximity_pool[id]
		var anchor: Vector2 = info.get("anchor", Vector2.ZERO)
		var d2 := 0.0 if player == null else player.global_position.distance_squared_to(anchor)
		if d2 < best_d2:
			best_d2 = d2
			best_id = str(id)
	_active_npc_id = best_id
	if _harvest_suppresses_npc_prompt():
		_emit_prompt(false)
		return
	_emit_prompt(true)
