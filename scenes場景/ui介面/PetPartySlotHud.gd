# res://scenes場景/ui介面/PetPartySlotHud.gd
# 槽內：血條與按鈕同寬同高（填滿槽位，咖啡色槽位主題），上層咖啡框透明按鈕＋白字；槽下 XP 條。寵物頭頂血條已隱藏。
extends Control

const _HP_BAR_SCENE := preload("res://scenes場景/ui介面/HealthBar.tscn")
const _SLOT_BTN_W := 41.0
const _SLOT_BTN_H := 28.0
const _SLOT_ROW_GAP := 2.0
const _GAP_BELOW_SAVE_ROW := 10.0
const _COL_GAP := 6.0
const _SLOT_BORDER := Color(0.29, 0.22, 0.16, 1)
const _SLOT_CORNER := 5
const _SLOT_TEXT_WHITE := Color(1, 1, 1, 1)
const _SLOT_RECALL_FADE_SEC := 0.16

var _pixel_font: Font
var _slot_roots: Array[Control] = []
var _buttons: Array[Button] = []
var _slot_hp_bars: Array[ProgressBar] = []
var _xp_bars: Array[ProgressBar] = []
var _party_hud_shown: bool = false
var _fade_tween: Tween
var _slot_hp_health: Array[HealthComponent] = []
var _slot_recall_pending: Array[bool] = []


func _apply_xp_bar_style(xp: ProgressBar) -> void:
	var h := int(maxf(4.0, xp.custom_minimum_size.y))
	xp.add_theme_stylebox_override("fill", HealthBarGradientUtil.create_xp_gradient_fill_stylebox(h))
	xp.add_theme_stylebox_override(
		"background",
		HealthBarGradientUtil.create_pixel_background_stylebox(
			h,
			HealthBarGradientUtil.xp_bar_background_color(null)
		)
	)


func _make_party_slot_border_stylebox(bg_alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, bg_alpha)
	s.set_border_width_all(2)
	s.border_color = _SLOT_BORDER
	s.set_corner_radius_all(_SLOT_CORNER)
	return s


func _apply_party_slot_overlay_button(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 10)
	if _pixel_font:
		b.add_theme_font_override("font", _pixel_font)
	for theme_key in [
		"font_color", "font_hover_color", "font_pressed_color",
		"font_focus_color", "font_disabled_color"
	]:
		b.add_theme_color_override(theme_key, _SLOT_TEXT_WHITE)
	b.add_theme_stylebox_override("normal", _make_party_slot_border_stylebox(0.0))
	b.add_theme_stylebox_override("hover", _make_party_slot_border_stylebox(0.06))
	b.add_theme_stylebox_override("pressed", _make_party_slot_border_stylebox(0.1))
	b.add_theme_stylebox_override("focus", _make_party_slot_border_stylebox(0.06))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _make_slot_hp_bar() -> ProgressBar:
	var anchor := _HP_BAR_SCENE.instantiate()
	var bar := anchor.get_node_or_null("HealthBar") as ProgressBar
	if bar == null:
		anchor.queue_free()
		push_error("PetPartySlotHud: HealthBar.tscn missing HealthBar child")
		return null
	anchor.remove_child(bar)
	anchor.queue_free()
	bar.owner = null
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(_SLOT_BTN_W, _SLOT_BTN_H)
	bar.skip_default_health_bar_theme = true
	HealthBarGradientUtil.apply_party_slot_hp_bar_theme(bar, int(_SLOT_BTN_H), _SLOT_BORDER, 2)
	return bar


func _detach_slot_health(slot_index: int) -> void:
	if slot_index < 0:
		return
	while _slot_hp_health.size() <= slot_index:
		_slot_hp_health.append(null)
	if slot_index < _slot_hp_bars.size():
		var bar: ProgressBar = _slot_hp_bars[slot_index]
		if bar.has_method("unbind_health"):
			bar.call("unbind_health")
		bar.max_value = 100.0
		bar.value = 100.0
		bar.modulate.a = 1.0
	_slot_hp_health[slot_index] = null


func _health_for_party_slot(slot_index: int) -> HealthComponent:
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("deployed_pet"):
		if not is_instance_valid(n):
			continue
		if not n.has_method("get_party_slot_index"):
			continue
		if int(n.call("get_party_slot_index")) != slot_index:
			continue
		return n.get_node_or_null("HealthComponent") as HealthComponent
	return null


func _connect_slot_health(slot_index: int, h: HealthComponent) -> void:
	_detach_slot_health(slot_index)
	while _slot_hp_health.size() <= slot_index:
		_slot_hp_health.append(null)
	var bar: ProgressBar = _slot_hp_bars[slot_index]
	if bar.has_method("setup"):
		bar.call("setup", h, false)
	_slot_hp_health[slot_index] = h


