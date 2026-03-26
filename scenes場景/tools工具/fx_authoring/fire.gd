@tool
extends Node2D

@export_group("Preview")
@export var autoplay: bool = true
@export var autoplay_speed: float = 1.0
@export_range(0.0, 1.0, 0.01) var preview_t: float = 0.0

@export_group("Fire Shape")
@export var base_width_px: float = 42.0
@export var flame_height_px: float = 74.0
@export var particle_count: int = 34
@export var bottom_particle_size_px: float = 8.0
@export var top_particle_size_px: float = 2.0

@export_group("Motion")
@export var rise_speed: float = 1.0
@export var x_sway_px: float = 7.0
@export var random_shrink: float = 0.45

@export_group("Palette")
@export var core_color: Color = Color(1.0, 0.62, 0.2, 0.92)
@export var mid_color: Color = Color(1.0, 0.36, 0.08, 0.72)
@export var ember_color: Color = Color(1.0, 0.9, 0.4, 0.56)

var _time: float = 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if autoplay:
		_time = fmod(_time + delta * max(0.01, autoplay_speed) * max(0.01, rise_speed), 1.0)
		preview_t = _time
	queue_redraw()

func _draw() -> void:
	var t: float = clamp(preview_t, 0.0, 1.0)
	for i in range(max(1, particle_count)):
		var idx: float = float(i)
		var seed: float = _hashf(i * 97 + 13)
		var life: float = fmod(t + seed, 1.0)
		var y_norm: float = 1.0 - life

		var spread: float = lerpf(base_width_px * 0.55, base_width_px * 0.12, y_norm)
		var x: float = (seed - 0.5) * spread + sin((life * TAU * 2.0) + idx * 0.37) * x_sway_px * y_norm
		var y: float = -life * flame_height_px

		var base_size: float = lerpf(bottom_particle_size_px, top_particle_size_px, y_norm)
		var shrink_rand: float = lerpf(1.0, max(0.1, 1.0 - random_shrink), _hashf(i * 181 + int(t * 1000.0)))
		var px: float = max(1.0, base_size * shrink_rand)

		var a: float = clamp(1.0 - life * 1.15, 0.0, 1.0)
		var c: Color = core_color.lerp(mid_color, clamp(life * 0.8, 0.0, 1.0)).lerp(ember_color, clamp((life - 0.65) / 0.35, 0.0, 1.0))
		c.a *= a

		draw_rect(Rect2(Vector2(x, y), Vector2(px, px)), c, true)

func _hashf(n: int) -> float:
	var x: float = float((n * 1103515245 + 12345) & 0x7fffffff)
	return fmod(x / 2147483647.0, 1.0)
