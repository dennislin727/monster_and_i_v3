# res://src腳本/autoload管理員/SignalBus.gd
@warning_ignore("unused_signal")
extends Node

# --- 遊戲狀態 ---
signal game_started

# --- 玩家與戰鬥 ---
signal player_health_changed(current_hp: int, max_hp: int)
signal dash_requested # 🔴 新增：瞬移請求訊號
signal damage_spawned(pos: Vector2, value: int, is_player: bool) # 🔴 飄字請求

# --- 物品與特效 ---
signal item_collected(item_data: Resource) 
signal request_effect_collect(pos: Vector2, icon: Texture2D) 

# --- 封印系統 ---
signal seal_mode_toggled(is_enabled: bool) # 控制封印模式開關
signal seal_process_started(target_entity: CharacterBody2D)
signal seal_ui_requested(is_show: bool) # 🔴 通知 UI 顯示濾鏡與張眼
signal seal_button_reset_requested     # 🔴 當封印失敗，通知按鈕恢復原狀
signal seal_draw_progress(progress: float)   # 傳遞畫線進度 (0.0 ~ 1.0)
signal seal_sword_fall(pos: Vector2)         # 觸發巨劍落下特效
signal seal_result_visual(is_success: bool)  # 觸發結果演繹 (Happy/Sad/Text)
signal seal_orb_fly(start_pos: Vector2)      # 成功後的光球飛行
signal popup_text(pos: Vector2, text: String, color: Color) # 新增通用跳字訊號

func _ready() -> void:
	print("[SignalBus] 電台頻道更新完畢，所有系統已可對接。")
