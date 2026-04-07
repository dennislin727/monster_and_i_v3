# res://scenes場景/ui介面/HarvestSwipeCapture.gd
extends Control
## 採收模式全螢幕接觸；將螢幕軌跡轉世界座標並交 HomeManager 做同幀上限採收。

var _dragging: bool = false
var _last_world: Vector2 = Vector2.ZERO
var _has_last: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 底欄（背包／寵物／日記）為全螢幕 IGNORE 根下的按鈕；採收層若蓋滿螢幕會先攔截穿透的觸控，導致底欄無法按。
	var bar_h := 63
	if GlobalBalance:
		bar_h = GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX
	offset_bottom = -float(bar_h)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if SignalBus:
		SignalBus.harvest_mode_changed.connect(_on_harvest_mode_changed)


func _on_harvest_mode_changed(active: bool) -> void:
	visible = active
	if not active:
		_dragging = false
		_has_last = false


func _gui_input(event: InputEvent) -> void:
	if HomeManager == null or not HomeManager.harvest_active:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_dragging = true
			_has_last = false
			_process_swipe_point(st.position)
		else:
			_dragging = false
			_has_last = false
	elif event is InputEventScreenDrag and _dragging:
		var sd := event as InputEventScreenDrag
		_process_swipe_point(sd.position)


func _process_swipe_point(screen_pos: Vector2) -> void:
	var w := _screen_to_world(screen_pos)
	if _has_last:
		_harvest_segment(_last_world, w)
	else:
		HomeManager.try_harvest_swipe_world(w)
	_last_world = w
	_has_last = true


func _harvest_segment(a: Vector2, b: Vector2) -> void:
	var dist := a.distance_to(b)
	var steps: int = clampi(int(dist / 10.0) + 1, 1, 40)
	for i in range(steps + 1):
		var t := float(i) / float(max(1, steps))
		var p := a.lerp(b, t)
		HomeManager.try_harvest_swipe_world(p)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var xf := get_viewport().get_canvas_transform()
	return xf.affine_inverse() * screen_pos
