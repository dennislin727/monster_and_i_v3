# res://src腳本/entities/homestead/HomesteadCrop.gd
class_name HomesteadCrop
extends Area2D

## 與 `LevelRoot.LEVEL_YSORT_PROXY_GROUP` 同字串（執行期掛到 level_container 供 y_sort）。
const _LEVEL_YSORT_PROXY_GROUP := "homestead_level_ysort_proxy"
const _PLAYER_BASE_Z := 5

## 採收後是否 `queue_free`；家園土格循環種植時設 false，由 `HomesteadSoilPlot` 回收。
@export var free_after_pickup: bool = true
@export var is_mature: bool = true
@export var item_template: ItemResource

signal harvest_recycled

var _gathered: bool = false


func _ready() -> void:
	add_to_group("homestead_crop")
	if get_node_or_null("GroundShadow") == null:
		var blob := GroundEllipseShadow.new()
		blob.name = "GroundShadow"
		blob.position = Vector2(0, 12)
		blob.ellipse_radius = Vector2(16, 5.5)
		add_child(blob)
	call_deferred("_attach_to_level_container_for_ysort")


func _attach_to_level_container_for_ysort() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var lc: Node = tree.get_first_node_in_group("level_container")
	if lc == null or get_parent() == lc:
		return
	# Godot 4：不可在仍有父節點時直接 add_child 到新父節點，須 reparent 或先 remove_child。
	reparent(lc, true)
	z_index = 5
	y_sort_enabled = true
	add_to_group(_LEVEL_YSORT_PROXY_GROUP)
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.y_sort_enabled = true


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if p.global_position.y < global_position.y:
		z_index = _PLAYER_BASE_Z + 1
	else:
		z_index = _PLAYER_BASE_Z - 1


## 仍長在田裡、可掃的成熟株（已入包但尚未 queue_free 時 is_mature 仍 true，勿只依 is_mature 計數）
func counts_as_mature_available() -> bool:
	return not _gathered and is_mature and item_template != null


## 採收模式下滑掃：世界座標命中可採區則入包並播收集演出。
func try_harvest_at(world_pos: Vector2) -> bool:
	if _gathered or not is_mature or item_template == null:
		return false
	var radius := _harvest_radius()
	if global_position.distance_to(world_pos) > radius:
		return false
	_gathered = true
	var stack_item: ItemResource = item_template.duplicate(true) as ItemResource
	SignalBus.item_collected.emit(stack_item)
	var tex: Texture2D = item_template.icon
	if tex == null:
		tex = item_template.world_texture
	SignalBus.request_effect_collect.emit(global_position, tex)
	_try_lucky_bonus_drop(tex)
	if free_after_pickup:
		queue_free()
	else:
		_gathered = false
		is_mature = false
		hide()
		harvest_recycled.emit()
	return true


func _try_lucky_bonus_drop(tex: Texture2D) -> void:
	if PetManager == null:
		return
	var luck := PetManager.get_party_luck_bonus_rate()
	if luck <= 0.0:
		return
	if randf() > luck:
		return
	var extra: ItemResource = item_template.duplicate(true) as ItemResource
	SignalBus.item_collected.emit(extra)
	SignalBus.request_effect_collect.emit(global_position + Vector2(10, -6), tex)


func _harvest_radius() -> float:
	for c in get_children():
		if c is CollisionShape2D:
			var cs := c as CollisionShape2D
			var sh := cs.shape
			if sh is CircleShape2D:
				return (sh as CircleShape2D).radius * maxf(global_scale.x, global_scale.y)
			if sh is RectangleShape2D:
				var r := sh as RectangleShape2D
				return maxf(r.size.x, r.size.y) * 0.5 * maxf(global_scale.x, global_scale.y)
	return 28.0
