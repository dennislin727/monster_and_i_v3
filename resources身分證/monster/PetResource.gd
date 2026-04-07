# res://resources身分證/monster/PetResource.gd
class_name PetResource
extends Resource

@export_group("基礎身分")
@export var pet_id: String = ""
@export var instance_id: String = ""
@export var pet_name: String = "未命名寵物"
@export var nickname: String = ""
@export var icon: Texture2D
@export var sprite_frames: SpriteFrames # 繼承自怪物的視覺
## 頭飾錨點（frame_offsets 等）不在 PetResource：出戰時由 PetCompanion 場景覆寫，否則後備為 `resources身分證/monster/{pet_id}.tres`（MonsterResource）。

@export_group("成長與故事")
@export var level: int = 1
## 當前等級內累積、指向下一級的經驗（存檔／執行期由 ProgressionManager 寫入）。
@export var experience: int = 0
@export_multiline var story: String = ""
@export var skills: Array[PetSkillEntry] = []

@export_group("數值基準")
@export var follow_distance: float = 60.0
@export var follow_speed_mult: float = 1.1 # 稍微比主角快，才不會掉隊
@export var max_hp: int = 0 # 0 表示使用 GlobalBalance.PET_MAX_HP

@export_group("支援能力")
@export var heal_amount: int = 15
@export var heal_cooldown: float = 10.0
## 幸運被動：採集/採收時額外掉落機率加成（0~1）。
@export var luck_bonus_rate: float = 0.0
