# res://resources身分證/monster/monster_resource.gd
class_name MonsterResource
extends Resource

const DEFAULT_HEAD_ANCHOR_OFFSET := Vector2(0, -40)

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
## 遠程風箏：主角太近時先拉開距離；主要傷害依賴技能（如 AOE），不進入飛撲近戰。
enum CombatStyle { MELEE, RANGED_KITER }
@export var combat_style: CombatStyle = CombatStyle.MELEE
## 與目標距離小於此值時往反方向跑（僅 RANGED_KITER）。
@export var kite_retreat_below: float = 100.0
## 與目標距離大於此值時往目標靠近（僅 RANGED_KITER；避免永遠放風箏超出偵測）。
@export var kite_chase_above: float = 360.0
## 遠程普攻（投石等）：與 **Spell 欄 `skills`** 分開；由 `MonsterAttackState` 施放，`attack_cooldown` 僅管這招冷卻。
@export var ranged_basic_skill: SkillResource
## 低於此距離不進遠程普攻（只走位／Spell 大絕），避免貼臉仍丟石。
@export var ranged_basic_min_dist: float = 52.0
## false：環境生物，不參與戰鬥鎖定與怪物 AI 互動，但可被封印。
@export var participates_in_combat: bool = true
@export var detection_range: float = 180.0
@export var actions_before_spell: int = 3 
@export var capture_rate: float = 0.5

@export_group("技能與掉落")
@export var skills: Array[SkillResource] = []
@export var drop_item: ItemResource
@export var drop_chance: float = 0.5
## 擊殺時固定入帳金幣（與掉落物機率無關）；0 表示不給金幣。
@export var gold_reward: int = 0
## 擊殺時分配給主角與出站寵物的經驗池總量（再平分）；0 表示不給經驗。
@export var xp_reward: int = 0

@export_group("視覺微調")
@export var sprite_frames: SpriteFrames

@export_group("頭飾錨點（基準＋免鉛筆列表）")
## 第一層整體基準：在 frame_offsets／anim_offsets 與下方 Dictionary 覆寫都未命中時使用（再才落到場景 AccessoryPoint 保底）。
@export var head_anchor_offset: Vector2 = DEFAULT_HEAD_ANCHOR_OFFSET
@export var anim_offsets: Array[AnimAnchorEntry] = []
@export var frame_offsets: Array[FrameAnchorEntry] = []
@export var add_anim_offset_row: bool = false:
	set(value):
		add_anim_offset_row = value
		if not value:
			return
		anim_offsets.append(AnimAnchorEntry.new())
		add_anim_offset_row = false
@export var add_frame_offset_row: bool = false:
	set(value):
		add_frame_offset_row = value
		if not value:
			return
		frame_offsets.append(FrameAnchorEntry.new())
		add_frame_offset_row = false
@export_group("視覺微調（相容舊資料）")
@export var animation_anchor_overrides: Dictionary = {}
@export var frame_anchor_overrides: Dictionary = {}
@export var accessory_offset: Vector2 = DEFAULT_HEAD_ANCHOR_OFFSET

@export_group("封印轉化")
@export var pet_data: PetResource

func resolve_head_anchor_offset(
	animation_name: StringName,
	frame_index: int,
	fallback_offset: Vector2 = DEFAULT_HEAD_ANCHOR_OFFSET
) -> Vector2:
	return HeadAnchorResolver.resolve_head_anchor_monster_exports(
		frame_offsets,
		anim_offsets,
		animation_name,
		frame_index,
		frame_anchor_overrides,
		animation_anchor_overrides,
		head_anchor_offset,
		accessory_offset,
		fallback_offset,
		DEFAULT_HEAD_ANCHOR_OFFSET
	)
