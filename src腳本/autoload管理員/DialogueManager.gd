# res://src腳本/autoload管理員/DialogueManager.gd
extends Node

## npc_id → NpcResource 路徑；日後新 NPC 在此註冊。
const _NPC_PATH_BY_ID := {}

## dialogue_graph_key → DialogueGraphResource 路徑。
const _GRAPH_PATH_BY_KEY := {}

## 主文 RichTextLabel 預設字級為 11；NPC 名前綴單獨維持 13（見 _format_body）。
const _SPEAKER_NAME_FONT_SIZE := 13

var _graphs: Dictionary = {}
var _open: bool = false
var _current_npc_id: String = ""
var _current_display_name: String = ""
var _current_node: DialogueNodeResource = null
var _current_graph: DialogueGraphResource = null
## 與 DialoguePanel 選項索引對齊（已過濾條件）
var _filtered_choices: Array[DialogueChoiceEntry] = []


func _ready() -> void:
	_register_builtin_graphs()
	if SignalBus:
		SignalBus.npc_dialogue_requested.connect(_on_npc_dialogue_requested)
		SignalBus.dialogue_choice_selected.connect(_on_dialogue_choice_selected)
		SignalBus.dialogue_close_requested.connect(_on_dialogue_close_requested)


func register_dialogue_graph(key: String, graph: DialogueGraphResource) -> void:
	var k := key.strip_edges()
	if k.is_empty() or graph == null:
		return
	_graphs[k] = graph


func _register_builtin_graphs() -> void:
	for k: String in _GRAPH_PATH_BY_KEY:
		var path: String = str(_GRAPH_PATH_BY_KEY[k])
		if path.is_empty() or not ResourceLoader.exists(path):
			push_warning("[DialogueManager] Missing dialogue graph file: %s" % path)
			continue
		var loaded: Resource = load(path)
		var g: DialogueGraphResource = loaded as DialogueGraphResource
		if g == null:
			push_warning("[DialogueManager] Not a DialogueGraphResource: %s" % path)
			continue
		register_dialogue_graph(k, g)


func _on_npc_dialogue_requested(npc_id: String) -> void:
	var clean := npc_id.strip_edges()
	if clean.is_empty():
		return
	if HomesteadStationDialogue and HomesteadStationDialogue.try_open(clean):
		return
	if SignalBus:
		SignalBus.pet_ui_close_requested.emit()
		SignalBus.inventory_ui_close_requested.emit()
		SignalBus.diary_ui_close_requested.emit()
	var npc: NpcResource = _load_npc_by_id(clean)
	if npc == null:
		push_warning("[DialogueManager] Unknown npc_id: %s" % clean)
		return
	var key := npc.dialogue_graph_key.strip_edges()
	if key.is_empty() or not _graphs.has(key):
		push_warning("[DialogueManager] Missing graph for key: %s" % key)
		return
	_current_graph = _graphs[key] as DialogueGraphResource
	_current_npc_id = clean
	_current_display_name = npc.display_name
	_open = true
	_filtered_choices.clear()
	if SignalBus:
		SignalBus.dialogue_blocking_changed.emit(true)
		SignalBus.npc_interaction_prompt_changed.emit(false, "", "", Vector2.ZERO)
	_enter_node(_current_graph.start_node_id)


func _load_npc_by_id(npc_id: String) -> NpcResource:
	var p: String = str(_NPC_PATH_BY_ID.get(npc_id, ""))
	if p.is_empty() or not ResourceLoader.exists(p):
		return null
	return load(p) as NpcResource


func _on_dialogue_choice_selected(choice_index: int) -> void:
	if HomesteadStationDialogue and HomesteadStationDialogue.consume_choice(choice_index):
		return
	if not _open or _current_node == null or _current_graph == null:
		return
	var idx := int(choice_index)
	if idx < 0 or idx >= _filtered_choices.size():
		return
	var ch: DialogueChoiceEntry = _filtered_choices[idx]
	if ch == null:
		return
	_apply_choice_on_select_feedback(ch)
	var next_id := ch.target_node_id.strip_edges()
	if next_id.is_empty() or next_id == DialogueGraphResource.CLOSE_SENTINEL:
		_close_dialogue()
		return
	_enter_node(next_id)


func _apply_choice_on_select_feedback(ch: DialogueChoiceEntry) -> void:
	if ch.on_select_play_player_happy:
		var item_ack := not ch.on_select_world_hint_instant_text.strip_edges().is_empty()
		var p := get_tree().get_first_node_in_group("player")
		if p != null and p.has_method("play_dialogue_reward_happy"):
			p.play_dialogue_reward_happy(item_ack)
		if SignalBus and item_ack and p is Node2D:
			var start := (p as Node2D).global_position + Vector2(0.0, -56.0)
			SignalBus.dialogue_reward_vfx_requested.emit(start)
	var hint_txt := ch.on_select_world_hint_instant_text.strip_edges()
	if hint_txt.is_empty():
		return
	if not SignalBus:
		return
	var fade := 0.6
	if GlobalBalance:
		fade = GlobalBalance.HUD_FADE_OUT_SEC
	var payload := {
		"instant_text": hint_txt,
		"hold_sec": 2.4,
		"fade_out_sec": fade,
	}
	SignalBus.player_world_hint_changed.emit("dialogue_choice_feedback", true, payload)


