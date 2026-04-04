# res://resources身分證/dialogue/dialogue_choice_entry.gd
class_name DialogueChoiceEntry
extends Resource

@export var text: String = ""
## 下一節點 id；設為 DialogueGraphResource.CLOSE_SENTINEL 代表關閉對話
@export var target_node_id: String = ""
## >0 時：僅當 NpcStateManager 好感 >= 此值才顯示
@export var min_affinity: int = 0
## 非空：僅當該 grant_once 尚未完成時顯示（與 DialogueEffectEntry.grant_once_id 對齊）
@export var require_grant_once_pending: String = ""
## 非空：僅當該 grant_once 已完成時顯示
@export var require_grant_once_done: String = ""
## true：隊伍至少一隻出戰寵物才顯示
@export var require_party_non_empty: bool = false
## true：隊伍必須為空才顯示
@export var require_party_empty: bool = false
## true：僅家園場景顯示（資料驅動條件）
@export var require_in_homestead: bool = false
## 選取時（關閉或進下一節前）：主角播 happy（對話獎勵，略過採集拾取冷卻）
@export var on_select_play_player_happy: bool = false
## 非空：主角頭上白字（HarvestModeHint `instant_text`；可選 hold_sec／fade_out_sec）
@export var on_select_world_hint_instant_text: String = ""
