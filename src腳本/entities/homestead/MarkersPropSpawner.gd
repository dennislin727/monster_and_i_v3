# res://src腳本/entities/homestead/MarkersPropSpawner.gd
# 在子節點的 Marker2D 位置生成 PackedScene（預設掛到 level_container，與 Player 同層 y_sort）。
extends Node2D

@export var prop_scene: PackedScene
## 可選：生成後寫入（例：`MonsterBase.data` → 綠史萊姆 `.tres`）
@export var prop_data: Resource
@export var attach_to_level_container: bool = true


func _ready() -> void:
	if prop_scene == null:
		return
	# 父節點仍在建樹時不可 add_child；延到下一幀（與石頭／史萊姆多顆生成相同）
	call_deferred("_spawn_props")


func _spawn_props() -> void:
	if prop_scene == null:
		return
	var target: Node = self
	if attach_to_level_container:
		var lc: Node = get_tree().get_first_node_in_group("level_container")
		if lc != null:
			target = lc
		else:
			push_warning("MarkersPropSpawner: level_container 找不到，改掛在本關卡下。")
	for child in get_children():
		if not (child is Marker2D):
			continue
		var m := child as Marker2D
		var inst: Node = prop_scene.instantiate()
		if inst == null:
			continue
		if prop_data != null and inst is MonsterBase and prop_data is MonsterResource:
			(inst as MonsterBase).data = prop_data as MonsterResource
		target.add_child(inst)
		if inst is Node2D:
			(inst as Node2D).global_position = m.global_position
