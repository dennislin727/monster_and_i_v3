# res://resources身分證/skill_fx_templates/SkillResource.gd
class_name SkillResource
extends Resource

enum SkillType { HEAL, AOE_ATTACK, DASH, PROJECTILE }

@export_group("基礎設定")
@export var skill_name: String = "新技能"
@export var type: SkillType = SkillType.HEAL
@export var animation_name: String = "spell"
@export var cooldown: float = 5.0
@export_multiline var description: String = ""

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

@export_group("AOE 線形掃掠（type=AOE_ATTACK）")
## 巨石等：沿視窗對角（右上外 → 左下外）掃過的線段；路徑附近敵方單位各結算一次傷害。
@export var aoe_sweep_duration_sec: float = 0.95
@export var aoe_sweep_hit_radius: float = 44.0
## 相對於攝影機可視範圍的延伸（世界單位感），數值愈大起迄點愈外側。
@export var aoe_sweep_margin_world: float = 140.0
## false：以攝影機中心推算對角；true：以施法者位置為中心推算（寵物較易看見命中區）。
@export var aoe_sweep_anchor_on_caster: bool = false
## true：落地圈（鎖定施法當下目標位置，警示後圓形範圍傷害）；false：沿用線段掃掠（對角滾石）。


@export var aoe_use_ground_target: bool = false


@export_group("視覺提示")
@export var show_warning_circle: bool = false # 🔴 詠唱時是否顯示紅圈
@export var warning_color: Color = Color(1, 0, 0, 0.4)
## 落地圈預警（GroundSlamAoE）：等距／斜俯視下將正圓垂直壓成橢圓，像貼在平面上；1.0＝未壓扁正圓。
@export_range(0.12, 1.0, 0.01) var ground_telegraph_y_scale: float = 0.6

@export_group("Procedural FX Template IDs")
@export var telegraph_fx_template_id: String = ""
@export var cast_fx_template_id: String = ""
@export var impact_fx_template_id: String = ""

@export_group("收招設定")
@export var recovery_animation: String = "idle" # 🔴 這裡可以填 "fall"

@export_group("家園（資料驅動）")
## 寵物在家園內可對 `homestead_soil_plot` 執行翻土；禁止用 pet_id 硬編判斷。
@export var is_homestead_till_skill: bool = false
