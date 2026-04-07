# res://src腳本/entities/homestead/LakeSideAmbientVfx.gd
extends Node2D
## 湖畔關卡：僅螢火蟲粒子（水 AnimatedSprite2D 由編輯器自行接 5 幀等）


func _ready() -> void:
	_setup_fireflies()


func _configure_firefly(p: CPUParticles2D) -> void:
	p.z_index = 3
	p.z_as_relative = true
	p.amount = 22
	p.lifetime = 4.0
	p.preprocess = 2.0
	p.explosiveness = 0.0
	p.randomness = 0.35
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 48.0
	p.direction = Vector2(0, -1)
	p.spread = 130.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 18.0
	p.angular_velocity_min = -12.0
	p.angular_velocity_max = 12.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = Color(0.95, 1.0, 0.55, 0.75)


func _setup_fireflies() -> void:
	var zones := get_node_or_null("FireflyZones")
	if zones == null:
		return
	for ch in zones.get_children():
		if ch is Marker2D:
			var p := CPUParticles2D.new()
			ch.add_child(p)
			_configure_firefly(p)
