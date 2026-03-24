# res://src腳本/resources身分證/monster_resource.gd
class_name MonsterResource
extends Resource

@export_group("基礎屬性")
@export var monster_name: String = "未命名"
@export var max_hp: int = 50
@export var move_speed: float = 60.0
@export var chase_speed: float = 90.0

@export_group("戰鬥參數")
# 🔴 新增：攻擊力倍率。史萊姆設 1.0，哥布林可以設 2.5
@export var attack_multiplier: float = 1.0 
@export var attack_cooldown: float = 1.2 
@export var attack_range: float = 45.0

@export_group("性格與AI")
enum AggroType { PASSIVE, AGGRESSIVE }
@export var aggro_type: AggroType = AggroType.PASSIVE
@export var detection_range: float = 180.0
@export var actions_before_spell: int = 3 
<<<<<<< HEAD
@export var capture_rate: float = 0.5
=======
>>>>>>> 04a968e97d9729a30c86abd1729c40fb84f52714

@export_group("技能與掉落")
@export var skills: Array[SkillResource] = []
@export var drop_item: ItemResource
@export var drop_chance: float = 0.5

@export_group("視覺微調")
@export var sprite_frames: SpriteFrames
@export var accessory_offset: Vector2 = Vector2(0, -40)