func _sync_all_slot_health_bindings() -> void:
	for i in PetManager.PARTY_SLOT_COUNT:
		if i >= _slot_hp_bars.size():
			break
		var p: PetResource = null
		if i < PetManager.party_slots.size():
			p = PetManager.party_slots[i] as PetResource
		if p == null:
			_detach_slot_health(i)
			continue
		var bound: HealthComponent = _slot_hp_health[i] if i < _slot_hp_health.size() else null
		if bound != null and not is_instance_valid(bound):
			_detach_slot_health(i)
		var h := _health_for_party_slot(i)
		if h != null and is_instance_valid(h):
			if i >= _slot_hp_health.size() or _slot_hp_health[i] != h:
				_connect_slot_health(i, h)
		else:
			_detach_slot_health(i)


func _queue_health_resync() -> void:
	call_deferred("_deferred_slot_health_sync_runner")


func _deferred_slot_health_sync_runner() -> void:
	_slot_health_sync_after_two_frames()


func _slot_health_sync_after_two_frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_sync_all_slot_health_bindings()


func _on_deployed_resync_slot_hp(_is_deployed: bool) -> void:
	_queue_health_resync()


func _on_field_companion_spawned(_slot_index: int) -> void:
	call_deferred("_sync_all_slot_health_bindings")


func _ready() -> void:
	_pixel_font = load("res://assets圖片_字體_音效/PixelFont.ttf") as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_hp_health.resize(PetManager.PARTY_SLOT_COUNT)
	_slot_recall_pending.resize(PetManager.PARTY_SLOT_COUNT)
	for j in PetManager.PARTY_SLOT_COUNT:
		_slot_hp_health[j] = null
		_slot_recall_pending[j] = false
	for i in PetManager.PARTY_SLOT_COUNT:
		var root := Control.new()
		root.name = "PartySlotRoot%d" % i
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.clip_contents = false
		root.custom_minimum_size = Vector2(_SLOT_BTN_W, _SLOT_BTN_H)
		root.size = Vector2(_SLOT_BTN_W, _SLOT_BTN_H)
		var hp_bar := _make_slot_hp_bar()
		if hp_bar:
			hp_bar.name = "PartySlotHp%d" % i
			hp_bar.visible = false
			root.add_child(hp_bar)
			_slot_hp_bars.append(hp_bar)
		var b := Button.new()
		b.name = "PartyBtn%d" % i
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		_apply_party_slot_overlay_button(b)
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.offset_left = 0
		b.offset_top = 0
		b.offset_right = 0
		b.offset_bottom = 0
		var idx := i
		b.pressed.connect(_on_slot_pressed.bind(idx))
		root.add_child(b)
		_buttons.append(b)
		add_child(root)
		_slot_roots.append(root)
		var xp := ProgressBar.new()
		xp.name = "PartySlotXp%d" % i
		xp.show_percentage = false
		xp.custom_minimum_size = Vector2(_SLOT_BTN_W, 4)
		xp.max_value = 100.0
		xp.value = 0.0
		_apply_xp_bar_style(xp)
		add_child(xp)
		_xp_bars.append(xp)
	z_index = 16
	if SignalBus:
		SignalBus.pet_party_changed.connect(_on_party_changed)
		SignalBus.pet_deployed_changed.connect(_on_deployed_resync_slot_hp)
		if not SignalBus.pet_party_field_companion_spawned.is_connected(_on_field_companion_spawned):
			SignalBus.pet_party_field_companion_spawned.connect(_on_field_companion_spawned)
		SignalBus.pet_roster_changed.connect(_refresh_labels)
		SignalBus.pet_nickname_changed.connect(_on_pet_nickname_changed)
	if ProgressionManager:
		ProgressionManager.player_progress_changed.connect(_on_any_progress_refresh)
	_refresh_labels()
	_apply_initial_visibility()
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_reflow_slots)
	_reflow_slots.call_deferred()


func _kill_fade_tween() -> void:
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null


func _apply_initial_visibility() -> void:
	_party_hud_shown = PetManager.is_deployed
	if _party_hud_shown:
		visible = true
		modulate.a = 1.0
	else:
		modulate.a = 0.0
		visible = false


func _on_party_changed() -> void:
	_refresh_labels()
	var want_show := PetManager.is_deployed
	if want_show == _party_hud_shown:
		return
	_party_hud_shown = want_show
	_kill_fade_tween()
	var dur_in := GlobalBalance.HUD_FADE_IN_SEC if GlobalBalance else 0.6
	var dur_out := GlobalBalance.HUD_FADE_OUT_SEC if GlobalBalance else 0.6
	_fade_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if want_show:
		visible = true
		modulate.a = 0.0
		_fade_tween.tween_property(self, "modulate:a", 1.0, dur_in)
	else:
		_fade_tween.tween_property(self, "modulate:a", 0.0, dur_out)
		_fade_tween.finished.connect(_on_fade_out_hide, CONNECT_ONE_SHOT)


func _on_fade_out_hide() -> void:
	if not PetManager.is_deployed:
		visible = false


func _on_pet_nickname_changed(_pet_data: PetResource) -> void:
	_refresh_labels()


func _on_any_progress_refresh() -> void:
	_refresh_labels()


