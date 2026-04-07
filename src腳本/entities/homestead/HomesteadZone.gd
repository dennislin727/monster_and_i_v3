# res://src腳本/entities/homestead/HomesteadZone.gd
extends Area2D
## 主角進出此區域時切換「在家園」狀態（不傳送）；可當大作綠地邊界，走廊留在區外。

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	call_deferred("_sync_initial_overlap")


func _sync_initial_overlap() -> void:
	if not monitoring:
		return
	for b in get_overlapping_bodies():
		_apply_player(b, true)


func _on_body_entered(body: Node2D) -> void:
	_apply_player(body, true)


func _on_body_exited(body: Node2D) -> void:
	_apply_player(body, false)


func _apply_player(body: Node2D, inside: bool) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if HomeManager:
		HomeManager.set_player_in_homestead(inside)
