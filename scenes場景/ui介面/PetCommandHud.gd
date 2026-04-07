# res://scenes場景/ui介面/PetCommandHud.gd
## Phase 12：右側戰技鈕 + 與 Dash 同組；瞄準態時 `_input` 更新預覽（對齊 SealManager 之螢幕→世界換算）。
## 戰技鈕外觀與翻滾鈕一致（圓角矩形）；冷卻遮罩為圓角矩形著色器（由下往上消退），分母與寵物實際寫入的 CD 快照對齊。
extends Control

const _AIM_IDX_MOUSE := -1
const _AIM_IDX_INACTIVE := -2
## 與 `PetPartySlotHud` 槽位圓角／邊框一致（著色器 px）
const _PET_SLOT_CORNER_PX := 5.0

@onready var _skill_btn: Button = $PetCommandSkillButton
@onready var _skill_name_lbl: Label = $PetCommandSkillButton/SkillNameLabel
@onready var _cd_overlay: ColorRect = $PetCommandSkillButton/CdOverlay
@onready var _cd_sec_lbl: Label = $PetCommandSkillButton/CdSecondsLabel

var _aim_capture_idx: int = _AIM_IDX_INACTIVE
var _cd_mat: ShaderMaterial


func _ready() -> void:
	add_to_group("pet_command_hud")
	add_to_group("right_action_hud")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)
	set_process(false)
	if _skill_btn:
		_skill_btn.add_to_group("joystick_touch_exclusion")
		_skill_btn.gui_input.connect(_on_skill_gui_input)
		_skill_btn.text = ""
	# 子節點全鋪鈕面時預設會 STOP 攔截觸控，父 Button 的 gui_input 收不到（寵物派出後戰技鈕才顯示時特別明顯）。
	if _skill_name_lbl:
		_skill_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _cd_sec_lbl:
		_cd_sec_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _cd_overlay:
		_cd_mat = _cd_overlay.material as ShaderMaterial
		if _cd_mat == null:
			var sh := load("res://scenes場景/ui介面/PetSkillCooldownOverlay.gdshader") as Shader
			if sh:
				_cd_mat = ShaderMaterial.new()
				_cd_mat.shader = sh
				_cd_overlay.material = _cd_mat
		if _cd_mat:
			_cd_mat.set_shader_parameter("corner_radius", _PET_SLOT_CORNER_PX)
	if SignalBus:
		if not SignalBus.pet_party_changed.is_connected(_refresh_skill_button):
			SignalBus.pet_party_changed.connect(_refresh_skill_button)
		if not SignalBus.pet_deployed_changed.is_connected(_refresh_skill_button):
			SignalBus.pet_deployed_changed.connect(_refresh_skill_button)
		if not SignalBus.pet_party_field_companion_spawned.is_connected(_refresh_skill_button):
			SignalBus.pet_party_field_companion_spawned.connect(_refresh_skill_button)
	call_deferred("_refresh_skill_button")


func _process(_delta: float) -> void:
	_update_command_cooldown_visual()


func on_pet_command_aim_stopped() -> void:
	set_process_input(false)
	_aim_capture_idx = _AIM_IDX_INACTIVE


func _refresh_skill_button(_a: Variant = null) -> void:
	if PetCommandManager:
		PetCommandManager.refresh_from_party()
	if _skill_btn == null:
		return
	var show_skill := false
	if PetCommandManager:
		show_skill = PetCommandManager.cached_manual_skill != null and PetCommandManager.party_slot0_has_field_companion()
	_skill_btn.visible = show_skill
	set_process(show_skill)
	var nm := "戰技"
	if show_skill and PetCommandManager and PetCommandManager.cached_manual_skill:
		nm = PetCommandManager.cached_manual_skill.skill_name
	if _skill_name_lbl:
		_skill_name_lbl.text = nm
	_update_command_cooldown_visual()