func _reflow_slots() -> void:
	if _slot_roots.size() < 3:
		return
	var rect := get_viewport().get_visible_rect()
	var h: float = rect.size.y
	var w: float = rect.size.x
	var save_row_bottom := 0.059 * h + 20.24
	var row_top := save_row_bottom + _GAP_BELOW_SAVE_ROW
	var cx := 0.101 * w
	var hb_left := 0.42 * w - 85.88
	_slot_roots[0].position = Vector2(cx - _SLOT_BTN_W * 0.5, row_top)
	_slot_roots[0].size = Vector2(_SLOT_BTN_W, _SLOT_BTN_H)
	_slot_roots[1].position = Vector2(hb_left, row_top)
	_slot_roots[1].size = Vector2(_SLOT_BTN_W, _SLOT_BTN_H)
	_slot_roots[2].position = Vector2(hb_left + _SLOT_BTN_W + _COL_GAP, row_top)
	_slot_roots[2].size = Vector2(_SLOT_BTN_W, _SLOT_BTN_H)
	var n := mini(3, mini(_slot_roots.size(), _slot_hp_bars.size()))
	for si in n:
		var r := _slot_roots[si]
		var hb := _slot_hp_bars[si]
		hb.position = Vector2.ZERO
		hb.size = r.size
	var y_xp := row_top + _SLOT_BTN_H + _SLOT_ROW_GAP
	if _xp_bars.size() >= 3:
		_xp_bars[0].position = Vector2(cx - _SLOT_BTN_W * 0.5, y_xp)
		_xp_bars[0].size = Vector2(_SLOT_BTN_W, 4)
		_xp_bars[1].position = Vector2(hb_left, y_xp)
		_xp_bars[1].size = Vector2(_SLOT_BTN_W, 4)
		_xp_bars[2].position = Vector2(hb_left + _SLOT_BTN_W + _COL_GAP, y_xp)
		_xp_bars[2].size = Vector2(_SLOT_BTN_W, 4)


func _refresh_labels() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		var p: PetResource = null
		if i < PetManager.party_slots.size():
			p = PetManager.party_slots[i] as PetResource
		if i < _slot_roots.size():
			_slot_roots[i].visible = p != null
		if p == null:
			b.visible = false
			b.text = ""
			b.tooltip_text = ""
			_detach_slot_health(i)
			if i < _slot_hp_bars.size():
				_slot_hp_bars[i].visible = false
			if i < _xp_bars.size():
				_xp_bars[i].visible = false
		else:
			if i < _slot_recall_pending.size():
				_slot_recall_pending[i] = false
			if i < _slot_roots.size():
				_slot_roots[i].modulate.a = 1.0
			b.visible = true
			b.disabled = false
			b.modulate.a = 1.0
			var nm := p.nickname.strip_edges() if p.nickname.strip_edges() != "" else (
				p.pet_name if p.pet_name.strip_edges() != "" else p.pet_id
			)
			b.text = nm
			b.tooltip_text = "槽位 %d：%s（點擊收回）" % [i + 1, nm]
			if i < _slot_hp_bars.size():
				_slot_hp_bars[i].visible = true
				_slot_hp_bars[i].modulate.a = 1.0
			if i < _xp_bars.size():
				var xpb := _xp_bars[i]
				xpb.visible = true
				xpb.modulate.a = 1.0
				xpb.value = _pet_xp_ratio_percent(p)
	_queue_health_resync()


func _pet_xp_ratio_percent(p: PetResource) -> float:
	if p == null or GlobalBalance == null:
		return 0.0
	if p.level >= GlobalBalance.PET_MAX_LEVEL:
		return 100.0
	var need := GlobalBalance.xp_needed_for_pet_next_level(p.level)
	if need <= 0:
		return 100.0
	return clampf(float(p.experience) * 100.0 / float(need), 0.0, 100.0)


func _on_slot_pressed(slot_index: int) -> void:
	if not visible or modulate.a < 0.05:
		return
	if slot_index < 0 or slot_index >= PetManager.party_slots.size():
		return
	if slot_index < _slot_recall_pending.size() and _slot_recall_pending[slot_index]:
		return
	if PetManager.party_slots[slot_index] == null:
		return
	if slot_index < _slot_recall_pending.size():
		_slot_recall_pending[slot_index] = true
	var root: Control = _slot_roots[slot_index] if slot_index < _slot_roots.size() else null
	var b: Button = _buttons[slot_index] if slot_index < _buttons.size() else null
	var hp: ProgressBar = _slot_hp_bars[slot_index] if slot_index < _slot_hp_bars.size() else null
	var xp: ProgressBar = _xp_bars[slot_index] if slot_index < _xp_bars.size() else null
	if b != null:
		b.disabled = true
	if root != null:
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(root, "modulate:a", 0.0, _SLOT_RECALL_FADE_SEC)
		if hp != null:
			tw.parallel().tween_property(hp, "modulate:a", 0.0, _SLOT_RECALL_FADE_SEC)
		if xp != null:
			tw.parallel().tween_property(xp, "modulate:a", 0.0, _SLOT_RECALL_FADE_SEC)
		await tw.finished
	if SignalBus:
		SignalBus.pet_party_slot_recall_requested.emit(slot_index)
