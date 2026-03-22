# res://src腳本/ui/PlayerHUD.gd
extends TextureProgressBar

func _ready():
	# 這裡我們稍微打破一下解耦，因為 HUD 啟動時需要找主角
	var player = get_tree().get_first_node_in_group("player")
	if player:
		max_value = player.health.max_hp
		value = player.health.current_hp
		player.health.health_changed.connect(func(c, m): value = c)
