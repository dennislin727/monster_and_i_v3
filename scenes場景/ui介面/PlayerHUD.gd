# res://scenes場景/ui介面/PlayerHUD.gd
extends TextureProgressBar

func _ready():
	# 🔴 改為直接聽電台，不去找主角節點
	SignalBus.player_health_changed.connect(_on_player_hp_changed)
	
	# 初始隱藏，直到收到第一次血量通知（或手動初始化）
	# 如果想一開始看到，可以先設為 100/100
	value = 100
	max_value = 100

func _on_player_hp_changed(curr: int, m_hp: int):
	max_value = m_hp
	value = curr
	print("[HUD] 收到血量更新: ", curr)
