# res://src腳本/entities/homestead/LevelRoot.gd
extends Node2D

## 執行期掛到 `level_container`、與玩家同層 y_sort 的節點（作物／家園站點寵物）；關卡卸載時集中清除，避免殘留。
const LEVEL_YSORT_PROXY_GROUP := "homestead_level_ysort_proxy"


func _ready() -> void:
	add_to_group("loaded_level")


func _exit_tree() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group(LEVEL_YSORT_PROXY_GROUP):
		if is_instance_valid(n):
			n.queue_free()
