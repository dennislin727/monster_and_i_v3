@tool
extends Node2D

@export_group("Preview")
@export var autoplay: bool = true
@export var autoplay_speed: float = 1.0
@export_range(0.0, 1.0, 0.01) var preview_t: float = 0.0

@export_group("Timing")
@export var cast_time_sec: float = 0.8
@export var ring_fade_in_sec: float = 0.2

@export_group("Shape")
@export var radius_px: float = 58.0
@export var ring_width_px: float = 4.0
@export var energy_width_px: float = 6.0

@export_group("Palette")
@export var ring_color: Color = Color(1.0, 0.22, 0.22, 0.62)
@export var fill_color: Color = Color(1.0, 0.1, 0.1, 0.18)
@export var energy_color: Color = Color(1.0, 0.25, 0.25, 0.95)
@export var flash_color: Color = Color(1.0, 0.65, 0.55, 0.85)

var _time: float = 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if autoplay:
			_time = fmod(_time + delta * max(0.01, autoplay_speed), max(0.01, cast_time_sec))
			preview_t = _time / max(0.01, cast_time_sec)
		queue_redraw()
	else:
		if autoplay:
			_time = fmod(_time + delta, max(0.01, cast_time_sec))
			preview_t = _time / max(0.01, cast_time_sec)
		queue_redraw()

func _draw() -> void:
	var t: float = clamp(preview_t, 0.0, 1.0)
	var fade_in_t: float = clamp((t * cast_time_sec) / max(0.01, ring_fade_in_sec), 0.0, 1.0)
	var ring_col: Color = ring_color
	ring_col.a *= fade_in_t
	var fill_col: Color = fill_color
	fill_col.a *= fade_in_t

	draw_circle(Vector2.ZERO, radius_px, fill_col)
	draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 56, ring_col, ring_width_px, true)

	var current_r: float = radius_px * t
	var energy_col: Color = energy_color
	energy_col.a *= (0.5 + 0.5 * fade_in_t)
	draw_arc(Vector2.ZERO, current_r, 0.0, TAU, 56, energy_col, energy_width_px, true)

	if t > 0.96:
		var flash_strength: float = (t - 0.96) / 0.04
		var fc: Color = flash_color
		fc.a *= clamp(flash_strength, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 56, fc, ring_width_px + 2.0, true)
