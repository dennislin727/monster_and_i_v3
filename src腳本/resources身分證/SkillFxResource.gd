class_name SkillFxResource
extends Resource

enum MobileLodLevel { HIGH, MEDIUM, LOW }

@export_group("Identity")
@export var fx_id: String = "fx_new"
@export var display_name: String = "New FX"

@export_group("Timing (seconds)")
@export var telegraph_duration: float = 0.20
@export var cast_duration: float = 0.12
@export var impact_duration: float = 0.28
@export var trigger_delay: float = 0.06

@export_group("Range / Shape")
@export var aoe_radius: float = 48.0
@export var use_screen_space: bool = false

@export_group("Visual Assets")
@export var telegraph_frames: SpriteFrames
@export var cast_frames: SpriteFrames
@export var impact_frames: SpriteFrames

@export_group("Palette / Theme")
@export var tint: Color = Color(1, 1, 1, 1)
@export var telegraph_color: Color = Color(1, 0.2, 0.2, 0.35)

@export_group("Mobile Budget")
@export var mobile_lod_level: MobileLodLevel = MobileLodLevel.MEDIUM
@export var estimated_particles: int = 24
@export var additive_blend: bool = false
