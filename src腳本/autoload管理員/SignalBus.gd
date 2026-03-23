# res://src腳本/autoload管理員/SignalBus.gd
extends Node
@warning_ignore("unused_signal")

# --- 1. 基礎戰鬥與數值 ---
signal player_health_changed(current_hp: int, max_hp: int)
signal dash_requested                                # 瞬移請求
signal damage_spawned(pos: Vector2, value: int, is_player: bool) # 傷害跳字
signal heal_spawned(pos: Vector2, value: int)         # 🔴 補上這個：補血跳字

# --- 2. 物品採集與特效 ---
signal item_collected(item_data: Resource)            # 物品進背包
signal request_effect_collect(pos: Vector2, icon: Texture2D) # 物品飛行特效

# --- 3. 核心通用跳字 (Got you! / Fail / 長壓提示) ---
signal popup_text(pos: Vector2, text: String, color: Color)

# --- 4. 封印系統協議 v2.1 ---
signal seal_mode_toggled(is_enabled: bool)            # 封印按鈕切換
signal seal_ui_requested(is_show: bool)               # UI 演員與濾鏡顯隱
signal seal_draw_progress(progress: float)            # 畫線進度同步 (0.0~1.0)
signal seal_button_reset_requested                    # 封印失敗後按鈕彈回
signal seal_orb_fly(start_pos: Vector2)               # 成功後的光球飛行演出
signal seal_attempt_finished(success: bool, data: Resource) # 封印最終結果通知

func _ready():
	print("[SignalBus] 頻道已全面升級至 v2.1，所有通訊正常。")
