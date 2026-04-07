# res://src腳本/autoload管理員/PetCommandManager.gd
## Phase 12：槽 1 手動戰技 — 薄層單一真相（狀態、解析技能、預覽節點）；不含業務公式以外的決策。
extends Node

enum State { IDLE, AIMING, EXECUTING }

var state: State = State.IDLE
var cached_manual_skill: SkillResource = null
var cached_slot0_instance_id: String = ""

var _preview_node: Node2D = null
var _dialogue_blocked: bool = false


func _ready() -> void:
	if SignalBus:
		if not SignalBus.dialogue_blocking_changed.is_connected(_on_dialogue_blocking_changed):
			SignalBus.dialogue_blocking_changed.connect(_on_dialogue_blocking_changed)
		if not SignalBus.seal_ui_requested.is_connected(_on_seal_ui_cancel_aim):
			SignalBus.seal_ui_requested.connect(_on_seal_ui_cancel_aim)
		if not SignalBus.harvest_mode_changed.is_connected(_on_harvest_cancel_aim):
			SignalBus.harvest_mode_changed.connect(_on_harvest_cancel_aim)
		if not SignalBus.pet_party_changed.is_connected(_on_party_or_deploy_changed):
			SignalBus.pet_party_changed.connect(_on_party_or_deploy_changed)
		if not SignalBus.pet_deployed_changed.is_connected(_on_party_or_deploy_changed):
			SignalBus.pet_deployed_changed.connect(_on_party_or_deploy_changed)
		if not SignalBus.pet_party_field_companion_spawned.is_connected(_on_field_companion_spawned):
			SignalBus.pet_party_field_companion_spawned.connect(_on_field_companion_spawned)
	refresh_from_party()


func _on_dialogue_blocking_changed(blocked: bool) -> void:
	_dialogue_blocked = blocked
	if blocked:
		cancel_aiming()


func _on_seal_ui_cancel_aim(is_open: bool) -> void:
	if is_open:
		cancel_aiming()


func _on_harvest_cancel_aim(active: bool) -> void:
	if active:
		cancel_aiming()


func _on_party_or_deploy_changed(_arg: Variant = null) -> void:
	refresh_from_party()


func _on_field_companion_spawned(_slot: int) -> void:
	refresh_from_party()


static func resolve_manual_skill_for_pet(pet: PetResource) -> SkillResource:
	if pet == null:
		return null
	for e in pet.skills:
		if e == null:
			continue
		var s: SkillResource = e.skill
		if s == null or s.is_homestead_till_skill:
			continue
		if s.type == SkillResource.SkillType.HEAL:
			return s
	for e in pet.skills:
		if e == null:
			continue
		var s2: SkillResource = e.skill
		if s2 == null or s2.is_homestead_till_skill:
			continue
		if s2.type == SkillResource.SkillType.AOE_ATTACK:
			return s2
	return null


func refresh_from_party() -> void:
	cached_manual_skill = null
	cached_slot0_instance_id = ""
	if PetManager == null:
		return
	var p: PetResource = PetManager.party_slots[0] as PetResource
	if p == null:
		return
	cached_slot0_instance_id = p.instance_id.strip_edges()
	cached_manual_skill = resolve_manual_skill_for_pet(p)


func party_slot0_has_field_companion() -> bool:
	return find_slot0_companion() != null


func find_slot0_companion() -> PetCompanion:
	if PetManager == null:
		return null
	var p: PetResource = PetManager.party_slots[0] as PetResource
	if p == null:
		return null
	var want_id := p.instance_id.strip_edges()
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("deployed_pet"):
		if n is PetCompanion:
			var pc := n as PetCompanion
			if pc.party_slot_index != 0:
				continue
			if pc.get_pet_instance_id().strip_edges() == want_id:
				return pc
	return null


func is_command_input_blocked() -> bool:
	if _dialogue_blocked:
		return true
	if HomeManager != null and HomeManager.harvest_active:
		return true
	var tree := get_tree()
	if tree == null:
		return true
	var sm := tree.get_first_node_in_group("seal_manager")
	if sm != null and sm.has_method("is_seal_ritual_active") and bool(sm.call("is_seal_ritual_active")):
		return true
	return false


func screen_to_world_2d(screen_pos: Vector2) -> Vector2:
	var vpt := get_viewport()
	if vpt == null:
		return Vector2.ZERO
	return vpt.get_canvas_transform().affine_inverse() * screen_pos


