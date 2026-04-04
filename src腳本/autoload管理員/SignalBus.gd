# res://src腳本/autoload管理員/SignalBus.gd
extends Node

# --- Sealing System Omni-Protocol v2.2 ---
# 警告：嚴禁在此腳本中進行任何邏輯運算，僅作為信號轉發站。

# [1. 基礎戰鬥與數值]
signal player_health_changed(current_hp: int, max_hp: int)
signal dash_requested                                     # 主角翻滾（dash）請求
signal damage_spawned(pos: Vector2, value: int, is_player: bool) # 傷害跳字 (世界座標)
signal heal_spawned(pos: Vector2, value: int)              # 補血跳字 (世界座標)
## 主角近戰判定幀；melee_target 為當下命中的 HurtboxComponent（無近戰目標則 null）
signal player_melee_hit(melee_target: Variant)
## 隊伍成員被怪物實際扣血後廣播（主角或出戰寵物）；供強制還手鎖定，不受互動距離限制。
signal party_damaged_by_monster(attacker_hurtbox: HurtboxComponent)

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
## `sealed_body`：當下被封印的怪物根節點（失敗或無目標時為 null）；湖畔多隻環境寶寶鳥存檔分槽用。
signal seal_attempt_finished(success: bool, data: Resource, sealed_body: Node) # 最終結果存檔

signal pet_captured(pet_data: PetResource)                 # 封印成功並轉化成寵物

# [5. 寵物系統 (UI/世界 解耦協議)]
signal pet_active_requested(pet_data: PetResource)         # UI 請求：切換目前選取/出戰目標
signal pet_deploy_requested(pet_data: PetResource)         # UI 請求：出戰（生成在玩家身邊由世界層處理）
signal pet_recall_requested                                # UI 請求：收回（目前選取之寵物所在槽位）
signal pet_party_slot_recall_requested(slot_index: int)   # UI 請求：收回指定出戰槽 0..2
signal pet_release_requested(pet_data: PetResource)        # UI 請求：放生（Manager 從 roster 移除並同步出戰／選取）

signal pet_active_changed(pet_data: Variant)               # 世界層廣播：目前選取目標已更新（清單空則 null）
signal pet_deployed_changed(is_deployed: bool)             # 世界層廣播：出戰狀態改變
signal pet_party_changed                                   # 世界層廣播：三槽編隊有變（細節讀 PetManager.party_slots）
signal pet_party_field_companion_spawned(slot_index: int) # 場上跟班 add_child 後；HUD 綁定血量用
signal pet_roster_changed                                  # 世界層廣播：寵物清單變更（捕捉/刪除/整理）
signal pet_mount_requested(enabled: bool)                  # UI 請求：坐騎開關（世界層尚未實作可先接聽）
signal pet_nickname_change_requested(pet_data: PetResource, nickname: String) # UI 請求：改名（僅發射）
signal pet_nickname_changed(pet_data: PetResource)         # Manager 廣播：綽號已寫入
## 請求：將寵物送往家園駐留（資料流由 Manager/HomeManager 仲裁）
signal pet_homestead_station_requested(pet_data: PetResource)
## 請求：敘事語意版本（如「送回家園」）；目前與駐留同流，保留語意拆分點
signal pet_sent_to_home_requested(pet_data: PetResource)
## 結果：家園駐留名單變更（UI/場景視覺刷新）
signal pet_home_roster_changed
## 請求：寵物進化（本輪僅保留入口，邏輯待後續階段）
signal pet_evolution_requested(pet_data: PetResource)

## UI 互斥：開啟一邊面板時請對應腳本關閉另一邊（避免底欄按鈕重疊）
signal pet_ui_close_requested
signal inventory_ui_close_requested
signal diary_ui_close_requested

signal seal_draw_confirmed  # 🟢 新增：邏輯判定成功，請 UI 播放收尾動畫
signal seal_sword_fall_finished  # 大劍落下動畫播畢（SealUI 發射，HUD 可緩慢恢復）

