# res://scenes場景/ui介面/PlayerHUD.gd
extends ProgressBar

func _ready() -> void:
	var h := int(maxf(4.0, custom_minimum_size.y))
	add_theme_stylebox_override("fill", HealthBarGradientUtil.create_gradient_fill_stylebox(h))
	var base_bg := get_theme_stylebox("background")
	var bg_color := Color(0.08, 0.08, 0.1, 0.9)
	if base_bg is StyleBoxFlat:
		bg_color = (base_bg as StyleBoxFlat).bg_color
	add_theme_stylebox_override(
		"background",
		HealthBarGradientUtil.create_pixel_background_stylebox(h, bg_color)
	)
	SignalBus.player_health_changed.connect(_on_player_hp_changed)
	show_percentage = false
	value = 100
	max_value = 100
	# Player 在 UILayer 子節點就緒前會先 emit，這裡補抓一次實際血量。
	call_deferred("_sync_initial_hp_from_player")

func _sync_initial_hp_from_player() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var hc: HealthComponent = p.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null:
		return
	_on_player_hp_changed(hc.current_hp, hc.max_hp)

func _on_player_hp_changed(curr: int, m_hp: int) -> void:
	max_value = m_hp
	value = curr
