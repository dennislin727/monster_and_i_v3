# res://scenes場景/ui介面/SealHudLocker.gd
extends Node

## 大劍結束後先等一段再極慢淡入（長壓怪物時暫不需要這些鈕）
const HUD_RESTORE_DELAY_SEC := 1.1
const HUD_FADE_IN_DURATION_SEC := 2.6

var _hud_seq: int = 0
var _fade_tween: Tween

func _ready() -> void:
	SignalBus.seal_ui_requested.connect(_on_seal_ui_requested)
	SignalBus.seal_sword_fall_finished.connect(_on_seal_sword_fall_finished)

func _hud_items(layer: CanvasLayer) -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	var hb := layer.get_node_or_null("PlayerHealthBar") as CanvasItem
	var xp_row := layer.get_node_or_null("PlayerXpRow") as CanvasItem
	var right_action := layer.get_node_or_null("RightActionHud") as CanvasItem
	var dash := layer.get_node_or_null("DashButton") as CanvasItem
	var pet_btn := layer.get_node_or_null("PetUI/OpenButton") as CanvasItem
	var inv_btn := layer.get_node_or_null("InventoryUI/OpenButton") as CanvasItem
	var diary_btn := layer.get_node_or_null("DiaryUI/OpenButton") as CanvasItem
	var save_btn := layer.get_node_or_null("SaveGameButton") as CanvasItem
	var party_hud := layer.get_node_or_null("PetPartySlotHud") as CanvasItem
	if hb:
		out.append(hb)
	if xp_row:
		out.append(xp_row)
	if right_action:
		out.append(right_action)
	elif dash:
		out.append(dash)
	if pet_btn:
		out.append(pet_btn)
	if inv_btn:
		out.append(inv_btn)
	if diary_btn:
		out.append(diary_btn)
	if save_btn:
		out.append(save_btn)
	if party_hud:
		out.append(party_hud)
	return out

func _kill_fade() -> void:
	if _fade_tween and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null

func _set_gameplay_hud_hidden() -> void:
	var layer := get_parent() as CanvasLayer
	if layer == null:
		return
	for ci in _hud_items(layer):
		ci.visible = false
		var m := ci.modulate
		m.a = 1.0
		ci.modulate = m

func _set_gameplay_hud_visible_instant() -> void:
	var layer := get_parent() as CanvasLayer
	if layer == null:
		return
	for ci in _hud_items(layer):
		ci.visible = true
		ci.modulate = Color(1, 1, 1, 1)

func _on_seal_ui_requested(is_seal_open: bool) -> void:
	_hud_seq += 1
	_kill_fade()
	if is_seal_open:
		_set_gameplay_hud_hidden()
	else:
		# 取消／失敗：立刻完整顯示
		_set_gameplay_hud_visible_instant()

func _on_seal_sword_fall_finished() -> void:
	var token := _hud_seq
	var layer := get_parent() as CanvasLayer
	if layer == null:
		return
	var items := _hud_items(layer)
	if items.is_empty():
		return
	# 延遲期間維持 hidden，避免透明鈕仍吃掉長壓怪物的觸控
	await get_tree().create_timer(HUD_RESTORE_DELAY_SEC).timeout
	if token != _hud_seq:
		return
	for ci in items:
		ci.visible = true
		var m := ci.modulate
		m.a = 0.0
		ci.modulate = m
	_kill_fade()
	_fade_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for ci in items:
		_fade_tween.tween_property(ci, "modulate:a", 1.0, HUD_FADE_IN_DURATION_SEC)
