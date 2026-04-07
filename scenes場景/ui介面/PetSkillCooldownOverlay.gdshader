shader_type canvas_item;

uniform vec2 rect_size = vec2(39.0, 39.0);
uniform float corner_radius : hint_range(1.0, 24.0) = 6.0;
/// 剩餘冷卻比例 0..1（由下往上覆蓋的高度）
uniform float cooldown_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec4 overlay_color : source_color = vec4(0.08, 0.07, 0.11, 0.76);

void fragment() {
	vec2 dim = max(rect_size, vec2(1.0));
	vec2 p = UV * dim - dim * 0.5;
	float r = min(corner_radius, min(dim.x, dim.y) * 0.5 - 0.5);
	r = max(r, 1.0);
	vec2 b = dim * 0.5 - vec2(r);
	vec2 q = abs(p) - b;
	float d = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
	float inside = step(d, 0.0);
	float y = UV.y;
	float fill = clamp(cooldown_ratio, 0.0, 1.0);
	float in_fill = step(1.0 - fill, y);
	float a = inside * in_fill * overlay_color.a;
	COLOR = vec4(overlay_color.rgb, a);
}
