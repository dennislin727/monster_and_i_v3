# res://src腳本/entities/pets/PetCompanionSpawner.gd
extends Node

const COMPANION_SCENE := preload("res://scenes場景/entities主角_怪物_寵物/寵物/PetCompanion.tscn")
const _RECALL_FADE_SEC := 0.16

var _buddies: Array = []


func _ready() -> void:
	_buddies.resize(PetManager.PARTY_SLOT_COUNT)
	for i in PetManager.PARTY_SLOT_COUNT:
		_buddies[i] = null
	if not SignalBus.pet_party_changed.is_connected(_on_party_changed):
		SignalBus.pet_party_changed.connect(_on_party_changed)
	if not SignalBus.pet_deployed_changed.is_connected(_on_deployed):
		SignalBus.pet_deployed_changed.connect(_on_deployed)


func _on_deployed(_is_deployed: bool) -> void:
	call_deferred("_sync_party")


func _on_party_changed() -> void:
	call_deferred("_sync_party")


func _sync_party() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		push_warning("[PetCompanionSpawner] 沒有父節點（應掛在 LevelContainer 下）。")
		return
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	for i in PetManager.PARTY_SLOT_COUNT:
		var want: PetResource = PetManager.party_slots[i] as PetResource if i < PetManager.party_slots.size() else null
		var buddy: Node = _buddies[i] if i < _buddies.size() else null
		if want == null:
			_free_buddy_at(i, true)
			continue
		if buddy != null and is_instance_valid(buddy):
			var cur_id := ""
			if buddy.has_method("get_pet_instance_id"):
				cur_id = str(buddy.call("get_pet_instance_id"))
			var want_id := want.instance_id.strip_edges()
			if cur_id == want_id:
				continue
		_free_buddy_at(i, false)
		_spawn_slot(i, want, parent_node, pl)


func _free_buddy_at(slot: int, fade_out: bool) -> void:
	if slot < 0 or slot >= _buddies.size():
		return
	var b: Node = _buddies[slot]
	if b != null and is_instance_valid(b):
		if fade_out:
			_fade_and_free_buddy(b)
		else:
			b.queue_free()
	_buddies[slot] = null


func _fade_and_free_buddy(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	if b is CanvasItem:
		var ci := b as CanvasItem
		ci.modulate.a = 1.0
		var tw := ci.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(ci, "modulate:a", 0.0, _RECALL_FADE_SEC)
		tw.finished.connect(func() -> void:
			if is_instance_valid(b):
				b.queue_free()
		, CONNECT_ONE_SHOT)
		return
	b.queue_free()


func _spawn_slot(slot: int, pet: PetResource, parent_node: Node, pl: Node2D) -> void:
	if COMPANION_SCENE == null:
		push_error("[PetCompanionSpawner] PetCompanion 場景載入失敗。")
		return
	var n: Node = COMPANION_SCENE.instantiate()
	if n.has_method("setup"):
		n.call("setup", pet, slot)
	if InventoryManager and not pet.instance_id.strip_edges().is_empty():
		var owner_key := "pet:%s" % pet.instance_id
		var equipped := InventoryManager.get_headwear_by_owner_key(owner_key)
		if equipped != null:
			n.set("equipped_headwear", equipped)
			if n.has_method("_update_headwear_visual"):
				n.call("_update_headwear_visual", true)
	parent_node.add_child(n)
	if pl:
		n.global_position = pl.global_position + _spawn_offset_for_slot(slot)
	_buddies[slot] = n
	if SignalBus:
		SignalBus.pet_party_field_companion_spawned.emit(slot)


func _spawn_offset_for_slot(slot: int) -> Vector2:
	match slot:
		0:
			return Vector2(-48, 8)
		1:
			return Vector2(48, 8)
		2:
			return Vector2(0, 72)
		_:
			return Vector2(-48, 8)