func can_start_command() -> bool:
	if is_command_input_blocked():
		return false
	if cached_manual_skill == null or cached_slot0_instance_id.is_empty():
		return false
	var pc := find_slot0_companion()
	if pc == null:
		return false
	return true


func start_aiming(initial_world: Vector2) -> bool:
	if state != State.IDLE:
		return false
	if not can_start_command():
		return false
	var sk := cached_manual_skill
	if sk == null or not sk.aoe_use_ground_target:
		return false
	var pc := find_slot0_companion()
	if pc == null:
		return false
	state = State.AIMING
	_free_preview()
	var em := get_tree().get_first_node_in_group("effect_manager")
	if em != null and em.has_method("spawn_ground_slam_preview"):
		_preview_node = em.call("spawn_ground_slam_preview", sk, pc, initial_world) as Node2D
	_lock_joystick_for_aiming(true)
	return true


func update_aim_world(world_pos: Vector2) -> void:
	if state != State.AIMING:
		return
	if _preview_node != null and is_instance_valid(_preview_node) and _preview_node.has_method("set_preview_impact_world"):
		_preview_node.call("set_preview_impact_world", world_pos)


func cancel_aiming() -> void:
	if state != State.AIMING:
		return
	state = State.IDLE
	_free_preview()
	_lock_joystick_for_aiming(false)
	var tree := get_tree()
	if tree:
		tree.call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "pet_command_hud", "on_pet_command_aim_stopped")


func confirm_aiming(world_pos: Vector2) -> void:
	if state != State.AIMING:
		return
	state = State.EXECUTING
	_free_preview()
	_lock_joystick_for_aiming(false)
	var pc := find_slot0_companion()
	var sk := cached_manual_skill
	var ok := false
	if pc != null and sk != null:
		ok = pc.execute_manual_command(sk, world_pos)
	if ok:
		_notify_player_pet_command_seal_pose(world_pos)
	state = State.IDLE
	var tree2 := get_tree()
	if tree2:
		tree2.call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "pet_command_hud", "on_pet_command_aim_stopped")


func request_instant_command() -> void:
	if state != State.IDLE:
		return
	if not can_start_command():
		return
	var sk := cached_manual_skill
	if sk == null:
		return
	if sk.aoe_use_ground_target and sk.type == SkillResource.SkillType.AOE_ATTACK:
		return
	var pc := find_slot0_companion()
	if pc == null:
		return
	state = State.EXECUTING
	pc.execute_manual_command(sk, Vector2.ZERO)
	state = State.IDLE


func _free_preview() -> void:
	if _preview_node != null and is_instance_valid(_preview_node):
		_preview_node.queue_free()
	_preview_node = null


func _notify_player_pet_command_seal_pose(target_world: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var p := tree.get_first_node_in_group("player")
	if p is PlayerController:
		(p as PlayerController).play_pet_command_seal_pose(target_world)


func _lock_joystick_for_aiming(lock: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var joy := tree.get_root().find_child("Virtual Joystick", true, false)
	if joy is VirtualJoystick:
		var vj := joy as VirtualJoystick
		if lock:
			vj._reset()
			vj.set_process_input(false)
			vj.hide()
		else:
			vj.restore_after_blocking_overlay()


## 手動戰技鈕徑向 CD：總秒數（含 `PetSkillEntry.skill_level` 縮放）。
func get_manual_command_cooldown_total_display() -> float:
	if PetManager == null:
		return 0.0
	var pet: PetResource = PetManager.party_slots[0] as PetResource
	var sk: SkillResource = cached_manual_skill
	if pet == null or sk == null:
		return 0.0
	match sk.type:
		SkillResource.SkillType.HEAL:
			var base: float = pet.heal_cooldown if pet.heal_cooldown > 0.0 else GlobalBalance.PET_HEAL_COOLDOWN
			var lv := 1
			for e in pet.skills:
				if e != null and e.skill == sk:
					lv = maxi(1, e.skill_level)
					break
			return GlobalBalance.resolve_pet_skill_cooldown_scaled(base, lv)
		_:
			var lv2 := 1
			for e2 in pet.skills:
				if e2 != null and e2.skill == sk:
					lv2 = maxi(1, e2.skill_level)
					break
			return GlobalBalance.resolve_pet_skill_cooldown_scaled(sk.cooldown, lv2)


func get_manual_command_cooldown_remaining_display() -> float:
	var pc := find_slot0_companion()
	var sk := cached_manual_skill
	if pc == null or sk == null:
		return 0.0
	return pc.get_manual_skill_cooldown_remaining(sk)
