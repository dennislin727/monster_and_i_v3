extends Node2D

var fx: Resource
var facing: Vector2 = Vector2.RIGHT
var _t: float = 0.0
var _alive: bool = false
var _seed: int = 1

func setup(config: Resource, in_facing: Vector2 = Vector2.RIGHT) -> void:
	fx = config
	facing = in_facing.normalized() if in_facing.length() > 0.001 else Vector2.RIGHT
	_seed = randi()
	_alive = (fx != null)
	if _alive:
		set_process(true)
		queue_redraw()

func _process(delta: float) -> void:
	if not _alive or fx == null:
		queue_free()
		return
	_t += delta
	var duration: float = max(0.01, float(fx.get("duration")))
	if bool(fx.get("pixel_snap")):
		global_position = global_position.round()
	queue_redraw()
	if _t >= duration and not bool(fx.get("loop")):
		queue_free()

func _draw() -> void:
	if fx == null:
		return
	var duration: float = max(0.01, float(fx.get("duration")))
	var p: float = clamp(_t / duration, 0.0, 1.0)
	var alpha: float = _alpha_by_phase(p)
	var primary: Color = fx.get("color_primary")
	var secondary: Color = fx.get("color_secondary")
	primary.a *= alpha
	secondary.a *= alpha
	var kind: int = int(fx.get("fx_kind"))
	match kind:
		0: _draw_warning_circle(p, primary, secondary)
		1: _draw_warning_line(p, primary, secondary)
		2: _draw_fissure(p, primary, secondary)
		3: _draw_fan_wave(p, primary, secondary)
		4: _draw_smoke(p, primary, secondary)
		5: _draw_fire(p, primary, secondary)
		6: _draw_golden_motes(p, primary, secondary)
		7: _draw_falling_leaves(p, primary, secondary)
		8: _draw_rain(p, primary, secondary)
		9: _draw_afterimage(p, primary, secondary)
		10: _draw_purple_trail(p, primary, secondary)
		11: _draw_water_column(p, primary, secondary)
		12: _draw_projectile_tail(p, primary, secondary)

func _alpha_by_phase(p: float) -> float:
	var fade_in: float = max(0.001, float(fx.get("fade_in")))
	var fade_out: float = max(0.001, float(fx.get("fade_out")))
	if p < fade_in:
		return p / fade_in
	if p > 1.0 - fade_out:
		return (1.0 - p) / fade_out
	return 1.0

func _draw_warning_circle(p: float, a: Color, b: Color) -> void:
	var r: float = float(fx.get("size")) * (0.86 + 0.14 * sin(p * TAU * 2.0))
	var w: float = float(fx.get("width"))
	draw_circle(Vector2.ZERO, r, Color(a.r, a.g, a.b, a.a * 0.25))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, b, w, true)

func _draw_warning_line(p: float, a: Color, b: Color) -> void:
	var len: float = float(fx.get("length"))
	var w: float = float(fx.get("width"))
	var dir: Vector2 = facing
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var start: Vector2 = -dir * len * 0.5
	var end: Vector2 = dir * len * 0.5
	draw_line(start, end, b, w, true)
	draw_polygon([start + perp * (w * 0.5), end + perp * (w * 0.5), end - perp * (w * 0.5), start - perp * (w * 0.5)], [Color(a.r, a.g, a.b, a.a * (0.2 + 0.2 * sin(p * TAU * 5.0)))])

func _draw_fissure(p: float, a: Color, b: Color) -> void:
	var len: float = float(fx.get("length"))
	var w: float = float(fx.get("width"))
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 6
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: float = lerpf(-len * 0.5, len * 0.5, t)
		var y: float = sin((t * 6.0 + float(_seed % 5)) * 2.1) * (w * 0.45)
		pts.append(Vector2(x, y))
	for i in range(steps):
		draw_line(pts[i], pts[i + 1], b, max(1.0, w * (1.0 - p)), true)
	draw_polyline(pts, a, 1.0, true)

func _draw_fan_wave(p: float, a: Color, b: Color) -> void:
	var radius: float = float(fx.get("size")) * (0.45 + p)
	var half: float = deg_to_rad(float(fx.get("angle_deg")) * 0.5)
	var base: float = facing.angle()
	var poly: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i in range(18):
		var t: float = float(i) / 17.0
		var ang: float = base + lerpf(-half, half, t)
		poly.append(Vector2.RIGHT.rotated(ang) * radius)
	draw_polygon(poly, [Color(a.r, a.g, a.b, a.a * 0.35)])
	draw_polyline(poly, b, max(1.0, float(fx.get("width")) * 0.35), true)

func _draw_smoke(p: float, a: Color, b: Color) -> void:
	_draw_square_particles(p, a, b, Vector2(0, -1), float(fx.get("drift_speed")) * 0.8, true)

