# res://scenes場景/ui介面/HealthBar.gd
extends ProgressBar

func setup(target_health: HealthComponent) -> void:
	max_value = target_health.max_hp
	value = target_health.current_hp
	target_health.health_changed.connect(_on_health_changed)
	# 🔴 初始透明，由 MonsterBase 控制透明度
	self.modulate.a = 0

func _on_health_changed(curr: int, _max: int) -> void:
	value = curr
