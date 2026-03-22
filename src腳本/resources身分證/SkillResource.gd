# res://src腳本/resources身分證/skill_resource.gd
class_name SkillResource
extends Resource

enum SkillType { HEAL, AOE_ATTACK, DASH, PROJECTILE }

@export_group("基礎設定")
@export var skill_name: String = "新技能"
@export var type: SkillType = SkillType.AOE_ATTACK
@export var animation_name: String = "spell" # 對應 AnimatedSprite2D 的動畫名
@export var cooldown: float = 5.0

@export_group("數值設定")
@export var power: int = 10           # 傷害量或治療量
@export var range_radius: float = 100.0 # 作用範圍

@export_group("觸發條件")
@export var min_hp_percentage: float = 0.0 # 至少要剩多少血才能放
@export var max_hp_percentage: float = 1.0 # 低於多少血才放 (如史萊姆補血設 0.3)
