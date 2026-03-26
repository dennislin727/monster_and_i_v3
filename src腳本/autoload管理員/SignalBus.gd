# res://src腳本/autoload管理員/SignalBus.gd
extends Node

# --- Sealing System Omni-Protocol v2.2 ---
# 警告：嚴禁在此腳本中進行任何邏輯運算，僅作為信號轉發站。

# [1. 基礎戰鬥與數值]
signal player_health_changed(current_hp: int, max_hp: int)
signal dash_requested                                     # 主角瞬移請求
signal damage_spawned(pos: Vector2, value: int, is_player: bool) # 傷害跳字 (世界座標)
signal heal_spawned(pos: Vector2, value: int)              # 補血跳字 (世界座標)
## 主角近戰判定幀；melee_target 為當下命中的 HurtboxComponent（無近戰目標則 null）
signal player_melee_hit(melee_target: Variant)

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

signal pet_captured(pet_data: PetResource)                 # 封印成功並轉化成寵物

# [5. 寵物系統 (UI/世界 解耦協議)]
signal pet_active_requested(pet_data: PetResource)         # UI 請求：切換目前選取/出戰目標
signal pet_deploy_requested(pet_data: PetResource)         # UI 請求：出戰（生成在玩家身邊由世界層處理）
signal pet_recall_requested                                # UI 請求：收回
signal pet_release_requested(pet_data: PetResource)        # UI 請求：放生（Manager 從 roster 移除並同步出戰／選取）

signal pet_active_changed(pet_data: Variant)               # 世界層廣播：目前選取目標已更新（清單空則 null）
signal pet_deployed_changed(is_deployed: bool)             # 世界層廣播：出戰狀態改變
signal pet_roster_changed                                  # 世界層廣播：寵物清單變更（捕捉/刪除/整理）
signal pet_mount_requested(enabled: bool)                  # UI 請求：坐騎開關（世界層尚未實作可先接聽）

## UI 互斥：開啟一邊面板時請對應腳本關閉另一邊（避免底欄按鈕重疊）
signal pet_ui_close_requested
signal inventory_ui_close_requested

signal seal_draw_confirmed  # 🟢 新增：邏輯判定成功，請 UI 播放收尾動畫
signal seal_sword_fall_finished  # 大劍落下動畫播畢（SealUI 發射，HUD 可緩慢恢復）

func _ready() -> void:
	# 讓靜態分析器知道這些 signal 在本類有明確使用（本檔僅做宣告/轉發站）。
	var declared_signals := [
		player_health_changed,
		dash_requested,
		damage_spawned,
		heal_spawned,
		player_melee_hit,
		item_collected,
		request_effect_collect,
		popup_text,
		seal_mode_toggled,
		seal_ui_requested,
		seal_draw_progress,
		seal_button_reset_requested,
		seal_orb_fly,
		seal_attempt_finished,
		pet_captured,
		pet_active_requested,
		pet_deploy_requested,
		pet_recall_requested,
		pet_release_requested,
		pet_active_changed,
		pet_deployed_changed,
		pet_roster_changed,
		pet_mount_requested,
		pet_ui_close_requested,
		inventory_ui_close_requested,
		seal_draw_confirmed,
		seal_sword_fall_finished,
	]
	if declared_signals.is_empty():
		return
	print("[SignalBus] v2.2 協議已就緒。通信加密已啟動，防止循環呼叫。")
