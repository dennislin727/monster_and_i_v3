extends AnimatedSprite2D

@export_group("Source")
@export var main_sprite_path: NodePath = "../AnimatedSprite2D"

@export_group("Placement")
@export var base_offset: Vector2 = Vector2(5.4, 12.9)
@export var preview_offset: Vector2 = Vector2.ZERO
@export var shadow_offset_extra: Vector2 = Vector2.ZERO
@export var shadow_scale: Vector2 = Vector2(0.8, 0.4)

@export_group("Style")
@export var shadow_opacity: float = 0.35

var main_sprite: AnimatedSprite2D

func _ready() -> void:
	main_sprite = get_node_or_null(main_sprite_path) as AnimatedSprite2D
	modulate = Color(0, 0, 0, shadow_opacity)
	skew = 0.0
	rotation_degrees = 0.0
	flip_v = true
	z_index = -1

func _process(_delta: float) -> void:
	if main_sprite == null:
		return
	position = base_offset + preview_offset
	offset = main_sprite.offset + shadow_offset_extra
	centered = main_sprite.centered
	var sf: SpriteFrames = main_sprite.sprite_frames
	if sf != sprite_frames:
		sprite_frames = sf
	if sprite_frames == null:
		visible = false
		return
	var want: StringName = main_sprite.animation
	if want.is_empty() or not sprite_frames.has_animation(want):
		visible = false
		return
	if sprite_frames.get_frame_count(want) <= 0:
		visible = false
		return
	visible = true
	if animation != want:
		animation = want
	frame = main_sprite.frame
	flip_h = main_sprite.flip_h
	var ms := main_sprite.scale
	scale = Vector2(absf(ms.x), absf(ms.y)) * shadow_scale