func _draw_fire(p: float, a: Color, b: Color) -> void:
	_draw_square_particles(p, a, b, Vector2(0, -1), float(fx.get("drift_speed")) * 1.3, false)

func _draw_golden_motes(p: float, a: Color, b: Color) -> void:
	_draw_square_particles(p, a, b, Vector2(0.4, -0.3), float(fx.get("drift_speed")) * 0.6, false)

func _draw_falling_leaves(p: float, a: Color, b: Color) -> void:
	_draw_square_particles(p, a, b, Vector2(0.2, 1), float(fx.get("drift_speed")), true)

func _draw_rain(p: float, a: Color, b: Color) -> void:
	var count: int = int(fx.get("particle_count"))
	var size: float = float(fx.get("size"))
	var speed: float = max(10.0, float(fx.get("drift_speed")))
	var w: float = max(1.0, float(fx.get("width")))
	for i in range(count):
		var sx: float = _hashf(i * 113 + 19) * size - size * 0.5
		var phase: float = fmod(p + _hashf(i * 79 + 5), 1.0)
		var y: float = lerpf(-size * 0.5, size * 0.5, phase) + phase * speed * 0.08
		var from: Vector2 = Vector2(sx, y)
		var to: Vector2 = from + Vector2(-w * 1.5, w * 3.5)
		draw_line(from, to, a if i % 2 == 0 else b, w, true)

func _draw_afterimage(p: float, a: Color, b: Color) -> void:
	var len: float = float(fx.get("length"))
	var w: float = float(fx.get("width"))
	var dir: Vector2 = facing
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	for i in range(3):
		var tp: float = float(i) / 2.0
		var tail: Vector2 = -dir * len * (tp + p * 0.2)
		var width_now: float = w * (1.0 - tp) * (1.0 - p * 0.6)
		draw_polygon(
			[tail - perp * width_now, tail + perp * width_now, tail + perp * width_now + dir * 14.0, tail - perp * width_now + dir * 14.0],
			[Color(a.r, a.g, a.b, a.a * (0.45 - tp * 0.2))]
		)
	draw_line(Vector2.ZERO, -dir * len, b, 1.0, true)

func _draw_purple_trail(p: float, a: Color, b: Color) -> void:
	_draw_afterimage(p, a, b)
	_draw_square_particles(p, a, b, -facing, float(fx.get("drift_speed")) * 0.7, false)

func _draw_water_column(p: float, a: Color, b: Color) -> void:
	var h: float = float(fx.get("length"))
	var w: float = float(fx.get("width"))
	var rect: Rect2 = Rect2(Vector2(-w * 0.5, -h * 0.5 + h * (1.0 - p)), Vector2(w, h * p))
	draw_rect(rect, Color(a.r, a.g, a.b, a.a * 0.6), true)
	draw_rect(rect.grow(-2.0), Color(b.r, b.g, b.b, b.a * 0.45), true)

func _draw_projectile_tail(p: float, a: Color, b: Color) -> void:
	var len: float = float(fx.get("length")) * (1.0 - p * 0.5)
	var w: float = float(fx.get("width"))
	var dir: Vector2 = facing
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = Vector2.ZERO
	var tail: Vector2 = -dir * len
	draw_polygon([tip, tail + perp * w, tail - perp * w], [a])
	draw_line(tail + perp * (w * 0.4), tip, b, 1.0, true)
	draw_line(tail - perp * (w * 0.4), tip, b, 1.0, true)

func _draw_square_particles(p: float, a: Color, b: Color, flow_dir: Vector2, speed: float, sway: bool) -> void:
	var count: int = int(fx.get("particle_count"))
	var spread: float = float(fx.get("size"))
	var px: float = max(1.0, float(fx.get("particle_size_px")))
	var jitter: float = float(fx.get("motion_jitter"))
	for i in range(count):
		var t0: float = _hashf(i * 17 + _seed)
		var life: float = fmod(p + t0, 1.0)
		var base: Vector2 = Vector2(
			(_hashf(i * 53 + 3) - 0.5) * spread,
			(_hashf(i * 97 + 11) - 0.5) * spread * 0.6
		)
		var dir: Vector2 = flow_dir.normalized()
		var off: Vector2 = dir * speed * life
		if sway:
			off.x += sin((life * TAU * 2.0) + i) * (jitter * 0.2)
		var pos: Vector2 = base + off
		var col: Color = a if i % 2 == 0 else b
		draw_rect(Rect2(pos, Vector2(px, px)), col, true)

func _hashf(n: int) -> float:
	var x := float((n * 1103515245 + 12345) & 0x7fffffff)
	return fmod(x / 2147483647.0, 1.0)
