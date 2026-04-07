# res://scenes場景/ui介面/HealthBar.gd
extends ProgressBar

var _bound_health: HealthComponent = null
## 為 true 時略過戰鬥用漸層（例：編隊槽內嵌條改套咖啡色槽位主題）。
var skip_default_health_bar_theme: bool = false


func _ready() -> void:
	if skip_default_health_bar_theme:
		return
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


func setup(target_health: HealthComponent, hide_until_combat: bool = true) -> void:
	if _bound_health != null and is_instance_valid(_bound_health) and _bound_health.health_changed.is_connected(_on_health_changed):
		_bound_health.health_changed.disconnect(_on_health_changed)
	_bound_health = target_health
	max_value = target_health.max_hp
	value = target_health.current_hp
	if not target_health.health_changed.is_connected(_on_health_changed):
		target_health.health_changed.connect(_on_health_changed)
	# 怪物／石頭：初始透明，由 MonsterBase／Rock 每幀淡入。寵物欄位傳 false。
	self.modulate.a = 0.0 if hide_until_combat else 1.0


func unbind_health() -> void:
	if _bound_health != null and is_instance_valid(_bound_health) and _bound_health.health_changed.is_connected(_on_health_changed):
		_bound_health.health_changed.disconnect(_on_health_changed)
	_bound_health = null


func _on_health_changed(curr: int, _max: int) -> void:
	value = curr
