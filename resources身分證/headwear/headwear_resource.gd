class_name HeadwearResource
extends Resource

@export_group("基礎資訊")
@export var headwear_id: String = "headwear_000"
@export var display_name: String = "新頭飾"
@export_multiline var description: String = ""

@export_group("視覺")
@export var icon: Texture2D
@export var sprite_frames: SpriteFrames # 最小可用：idle_down / idle_side / idle_up
