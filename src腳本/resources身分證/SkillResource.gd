# res://src腳本/resources身分證/SkillResource.gd
class_name SkillResource
extends Resource

enum SkillType { HEAL, AOE_ATTACK, DASH, PROJECTILE }

@export_group("基礎設定")
@export var skill_name: String = "新技能"
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
