# res://scenes場景/ui介面/HealthBar.gd
extends TextureProgressBar

func setup(target_health: HealthComponent) -> void:
<<<<<<< HEAD
	max_value = target_health.max_hp
	value = target_health.current_hp
	target_health.health_changed.connect(_on_health_changed)
	# 🔴 初始透明，由 MonsterBase 控制透明度
	self.modulate.a = 0

func _on_health_changed(curr: int, _max: int) -> void:
	value = curr
=======
	# 🔴 確保數值同步
	max_value = target_health.max_hp
	value = target_health.current_hp
	
	# 監聽血量變動
	target_health.health_changed.connect(_on_health_changed)
	
	# 初始隱藏，被打才顯示
	modulate.a = 0 

func _on_health_changed(curr: int, _max: int) -> void:
	value = curr
	
	# 療癒的淡入淡出效果
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.2) # 顯示
	t.tween_interval(2.0) # 停留兩秒
	t.tween_property(self, "modulate:a", 0.0, 0.5) # 消失
>>>>>>> 7b075d86e301c5e59bc262ee2693a51f1efe938d
