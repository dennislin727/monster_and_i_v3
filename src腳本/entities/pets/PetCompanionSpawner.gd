# res://src腳本/entities/pets/PetCompanionSpawner.gd
extends Node

const COMPANION_SCENE := preload("res://scenes場景/entities主角_怪物_寵物/寵物/PetCompanion.tscn")

var _buddy: Node

func _ready() -> void:
	if not SignalBus.pet_deployed_changed.is_connected(_on_deployed):
		SignalBus.pet_deployed_changed.connect(_on_deployed)
	if not SignalBus.pet_active_changed.is_connected(_on_active_changed):
		SignalBus.pet_active_changed.connect(_on_active_changed)

func _on_deployed(is_deployed: bool) -> void:
	if is_deployed:
		call_deferred("_spawn")
	else:
		_despawn()

func _on_active_changed(_pet_data: Variant) -> void:
	# 切換 active 不代表換出戰；出戰實體只跟著 deployed_pet
	pass

func _spawn() -> void:
	_despawn()
	var pet := PetManager.deployed_pet
	if pet == null:
		push_warning("[PetCompanionSpawner] deployed_pet 為空，無法生成寵物。")
		return
	if COMPANION_SCENE == null:
		push_error("[PetCompanionSpawner] PetCompanion 場景載入失敗。")
		return
	var n: Node = COMPANION_SCENE.instantiate()
	if n.has_method("setup"):
		n.setup(pet)
	var parent_node := get_parent()
	if parent_node == null:
		push_warning("[PetCompanionSpawner] 沒有父節點（應掛在 LevelContainer 下）。")
		return
	parent_node.add_child(n)
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl:
		n.global_position = pl.global_position + Vector2(-48, 8)
	_buddy = n

func _despawn() -> void:
	if _buddy != null and is_instance_valid(_buddy):
		_buddy.queue_free()
	_buddy = null
