class_name MonsterResource
extends Resource

@export var monster_name: String = "史萊姆"
@export var max_hp: int = 50
@export var move_speed: float = 100.0
@export var catch_rate: float = 0.5 # 封印成功率
@export var drop_item: ItemResource # 掉落什麼道具
@export var sprite_frames: SpriteFrames # 動畫資源
