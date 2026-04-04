# res://src腳本/entities/homestead/LevelPortal.gd
extends Area2D
## 走進區域即切換關卡（單次觸發後短暫關閉監聽，避免換場當幀重入）。

@export var go_homestead: bool = true

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
	if go_homestead:
		HomeManager.switch_to_homestead()
	else:
		HomeManager.switch_to_lake()
	call_deferred("_rear_arm")


func _rear_arm() -> void:
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self):
		monitoring = true
		_armed = true
