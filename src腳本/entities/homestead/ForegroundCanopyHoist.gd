# res://src腳本/entities/homestead/ForegroundCanopyHoist.gd
# 編輯時把樹冠放在本節點下方便管理；進入遊戲後改掛到 LevelContainer，與 Player 同一 y_sort 父層。
extends Node2D


func _ready() -> void:
	# LevelContainer 仍在建子節點時不可對其 add_child（除錯器：Parent node is busy setting up children）。
	call_deferred("_hoist_children")


func _hoist_children() -> void:
	var lc: Node = get_parent()
	if lc == null or not is_instance_valid(self):
		return
	var bucket: Array[Node] = get_children()
	for c in bucket:
		var g: Vector2 = Vector2.ZERO
		if c is Node2D:
			g = (c as Node2D).global_position
		remove_child(c)
		lc.add_child(c)
		if c is Node2D:
			(c as Node2D).global_position = g
	queue_free()
