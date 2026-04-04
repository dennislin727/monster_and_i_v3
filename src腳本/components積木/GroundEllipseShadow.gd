# res://src腳本/components積木/GroundEllipseShadow.gd
class_name GroundEllipseShadow
extends Node2D
## 貼地橢圓陰影（Sprite2D 作物／靜態道具等，無 AnimatedSprite2D 時用）

@export var ellipse_radius: Vector2 = Vector2(14, 5)
@export var shadow_color: Color = Color(0, 0, 0, 0.28)
func _ready() -> void:
	z_index = -2
	z_as_relative = true
	queue_redraw()


func _draw() -> void:
	var n := 20
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var t := (float(i) / float(n)) * TAU
		pts[i] = Vector2(cos(t) * ellipse_radius.x, sin(t) * ellipse_radius.y)
	draw_colored_polygon(pts, shadow_color)
