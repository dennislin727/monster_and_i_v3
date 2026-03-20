# res://src腳本/ui/HealthBar.gd
extends TextureProgressBar

var health_component: HealthComponent

func setup(target_health: HealthComponent) -> void:
	health_component = target_health
	health_component.health_changed.connect(_on_health_changed)
	max_value = health_component.max_hp
	value = health_component.current_hp
	hide() # 初始隱藏

func _on_health_changed(curr: int, _max: int) -> void:
	value = curr
	show() # 被打就顯示
	
	# 簡單的消失計時器
	var t = create_tween()
	t.tween_interval(2.0)
	t.tween_callback(hide)