func _update_command_cooldown_visual() -> void:
	if not _skill_btn or not _skill_btn.visible or PetCommandManager == null:
		return
	var rem: float = PetCommandManager.get_manual_command_cooldown_remaining_display()
	var sk: SkillResource = PetCommandManager.cached_manual_skill
	var pc: PetCompanion = PetCommandManager.find_slot0_companion()
	var denom: float = 0.0
	if pc != null and sk != null and rem > 0.0001:
		denom = pc.get_manual_skill_cooldown_bar_denominator(sk)
	if denom <= 1e-6:
		denom = maxf(maxf(PetCommandManager.get_manual_command_cooldown_total_display(), rem), 1e-6)
	# 與剩餘秒數線性對齊；勿再用「至少 1/denom」的 min_band，否則最後約 1 秒遮罩高度會卡住，體感像多等一會。
	var ratio_vis: float = clampf(rem / denom, 0.0, 1.0) if denom > 1e-6 else 0.0
	if _cd_mat:
		_cd_mat.set_shader_parameter("cooldown_ratio", ratio_vis)
		if _cd_overlay:
			_cd_mat.set_shader_parameter("rect_size", _cd_overlay.size)
	if _cd_overlay:
		_cd_overlay.visible = rem > 0.0005
	if _cd_sec_lbl:
		# 最後極短時間不顯示數字，避免「已幾乎轉好卻還看到 1」的落差（遮罩仍會線性收完）
		if rem > 0.12:
			_cd_sec_lbl.text = str(int(ceil(rem - 1e-4)))
			_cd_sec_lbl.visible = true
		else:
			_cd_sec_lbl.text = ""
			_cd_sec_lbl.visible = false
	if _skill_name_lbl:
		_skill_name_lbl.modulate = Color(1, 1, 1, 1) if rem <= 0.05 else Color(0.78, 0.76, 0.74, 1)
	_skill_btn.disabled = rem > 0.0001


func _on_skill_gui_input(event: InputEvent) -> void:
	if PetCommandManager == null:
		return
	if PetCommandManager.is_command_input_blocked():
		return
	if PetCommandManager.state != PetCommandManager.State.IDLE:
		return
	if _skill_btn and _skill_btn.disabled:
		return
	var sk: SkillResource = PetCommandManager.cached_manual_skill
	if sk == null:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			# Godot 4：`InputEventScreenTouch` 僅有 `position`（視窗座標），無 `global_position`。
			_start_skill_from_screen(st.position, st.index)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_start_skill_from_screen(mb.global_position, _AIM_IDX_MOUSE)


func _start_skill_from_screen(screen_pos: Vector2, touch_index: int) -> void:
	var sk: SkillResource = PetCommandManager.cached_manual_skill
	if sk == null:
		return
	if sk.type == SkillResource.SkillType.AOE_ATTACK and sk.aoe_use_ground_target:
		var w := PetCommandManager.screen_to_world_2d(screen_pos)
		if PetCommandManager.start_aiming(w):
			_aim_capture_idx = touch_index
			set_process_input(true)
	elif sk.type == SkillResource.SkillType.HEAL or (sk.type == SkillResource.SkillType.AOE_ATTACK and not sk.aoe_use_ground_target):
		PetCommandManager.request_instant_command()


func _input(event: InputEvent) -> void:
	if PetCommandManager == null or PetCommandManager.state != PetCommandManager.State.AIMING:
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _aim_capture_idx:
			var w := PetCommandManager.screen_to_world_2d(sd.position)
			PetCommandManager.update_aim_world(w)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed and st.index == _aim_capture_idx:
			var w2 := PetCommandManager.screen_to_world_2d(st.position)
			PetCommandManager.confirm_aiming(w2)
	elif event is InputEventMouseMotion:
		if _aim_capture_idx == _AIM_IDX_MOUSE and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var wm := PetCommandManager.screen_to_world_2d(event.global_position)
			PetCommandManager.update_aim_world(wm)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _aim_capture_idx == _AIM_IDX_MOUSE:
			var wf := PetCommandManager.screen_to_world_2d(mb.global_position)
			PetCommandManager.confirm_aiming(wf)
