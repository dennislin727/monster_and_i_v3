# res://src腳本/resources身分證/monster_resource.gd
class_name MonsterResource
extends Resource

@export_group("基礎屬性")
@export var monster_name: String = "未命名"
@export var max_hp: int = 50
@export var move_speed: float = 60.0
@export var chase_speed: float = 90.0

@export_group("性格與AI")
enum AggroType { PASSIVE, AGGRESSIVE } # 被動(被打才還手) vs 主動(進範圍就打)
@export var aggro_type: AggroType = AggroType.PASSIVE
@export var detection_range: float = 180.0
@export var attack_range: float = 45.0

@export_group("技能配置 (Spell)")
@export var actions_before_spell: int = 3 # 🔴 你提議的計數器：做幾次動作後放招
@export var skills: Array[SkillResource] = []

@export_group("掉落清單")
@export var drop_item: ItemResource
@export var drop_chance: float = 0.5

@export_group("視覺微調")
@export var sprite_frames: SpriteFrames
@export var accessory_offset: Vector2 = Vector2(0, -40)
