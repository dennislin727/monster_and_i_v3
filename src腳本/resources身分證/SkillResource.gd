<<<<<<< HEAD
# res://src腳本/resources身分證/SkillResource.gd
=======
# res://src腳本/resources身分證/skill_resource.gd
>>>>>>> 7b075d86e301c5e59bc262ee2693a51f1efe938d
class_name SkillResource
extends Resource

enum SkillType { HEAL, AOE_ATTACK, DASH, PROJECTILE }

@export_group("基礎設定")
@export var skill_name: String = "新技能"
<<<<<<< HEAD
@export var type: SkillType = SkillType.HEAL
@export var animation_name: String = "spell"
@export var cooldown: float = 5.0

@export_group("時序控制 (秒)")
@export var startup_time: float = 0.5   # 施法前的蓄力時間
@export var trigger_delay: float = 0.6  # 動畫開始後多久觸發效果
@export var recovery_time: float = 0.8  # 施法後的收招時間

@export_group("特殊動作")
@export var dash_before_skill: bool = true
@export var dash_distance: float = 120.0

@export_group("數值與條件")
@export var power: int = 20
@export var max_hp_pct: float = 0.5
=======
@export var type: SkillType = SkillType.AOE_ATTACK
@export var animation_name: String = "spell" # 對應 AnimatedSprite2D 的動畫名
@export var cooldown: float = 5.0

@export_group("數值設定")
@export var power: int = 10           # 傷害量或治療量
@export var range_radius: float = 100.0 # 作用範圍

@export_group("觸發條件")
@export var min_hp_percentage: float = 0.0 # 至少要剩多少血才能放
@export var max_hp_percentage: float = 1.0 # 低於多少血才放 (如史萊姆補血設 0.3)
>>>>>>> 7b075d86e301c5e59bc262ee2693a51f1efe938d
