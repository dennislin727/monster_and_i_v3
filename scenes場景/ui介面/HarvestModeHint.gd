# res://scenes場景/ui介面/HarvestModeHint.gd
extends Label
## 主角螢幕位置上方白字提示（無底、無框）；跟隨座標，不寫入玩家狀態。
## `player_world_hint_changed`：無 payload 時查 PlayerHintCatalog；Dictionary 含 `instant_text` 時單行白字（可選 `hold_sec`／`fade_out_sec`）；含 `typing_intro`+`final_text` 時跑打字序列。

## 主角腳底螢幕點往上偏移（像素；Y 愈小愈高，避開頭飾）
const _OFFSET_ABOVE_FEET := Vector2(0, -118)

var _active_hint_id: String = ""
var _seq_token: int = 0
var _fade_tween: Tween


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_OFF
	custom_minimum_size = Vector2(300, 52)
	add_theme_constant_override("line_spacing", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	text = ""
	z_index = 15
	add_theme_color_override("font_color", Color(1, 1, 1, 1))
	# 與 PetCompanion.tscn → NameLabel 一致：白字 + 向下 1px、半透明黑陰影
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.2))
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_constant_override("shadow_offset_y", 1)
	if SignalBus:
		SignalBus.player_world_hint_changed.connect(_on_player_world_hint_changed)


func _kill_fade_tween() -> void:
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null


func _reset_visual_state() -> void:
	_kill_fade_tween()
	modulate = Color(1, 1, 1, 1)


func _on_player_world_hint_changed(hint_id: String, show_hint: bool, payload: Variant = null) -> void:
	if show_hint:
		_seq_token += 1
		var run_id := _seq_token
		_reset_visual_state()
		if payload is Dictionary:
			var ins := str((payload as Dictionary).get("instant_text", "")).strip_edges()
			if not ins.is_empty():
				_active_hint_id = hint_id if not hint_id.is_empty() else "instant"
				text = ins
				visible = true
				_run_instant_hint_timed(payload as Dictionary, run_id)
				return
		if _is_typing_sequence_payload(payload):
			_active_hint_id = hint_id
			visible = true
			text = ""
			_run_typed_then_final(payload as Dictionary, run_id)
			return
		if not PlayerHintCatalog:
			return
		var t: String = PlayerHintCatalog.resolve_text(hint_id)
		if t.is_empty():
			return
		_active_hint_id = hint_id
		text = t
		visible = true
		return
	_seq_token += 1
	_reset_visual_state()
	if hint_id.is_empty() or hint_id == _active_hint_id:
		visible = false
		_active_hint_id = ""
		text = ""


func _run_instant_hint_timed(payload: Dictionary, run_id: int) -> void:
	var hold := maxf(0.3, float(payload.get("hold_sec", 2.2)))
	var fade := maxf(0.05, float(payload.get("fade_out_sec", GlobalBalance.HUD_FADE_OUT_SEC if GlobalBalance else 0.6)))
	await get_tree().create_timer(hold).timeout
	if run_id != _seq_token:
		return
	_kill_fade_tween()
	modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade)
	_fade_tween.tween_callback(func() -> void:
		if run_id != _seq_token:
			return
		visible = false
		text = ""
		_active_hint_id = ""
		modulate = Color(1, 1, 1, 1)
		_fade_tween = null
	)


func _is_typing_sequence_payload(payload: Variant) -> bool:
	if not (payload is Dictionary):
		return false
	var d: Dictionary = payload
	var a := str(d.get("typing_intro", "")).strip_edges()
	var b := str(d.get("final_text", "")).strip_edges()
	return not a.is_empty() and not b.is_empty()


func _run_typed_then_final(payload: Dictionary, run_id: int) -> void:
	var intro: String = str(payload.get("typing_intro", ""))
	var final_t: String = str(payload.get("final_text", ""))
	var csec: float = maxf(0.02, float(payload.get("typing_char_sec", 0.06)))
	var intro_pause: float = maxf(0.0, float(payload.get("intro_pause_sec", 0.45)))
	var gap: float = maxf(0.0, float(payload.get("gap_sec", 0.12)))
	var hold_after_final: float = maxf(0.0, float(payload.get("final_hold_sec", 2.4)))
	var fade_out: float = maxf(0.05, float(payload.get("final_fade_out_sec", GlobalBalance.HUD_FADE_OUT_SEC)))
	text = ""
	var acc := ""
	for c in intro:
		if run_id != _seq_token:
			return
		acc += c
		text = acc
		await get_tree().create_timer(csec).timeout
	if run_id != _seq_token:
		return
	await get_tree().create_timer(intro_pause).timeout
	if run_id != _seq_token:
		return
	text = ""
	await get_tree().create_timer(gap).timeout
	if run_id != _seq_token:
		return
	text = final_t
	modulate = Color(1, 1, 1, 1)
	if hold_after_final > 0.0:
		await get_tree().create_timer(hold_after_final).timeout
	if run_id != _seq_token:
		return
	_kill_fade_tween()
	modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_out)
	_fade_tween.tween_callback(func() -> void:
		if run_id != _seq_token:
			return
		visible = false
		text = ""
		_active_hint_id = ""
		modulate = Color(1, 1, 1, 1)
		_fade_tween = null
	)


func _process(_delta: float) -> void:
	if not visible:
		return
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var feet := player.global_position
	var screen := (get_viewport().get_canvas_transform() * feet) as Vector2
	var anchor := screen + _OFFSET_ABOVE_FEET
	global_position = anchor - size * 0.5
