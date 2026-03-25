# res://src腳本/resources身分證/pet_resource.gd
class_name PetResource
extends Resource

@export_group("基礎身分")
@export var pet_id: String = ""
@export var pet_name: String = "未命名寵物"
@export var icon: Texture2D
@export var sprite_frames: SpriteFrames # 繼承自怪物的視覺

@export_group("數值基準")
@export var follow_distance: float = 60.0
@export var follow_speed_mult: float = 1.1 # 稍微比主角快，才不會掉隊

@export_group("支援能力")
@export var heal_amount: int = 15
@export var heal_cooldown: float = 10.0
