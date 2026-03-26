# res://scenes場景/ui介面/PlayerHUD.gd
extends ProgressBar

func _ready() -> void:
	SignalBus.player_health_changed.connect(_on_player_hp_changed)
	show_percentage = false
	value = 100
	max_value = 100

func _on_player_hp_changed(curr: int, m_hp: int) -> void:
	max_value = m_hp
	value = curr
