# res://src腳本/autoload管理員/PlayerHintCatalog.gd
extends Node
## 主角頭上／世界情境提示文案目錄（教學、寶箱、危險區等）。
## 觸發端發 `SignalBus.player_world_hint_changed(hint_id, show_hint, payload?)`；無 payload 時由此查表；有 payload（如打字序列）由 HarvestModeHint 解讀。

## 家園：有成熟作物、未開採收模式（目前改由 HomeManager 一次性 instant 提醒，此 id 保留相容）
const HINT_HOMESTEAD_TAP_HARVEST := "homestead_harvest_tap"
## 家園：採收模式中、仍有成熟作物 → 滑掃教學（僅全遊戲第一次採收流程，採滿 2 株後關閉）
const HINT_HOMESTEAD_SWIPE := "homestead_harvest_swipe"
## 家園：採收模式中、已無成熟作物 → 收工提示
const HINT_HOMESTEAD_NO_CROPS := "homestead_harvest_no_crops"
## 預留：等級／危險偵測、寶物提示等
const HINT_WORLD_DANGER_SOFT := "world_danger_soft"


func resolve_text(hint_id: String) -> String:
	match hint_id:
		HINT_HOMESTEAD_TAP_HARVEST:
			return "可點擊採收按鈕進行收割！"
		HINT_HOMESTEAD_SWIPE:
			return "在作物上用手指拖曳～"
		HINT_HOMESTEAD_NO_CROPS:
			return ""
		HINT_WORLD_DANGER_SOFT:
			return "這裡可能有點危險…"
		_:
			return ""
