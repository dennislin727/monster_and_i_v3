# res://src腳本/entities/npcs/NpcFieldAgent.gd
extends Node2D

## 與主角 `Player` 根節點 z_index 對齊（見 Main／Player.tscn）。
const _PLAYER_BASE_Z := 5

@export var npc_data: NpcResource

@onready var _area: Area2D = $InteractionArea
@onready var _prompt_anchor: Marker2D = $PromptAnchor

var _player_inside: bool = false


func _ready() -> void:
	if npc_data == null:
		push_warning("[NpcFieldAgent] Missing npc_data on %s" % str(get_path()))
		return
	if _area:
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)
	if SignalBus:
		SignalBus.dialogue_blocking_changed.connect(_on_dialogue_blocking_changed)
		SignalBus.npc_affinity_changed.connect(_on_npc_affinity_changed)


func _process(_delta: float) -> void:
	# LevelContainer 對子節點做 y_sort，但主角／NPC 原點與腳底不一致時會錯覺「踩在頭上」。
	# 玩家在 NPC 北方（較小 global_y）時應被畫在後面，NPC 壓在玩家上。
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if p.global_position.y < global_position.y:
		z_index = _PLAYER_BASE_Z + 1
	else:
		z_index = _PLAYER_BASE_Z - 1


func _prompt_text() -> String:
	if npc_data == null:
		return ""
	return NpcStateManager.resolve_prompt_line(npc_data)


func _on_body_entered(body: Node) -> void:
	if npc_data == null:
		return
	if not body.is_in_group("player"):
		return
	_player_inside = true
	NpcInteractionManager.set_active_proximity(
		npc_data.npc_id,
		_prompt_text(),
		_prompt_anchor.global_position
	)


func _on_body_exited(body: Node) -> void:
	if npc_data == null:
		return
	if not body.is_in_group("player"):
		return
	_player_inside = false
	NpcInteractionManager.clear_proximity_if_match(npc_data.npc_id)


func _on_dialogue_blocking_changed(blocked: bool) -> void:
	if blocked or not _player_inside or npc_data == null:
		return
	NpcInteractionManager.set_active_proximity(
		npc_data.npc_id,
		_prompt_text(),
		_prompt_anchor.global_position
	)


func _on_npc_affinity_changed(npc_id: String, _new_value: int) -> void:
	if npc_data == null or npc_id != npc_data.npc_id:
		return
	if not _player_inside:
		return
	NpcInteractionManager.set_active_proximity(
		npc_data.npc_id,
		_prompt_text(),
		_prompt_anchor.global_position
	)
