# res://src腳本/components積木/ShadowComponent.gd
extends AnimatedSprite2D

@export_group("基礎偏移 (你的微調成果)")
@export var base_offset: Vector2 = Vector2(-5, 3) # 🔴 你調好的位置
@export var base_scale: Vector2 = Vector2(0.8, 0.6)  # 🔴 你調好的比例

@export_group("影子美學設定")
@export var shadow_opacity: float = 0.35
@export var max_jump_height: float = 120.0 # 預期的最高跳躍高度

@onready var main_sprite: AnimatedSprite2D = get_node("../AnimatedSprite2D")

func _ready() -> void:
	# 1. 視覺初始化
	modulate = Color(0, 0, 0, shadow_opacity)
	skew = deg_to_rad(35.0)
	rotation_degrees = -160.0
	z_index = -1
	
	# 2. 應用你的微調數值
	position = base_offset
	scale = base_scale
	
	if main_sprite:
		sprite_frames = main_sprite.sprite_frames

func _process(_delta: float) -> void:
	if not main_sprite: return
	
	# 同步動畫
	if animation != main_sprite.animation:
		animation = main_sprite.animation
	frame = main_sprite.frame
	flip_h = main_sprite.flip_h
	
	# 3. 🔴 影子高度感應邏輯 (基於你的微調數值進行縮放)
	var current_height = abs(main_sprite.position.y)
	
	# 計算縮放係數 (從 1.0 降到 0.5)
	var shrink_factor = remap(current_height, 0, max_jump_height, 1.0, 0.5)
	shrink_factor = clamp(shrink_factor, 0.5, 1.0)
	
	# 以你的 base_scale 為基準進行縮放
	scale = base_scale * shrink_factor
	
	# 隨高度變淡
	modulate.a = shadow_opacity * shrink_factor