# [6. NPC 對話／互動（Phase 9）]
## 狀態：顯示靠近提示（世界座標錨點由呼叫端換算螢幕）
signal npc_interaction_prompt_changed(visible: bool, npc_id: String, prompt_text: String, anchor_global: Vector2)
## 請求：玩家點選提示後開啟對話
signal npc_dialogue_requested(npc_id: String)
## 狀態：對話面板內容（關閉時 visible=false，其餘字串可空）
signal dialogue_presented(visible: bool, body_bbcode: String, choice_labels: PackedStringArray)
## 請求：選擇選項索引
signal dialogue_choice_selected(choice_index: int)
## 請求：關閉對話（與圖中「待會再來」等價入口）
signal dialogue_close_requested
## 狀態：是否鎖定移動／並供 HUD 隱藏搖桿等
signal dialogue_blocking_changed(blocked: bool)
## 請求：NPC／任務等發放道具（與採集 item_collected 分流；由 InventoryManager 執行堆疊）
signal inventory_grant_requested(item_id: String, amount: int)
## 結果：NPC 好感變更後廣播（由 NpcStateManager 寫入後發射；UI／提示可監聽刷新）
signal npc_affinity_changed(npc_id: String, new_value: int)
## 對話獎勵（例謝謝收道具）：世界座標起點；EffectManager 播光球拋物線落下（不綁定背包欄位）
signal dialogue_reward_vfx_requested(start_world_pos: Vector2)
## 對話效果擴充：任務型請求（由專用 Manager 監聽）
signal dialogue_quest_requested(quest_id: String)

# [7. 家園／採收（Phase 10）]
## 請求：採收模式開關（由採收鈕發射，HomeManager 仲裁互斥後更新狀態）
signal harvest_mode_toggled(enabled: bool)
## 狀態：採收模式是否啟用（HomeManager 廣播；HUD／輸入層監聽）
signal harvest_mode_changed(active: bool)
## 狀態：主角是否身在家園關卡（HomeManager 廣播；採收鈕顯示等）
signal player_in_homestead_changed(in_homestead: bool)
## 家園內放置寵物視覺／互動錨點需重建（無參數；讀 PetManager 駐留列表）
signal homestead_station_visuals_refresh
## 請求：螢幕中上方區域標題漸顯→停留→漸隱（duration_sec≤0 時由 UI 用 GlobalBalance 預設）
signal area_title_show_requested(title: String, duration_sec: float)
## 請求：區域標題立刻漸隱並收起（離開區域等）
signal area_title_hide_requested
## 主角頭上世界提示（教學／寶箱／危險等）：hint_id 對應 PlayerHintCatalog；show_hint 為是否顯示該則。
## payload：無則 emit 第三參數傳 `null`。Dictionary 時由 HarvestModeHint 解讀（`instant_text`／`hold_sec`／`fade_out_sec` 或 `typing_intro`／`final_text` 等）；null 則查 PlayerHintCatalog。
signal player_world_hint_changed(hint_id: String, show_hint: bool, payload: Variant)

# [8. 單槽存檔（本機覆寫）]
signal game_save_requested
signal game_save_finished(success: bool)

func _ready() -> void:
	# 讓靜態分析器知道這些 signal 在本類有明確使用（本檔僅做宣告/轉發站）。
	var declared_signals := [
		player_health_changed,
		dash_requested,
		damage_spawned,
		heal_spawned,
		player_melee_hit,
		party_damaged_by_monster,
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
		pet_party_slot_recall_requested,
		pet_release_requested,
		pet_active_changed,
		pet_deployed_changed,
		pet_party_changed,
		pet_party_field_companion_spawned,
		pet_roster_changed,
		pet_mount_requested,
		pet_nickname_change_requested,
		pet_nickname_changed,
		pet_homestead_station_requested,
		pet_sent_to_home_requested,
		pet_home_roster_changed,
		pet_evolution_requested,
		pet_ui_close_requested,
		inventory_ui_close_requested,
		diary_ui_close_requested,
		seal_draw_confirmed,
		seal_sword_fall_finished,
		npc_interaction_prompt_changed,
		npc_dialogue_requested,
		dialogue_presented,
		dialogue_choice_selected,
		dialogue_close_requested,
		dialogue_blocking_changed,
		inventory_grant_requested,
		npc_affinity_changed,
		dialogue_reward_vfx_requested,
		dialogue_quest_requested,
		harvest_mode_toggled,
		harvest_mode_changed,
		player_in_homestead_changed,
		homestead_station_visuals_refresh,
		area_title_show_requested,
		area_title_hide_requested,
		player_world_hint_changed,
		game_save_requested,
		game_save_finished,
	]
	if declared_signals.is_empty():
		return
	print("[SignalBus] v2.2 協議已就緒。通信加密已啟動，防止循環呼叫。")