func _on_dialogue_close_requested() -> void:
	if HomesteadStationDialogue and HomesteadStationDialogue.is_active():
		HomesteadStationDialogue.force_close()
		return
	if _open:
		_close_dialogue()


func _enter_node(node_id: String) -> void:
	var node := _current_graph.get_node_by_id(node_id)
	if node == null:
		push_warning("[DialogueManager] Missing node: %s" % node_id)
		_close_dialogue()
		return
	_current_node = node
	_run_enter_effects(node)
	_emit_present(node)


func _run_enter_effects(node: DialogueNodeResource) -> void:
	for e in node.on_enter_effects:
		if e == null:
			continue
		match e.kind:
			DialogueEffectEntry.Kind.GIVE_ITEM:
				var gid := e.grant_once_id.strip_edges()
				if not gid.is_empty() and NpcStateManager.is_grant_once_done(_current_npc_id, gid):
					continue
				if SignalBus and not e.item_id.strip_edges().is_empty() and e.amount > 0:
					SignalBus.inventory_grant_requested.emit(e.item_id.strip_edges(), int(e.amount))
				if not gid.is_empty():
					NpcStateManager.mark_grant_once_done(_current_npc_id, gid)
				var ms := e.career_milestone_id.strip_edges()
				if not ms.is_empty() and DiaryManager:
					DiaryManager.try_unlock_career(ms)
			DialogueEffectEntry.Kind.ADD_AFFINITY:
				NpcStateManager.add_affinity(_current_npc_id, int(e.affinity_delta))
			DialogueEffectEntry.Kind.REQUEST_QUEST:
				var qid := e.quest_request_id.strip_edges()
				if not qid.is_empty() and SignalBus:
					SignalBus.dialogue_quest_requested.emit(qid)
			_:
				pass


func _emit_present(node: DialogueNodeResource) -> void:
	var body := _format_body(node)
	_filtered_choices.clear()
	for ch in node.choices:
		if ch and _choice_visible_for_npc(ch, _current_npc_id):
			_filtered_choices.append(ch)
	if _filtered_choices.is_empty():
		_filtered_choices.append(_make_fallback_close_choice())
	var labels: PackedStringArray = PackedStringArray()
	for ch in _filtered_choices:
		labels.append(ch.text)
	if SignalBus:
		SignalBus.dialogue_presented.emit(true, body, labels)


func _choice_visible_for_npc(ch: DialogueChoiceEntry, npc_id: String) -> bool:
	if ch.min_affinity > 0 and NpcStateManager.get_affinity(npc_id) < ch.min_affinity:
		return false
	var pend := ch.require_grant_once_pending.strip_edges()
	if not pend.is_empty() and NpcStateManager.is_grant_once_done(npc_id, pend):
		return false
	var done_req := ch.require_grant_once_done.strip_edges()
	if not done_req.is_empty() and not NpcStateManager.is_grant_once_done(npc_id, done_req):
		return false
	if ch.require_party_non_empty and (PetManager == null or not PetManager.is_deployed):
		return false
	if ch.require_party_empty and PetManager != null and PetManager.is_deployed:
		return false
	if ch.require_in_homestead and (HomeManager == null or not HomeManager.in_homestead):
		return false
	return true


func _make_fallback_close_choice() -> DialogueChoiceEntry:
	var c := DialogueChoiceEntry.new()
	c.text = "待會再來"
	c.target_node_id = DialogueGraphResource.CLOSE_SENTINEL
	return c


func _format_body(node: DialogueNodeResource) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for line in node.lines:
		if line == null or line.text.strip_edges().is_empty():
			continue
		match line.speaker:
			DialogueLineBlock.Speaker.PLAYER_THOUGHT:
				parts.append("（我）\n" + line.text)
			_:
				var head := "%s：" % _current_display_name
				var sz := _SPEAKER_NAME_FONT_SIZE
				parts.append(
					"[font_size=%d]%s[/font_size]\n\n[font_size=%d]%s[/font_size]"
					% [sz, head, sz, line.text]
				)
	if parts.is_empty():
		return "……"
	return "\n\n".join(parts)


func _close_dialogue() -> void:
	_open = false
	_current_node = null
	_current_graph = null
	_current_npc_id = ""
	_current_display_name = ""
	_filtered_choices.clear()
	if SignalBus:
		SignalBus.dialogue_presented.emit(false, "", PackedStringArray())
		SignalBus.dialogue_blocking_changed.emit(false)
