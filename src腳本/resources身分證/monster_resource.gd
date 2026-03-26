# res://src腳本/resources身分證/monster_resource.gd
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
@export var detection_range: float = 180.0
@export var actions_before_spell: int = 3 
@export var capture_rate: float = 0.5

@export_group("技能與掉落")
@export var skills: Array[SkillResource] = []
@export var drop_item: ItemResource
@export var drop_chance: float = 0.5

@export_group("視覺微調")
@export var sprite_frames: SpriteFrames
@export var head_anchor_offset: Vector2 = DEFAULT_HEAD_ANCHOR_OFFSET
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
	var anim_key := String(animation_name)
	var frame_overrides_for_anim: Dictionary = frame_anchor_overrides.get(anim_key, {})
	if frame_overrides_for_anim.has(frame_index):
		var frame_value = frame_overrides_for_anim[frame_index]
		if frame_value is Vector2:
			return frame_value
	if animation_anchor_overrides.has(anim_key):
		var anim_value = animation_anchor_overrides[anim_key]
		if anim_value is Vector2:
			return anim_value
	if head_anchor_offset != DEFAULT_HEAD_ANCHOR_OFFSET or accessory_offset == DEFAULT_HEAD_ANCHOR_OFFSET:
		return head_anchor_offset
	if accessory_offset != DEFAULT_HEAD_ANCHOR_OFFSET:
		return accessory_offset
	return fallback_offset
