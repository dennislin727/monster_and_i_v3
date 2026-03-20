# res://src腳本/resources身分證/monster_resource.gd
class_name MonsterResource
extends Resource

@export_group("基礎屬性")
@export var monster_id: String = "slime_001"
@export var monster_name: String = "綠史萊姆"
@export var max_hp: int = 30
@export var move_speed: float = 80.0

@export_group("視覺資源")
@export var sprite_frames: SpriteFrames # 🔴 這裡直接拉入你畫好的動畫包
@export var shadow_size: float = 1.0     # 影子大小

@export_group("戰鬥參數")
@export var attack_damage: int = 5
@export var exp_reward: int = 10
@export var drop_item: ItemResource     # 掉落物
