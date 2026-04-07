# res://resources身分證/dialogue/dialogue_effect_entry.gd
class_name DialogueEffectEntry
extends Resource

enum Kind { NONE, GIVE_ITEM, ADD_AFFINITY, REQUEST_QUEST }

@export var kind: Kind = Kind.NONE
@export var item_id: String = ""
@export var amount: int = 1
## 非空時：每名 NPC 此 key 僅成功發放一次（與 GIVE_ITEM 併用）
@export var grant_once_id: String = ""
## 非空：本次效果實際執行後（含首次 grant_once 發放）解鎖生涯成就 id（見 DiaryManager.CAREER_TITLES）
@export var career_milestone_id: String = ""
## kind == ADD_AFFINITY 時套用（可正可負）
@export var affinity_delta: int = 0
## kind == REQUEST_QUEST 時：送出任務請求 id（由專用 Manager 消費）
@export var quest_request_id: String = ""
