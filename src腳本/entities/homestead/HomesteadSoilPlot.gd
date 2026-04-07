# res://src腳本/entities/homestead/HomesteadSoilPlot.gd
extends Node2D
## Phase 10 切片：未翻土 → 幼苗(1.5s) → 開花(1.5s) → 成熟(1.5s)。
## 離線成長使用本機時間；成熟計數由 HomeManager 單次掃描上限控管。

enum _State { UNTILLED, STAGE_1, STAGE_2, MATURE }

@export var item_template: ItemResource
## 每階段秒數（預設 1.5 秒）
@export var stage_duration_sec: float = 1.5

@onready var _crop: HomesteadCrop = $Crop
@onready var _soil: Sprite2D = $SoilVisual


var _state: _State = _State.UNTILLED
var _next_transition_unix: int = 0


func _ready() -> void:
	add_to_group("homestead_soil_plot")
	if stage_duration_sec <= 0.0:
		stage_duration_sec = 1.5
	if _crop:
		_crop.free_after_pickup = false
		_crop.is_mature = false
		if item_template != null:
			_crop.item_template = item_template
		_crop.hide()
		if not _crop.harvest_recycled.is_connected(_on_crop_recycled):
			_crop.harvest_recycled.connect(_on_crop_recycled)
	_apply_untilled_visual()


func can_pet_till() -> bool:
	return _state == _State.UNTILLED


## 由出戰寵物呼叫；成功開始成長計時。
func till_from_pet(_pet: Node2D) -> bool:
	if _state != _State.UNTILLED or _crop == null:
		return false
	_state = _State.STAGE_1
	_schedule_next_stage()
	_apply_stage1_visual()
	return true


func _schedule_next_stage() -> void:
	_next_transition_unix = int(Time.get_unix_time_from_system() + ceili(stage_duration_sec))
	var t := get_tree().create_timer(stage_duration_sec)
	t.timeout.connect(_on_growth_tick, CONNECT_ONE_SHOT)


func _on_growth_tick() -> void:
	_advance_growth(1, 1, true)


func _on_crop_recycled() -> void:
	_state = _State.UNTILLED
	_next_transition_unix = 0
	_apply_untilled_visual()
	if HomeManager:
		HomeManager.request_homestead_hints_refresh()


func _apply_untilled_visual() -> void:
	if _soil == null:
		return
	_soil.show()
	_soil.modulate = Color(0.55, 0.72, 0.38, 1.0)


func _apply_stage1_visual() -> void:
	if _soil == null:
		return
	_soil.show()
	_soil.modulate = Color(0.5, 0.35, 0.22, 1.0)
	if _crop:
		_crop.hide()
		_crop.is_mature = false


func _apply_stage2_visual() -> void:
	if _soil == null:
		return
	_soil.show()
	_soil.modulate = Color(0.44, 0.31, 0.2, 1.0)
	if _crop:
		_crop.show()
		_apply_crop_display_modulate(Color(1.0, 1.0, 1.0, 0.55))
		_crop.is_mature = false


func _apply_mature_visual() -> void:
	if _soil == null:
		return
	_soil.modulate = Color(0.45, 0.4, 0.3, 0.35)
	if _crop:
		_apply_crop_display_modulate(Color(1, 1, 1, 1))
		_crop.show()
		_crop.is_mature = true


func _apply_crop_display_modulate(base: Color) -> void:
	if _crop == null:
		return
	if HomeManager:
		_crop.modulate = HomeManager.apply_crop_harvest_highlight_modulate(base)
	else:
		_crop.modulate = base


func reapply_crop_modulate_for_harvest_mode() -> void:
	if _crop == null:
		return
	match _state:
		_State.STAGE_2:
			_apply_crop_display_modulate(Color(1.0, 1.0, 1.0, 0.55))
		_State.MATURE:
			_apply_crop_display_modulate(Color(1, 1, 1, 1))
		_:
			pass


func _advance_growth(steps: int, mature_budget: int, schedule_timer: bool) -> int:
	if not is_inside_tree() or _crop == null or not is_instance_valid(_crop):
		return 0
	var matured_count := 0
	var remain_steps := maxi(0, steps)
	var remain_budget := maxi(0, mature_budget)
	while remain_steps > 0:
		remain_steps -= 1
		match _state:
			_State.UNTILLED:
				break
			_State.STAGE_1:
				_state = _State.STAGE_2
				_apply_stage2_visual()
				if schedule_timer:
					_schedule_next_stage()
			_State.STAGE_2:
				if remain_budget <= 0:
					if schedule_timer:
						_schedule_next_stage()
					break
				_state = _State.MATURE
				_next_transition_unix = 0
				if item_template != null:
					_crop.item_template = item_template
				_apply_mature_visual()
				remain_budget -= 1
				matured_count += 1
				if HomeManager:
					HomeManager.request_homestead_hints_refresh()
			_State.MATURE:
				break
	return matured_count


func apply_offline_growth_seconds(elapsed_sec: int, mature_budget: int) -> int:
	if elapsed_sec <= 0:
		return 0
	if _state == _State.UNTILLED or _state == _State.MATURE:
		return 0
	var phase_sec := maxi(1, int(round(stage_duration_sec)))
	var steps := int(elapsed_sec / float(phase_sec))
	if steps <= 0:
		return 0
	var matured := _advance_growth(steps, mature_budget, false)
	if (_state == _State.STAGE_1 or _state == _State.STAGE_2) and _next_transition_unix == 0:
		_schedule_next_stage()
	return matured


func get_home_save_snapshot() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var remain := maxi(0, _next_transition_unix - now)
	return {
		"state": int(_state),
		"remain_sec": remain,
	}


func apply_home_save_snapshot(data: Dictionary) -> void:
	_state = _State.UNTILLED
	_next_transition_unix = 0
	var s := int(data.get("state", int(_State.UNTILLED)))
	match s:
		int(_State.STAGE_1):
			_state = _State.STAGE_1
			_apply_stage1_visual()
		int(_State.STAGE_2):
			_state = _State.STAGE_2
			_apply_stage2_visual()
		int(_State.MATURE):
			_state = _State.MATURE
			_apply_mature_visual()
		_:
			_state = _State.UNTILLED
			_apply_untilled_visual()
	var remain := maxi(0, int(data.get("remain_sec", 0)))
	if _state == _State.STAGE_1 or _state == _State.STAGE_2:
		_next_transition_unix = int(Time.get_unix_time_from_system()) + remain
		var wait_sec := maxf(0.1, float(remain))
		var t := get_tree().create_timer(wait_sec)
		t.timeout.connect(_on_growth_tick, CONNECT_ONE_SHOT)
