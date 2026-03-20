# res://src腳本/autoload管理員/SignalBus.gd
extends Node

# --- 遊戲狀態 ---
signal game_started

# --- 玩家與戰鬥 ---
signal player_health_changed(current_hp: int, max_hp: int)
signal dash_requested # 🔴 新增：瞬移請求訊號

# --- 物品與特效 ---
signal item_collected(item_data: Resource) 
signal request_effect_collect(pos: Vector2, icon: Texture2D) 

# --- 封印系統 ---
signal seal_mode_toggled(is_enabled: bool) # 控制封印模式開關
signal seal_process_started(target_entity: CharacterBody2D)

func _ready() -> void:
	print("[SignalBus] 電台頻道更新完畢，所有系統已可對接。")
