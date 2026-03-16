# res://src/autoload/SignalBus.gd
extends Node

# --- 遊戲狀態訊號 ---
signal game_started
signal game_paused(is_paused: bool)

# --- 玩家相關訊號 (使用 Dictionary 傳遞多數值，或 Resource 傳遞對象) ---
signal player_health_changed(current_hp: int, max_hp: int)
signal player_exp_gained(amount: int)
signal player_leveled_up(new_level: int)

# --- 物品與蒐集 ---
# 這裡遵循我們的規範：傳送整個 Resource 資料，而非單一數值
signal item_collected(item_data: Resource) 

# --- 封印系統 (Pet Sealing) ---
signal seal_process_started(target_entity: CharacterBody2D)
signal seal_attempt_finished(is_success: bool, result_pet_data: Resource)

func _ready() -> void:
	print("[SignalBus] 電台已上線，準備轉發訊號。")

signal request_effect_collect(pos: Vector2, icon: Texture2D)
