# res://src腳本/entities/homestead/TownLeafAmbientVfx.gd
extends Node2D
## 落葉鎮：緩落葉片粒子（節點結構比照湖畔 `LakeSideAmbientVfx` + `FireflyZones`）。
## 每個 LeafZone（同一棵樹）同時發兩色粒子；`color_ramp` 做生成／結束漸顯漸隱。
##
## 參考：湖畔螢火蟲 `scale_amount_min = 1.0`、`scale_amount_max = 2.5`；本腳本葉片再放大一階。
##
## 前景 `ForegroundDecor` 會由 `ForegroundCanopyHoist` 改掛到 `level_container`（z＝`LEVEL_SORTED_ENTITY_Z_INDEX`）。
## 若粒子留在關卡子樹內，會永遠被前景蓋住；故進入場景後將本節點（掛在 `Art/Ambience`）同樣改掛到 `level_container`，z 比前景 +1。


const _LEAF_A := Color(1.0, 187.0 / 255.0, 119.0 / 255.0, 0.78)
const _LEAF_B := Color(170.0 / 255.0, 93.0 / 255.0, 63.0 / 255.0, 0.78)


func _ready() -> void:
	_setup_falling_leaves()
	call_deferred("_hoist_to_level_container")


## Godot 4.1：`CPUParticles2D.color_ramp` 為 `Gradient`（4.2+ 部分版本改為 Texture，此寫法與 4.1 一致）。
func _leaf_lifetime_color_ramp(peak: Color) -> Gradient:
	var g := Gradient.new()
	var r := peak.r
	var gg := peak.g
	var b := peak.b
	var a := peak.a
	g.add_point(0.0, Color(r, gg, b, 0.0))
	g.add_point(0.1, Color(r, gg, b, a))
	g.add_point(0.88, Color(r, gg, b, a))
	g.add_point(1.0, Color(r, gg, b, 0.0))
	return g


func _configure_leaf_particles(p: CPUParticles2D, tint: Color) -> void:
	p.z_index = 2
	p.z_as_relative = true
	# 每色一發射器；雙色合計約 12／區（略少於舊版 16，畫面較鬆）
	p.amount = 6
	p.lifetime = 3.0
	p.preprocess = 1.0
	p.explosiveness = 0.0
	p.randomness = 0.5
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 52.0
	# 風往右減弱（direction.x、gravity.x 皆下調）
	p.direction = Vector2(0.035, 1.0)
	p.spread = 40.0
	# 重力／初速略降，飄落更慢、更優雅
	p.gravity = Vector2(2.2, 9.0)
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 8.0
	p.angular_velocity_min = -26.0
	p.angular_velocity_max = 26.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.2
	p.color = Color.WHITE
	p.color_ramp = _leaf_lifetime_color_ramp(tint)


func _setup_falling_leaves() -> void:
	var zones := get_node_or_null("LeafZones")
	if zones == null:
		return
	for ch in zones.get_children():
		if ch is Marker2D:
			for tint in [_LEAF_A, _LEAF_B]:
				var p := CPUParticles2D.new()
				ch.add_child(p)
				_configure_leaf_particles(p, tint)


func _hoist_to_level_container() -> void:
	var tree := get_tree()
	if tree == null or not is_instance_valid(self):
		return
	var lc: Node = tree.get_first_node_in_group("level_container")
	if lc == null:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	var gp := global_position
	parent_node.remove_child(self)
	lc.add_child(self)
	global_position = gp
	z_as_relative = false
	z_index = GlobalBalance.LEVEL_SORTED_ENTITY_Z_INDEX + 1
