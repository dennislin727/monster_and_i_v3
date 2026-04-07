# res://src腳本/entities/homestead/LevelPortal.gd
extends Area2D
## 走進區域即切換關卡（單次觸發後短暫關閉監聽，避免換場當幀重入）。

enum Destination { HOMESTEAD, LAKE, TOWN }

@export var destination: Destination = Destination.LAKE
## 目標關卡根節點下的 Marker2D 名稱（例如 PlayerSpawn_FromLake）。
@export var spawn_marker_name: StringName = &"PlayerSpawn"

var _armed: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not _armed or body == null or not body.is_in_group("player"):
		return
	if HomeManager == null:
		return
	_armed = false
	set_deferred("monitoring", false)
	var m := str(spawn_marker_name).strip_edges()
	if m.is_empty():
		m = "PlayerSpawn"
	match destination:
		Destination.HOMESTEAD:
			HomeManager.switch_to_homestead(m)
		Destination.LAKE:
			HomeManager.switch_to_lake(m)
		Destination.TOWN:
			HomeManager.switch_to_town(m)
	call_deferred("_rear_arm")


func _rear_arm() -> void:
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self):
		monitoring = true
		_armed = true
