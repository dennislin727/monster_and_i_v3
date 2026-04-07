class_name FxTemplateResource
extends Resource

enum FxKind {
	WARNING_CIRCLE,
	WARNING_LINE,
	FISSURE,
	FAN_WAVE,
	SMOKE,
	FIRE,
	GOLDEN_MOTES,
	FALLING_LEAVES,
	RAIN,
	AFTERIMAGE_TRAIL,
	PURPLE_TRAIL,
	WATER_COLUMN,
	PROJECTILE_TAIL
}

@export_group("Identity")
@export var template_id: String = "warning_circle"
@export var display_name: String = "FX Template"
@export var fx_kind: FxKind = FxKind.WARNING_CIRCLE

@export_group("Timing")
@export var duration: float = 0.45
@export var fade_in: float = 0.08
@export var fade_out: float = 0.12
@export var loop: bool = false

@export_group("Shape / Motion")
@export var size: float = 48.0
@export var width: float = 6.0
@export var length: float = 96.0
@export var angle_deg: float = 70.0
@export var direction: Vector2 = Vector2.RIGHT
@export var drift_speed: float = 18.0
@export var motion_jitter: float = 8.0

@export_group("Palette")
@export var color_primary: Color = Color(1, 0.3, 0.3, 0.8)
@export var color_secondary: Color = Color(1, 1, 1, 0.55)

@export_group("Particle")
@export var particle_count: int = 18
@export var particle_size_px: float = 2.0
@export var particle_lifetime: float = 0.55

@export_group("Mobile")
@export var pixel_snap: bool = true
@export var mobile_cost_hint: int = 20
