# res://src腳本/autoload管理員/SignalBus.gd
extends Node

# --- Sealing System Omni-Protocol v2.2 ---
# 警告：嚴禁在此腳本中進行任何邏輯運算，僅作為信號轉發站。

# [1. 基礎戰鬥與數值]
signal player_health_changed(current_hp: int, max_hp: int)
signal dash_requested                                     # 主角瞬移請求
signal damage_spawned(pos: Vector2, value: int, is_player: bool) # 傷害跳字 (世界座標)
signal heal_spawned(pos: Vector2, value: int)              # 補血跳字 (世界座標)

# [2. 物品採集與特效]
signal item_collected(item_data: Resource)                 # 物品進入背包數據
signal request_effect_collect(pos: Vector2, icon: Texture2D) # 物品飛行演出請求

# [3. 核心通用跳字系統]
# 用於顯示 "長壓怪物！！"、"Got you!"、"Fail" 等非數字提示
signal popup_text(target: Node2D, text: String, color: Color)

# [4. 封印系統核心協議 (防迴圈版)]

## 啟動協議：由 UI 按鈕發射，SealManager 接收
signal seal_mode_toggled(is_enabled: bool)

## 演繹協議：由 SealManager 發射，SealUI 接收 (UI 演員演繹)
signal seal_ui_requested(is_show: bool)
signal seal_draw_progress(progress: float)

## 🟢 安全重置協議：由 SealManager 發射，UI 按鈕與搖桿接收
## 用於「靜默彈起」按鈕，防止 Stack Overflow
signal seal_button_reset_requested

## 結算協議：封印成功後的世界演繹
signal seal_orb_fly(start_pos: Vector2)                    # 光球飛向寵物欄
signal seal_attempt_finished(success: bool, data: Resource) # 最終結果存檔

func _ready():
	print("[SignalBus] v2.2 協議已就緒。通信加密已啟動，防止循環呼叫。")
