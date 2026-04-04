# res://scenes場景/ui介面/PlayerXpRow.gd
extends HBoxContainer

@onready var _bar: ProgressBar = $PlayerXpBar
@onready var _lvl: Label = $PlayerLevelLabel


func _ready() -> void:
	if _bar:
		var h := int(maxf(4.0, _bar.custom_minimum_size.y))
		_bar.add_theme_stylebox_override("fill", HealthBarGradientUtil.create_xp_gradient_fill_stylebox(h))
		var base_bg := _bar.get_theme_stylebox("background")
		var bg_color := HealthBarGradientUtil.xp_bar_background_color(base_bg)
		_bar.add_theme_stylebox_override(
			"background",
			HealthBarGradientUtil.create_pixel_background_stylebox(h, bg_color)
		)
	if ProgressionManager:
		if not ProgressionManager.player_progress_changed.is_connected(_sync):
			ProgressionManager.player_progress_changed.connect(_sync)
	call_deferred("_sync")


func _sync() -> void:
	if ProgressionManager == null or _bar == null or _lvl == null:
		return
	_lvl.text = "Lv.%d" % ProgressionManager.player_level
	_bar.max_value = 100.0
	_bar.value = ProgressionManager.get_player_xp_bar_ratio() * 100.0
