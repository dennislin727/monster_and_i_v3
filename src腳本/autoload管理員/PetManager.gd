extends Node

var captured_pets: Array[PetResource] = []
var active_pet: PetResource = null
var is_deployed: bool = false
var deployed_pet: PetResource = null

func _ready() -> void:
	if SignalBus and not SignalBus.seal_attempt_finished.is_connected(_on_seal_attempt_finished):
		SignalBus.seal_attempt_finished.connect(_on_seal_attempt_finished)
	if SignalBus and not SignalBus.pet_active_requested.is_connected(_on_pet_active_requested):
		SignalBus.pet_active_requested.connect(_on_pet_active_requested)
	if SignalBus and not SignalBus.pet_deploy_requested.is_connected(_on_pet_deploy_requested):
		SignalBus.pet_deploy_requested.connect(_on_pet_deploy_requested)
	if SignalBus and not SignalBus.pet_recall_requested.is_connected(_on_pet_recall_requested):
		SignalBus.pet_recall_requested.connect(_on_pet_recall_requested)
	if SignalBus and not SignalBus.pet_release_requested.is_connected(_on_pet_release_requested):
		SignalBus.pet_release_requested.connect(_on_pet_release_requested)

func _on_seal_attempt_finished(success: bool, data: Resource) -> void:
	if not success:
		return

	var monster_data := data as MonsterResource
	if monster_data == null:
		return

	var pet_template: PetResource = monster_data.pet_data
	var pet_data: PetResource
	if pet_template == null:
		pet_data = _make_pet_from_monster(monster_data)
	else:
		# 封印入庫時一定要做「個體化」：同一個 .tres 可能被捕捉多次，不能共用同一個 Resource 參考
		pet_data = pet_template.duplicate(true) as PetResource
		_ensure_pet_inherits_monster_visual(pet_data, monster_data)
		if pet_data.nickname.strip_edges() == "":
			pet_data.nickname = pet_data.pet_name

	captured_pets.append(pet_data)
	if active_pet == null:
		_set_active_pet(pet_data)

	if SignalBus:
		SignalBus.pet_captured.emit(pet_data)
		SignalBus.pet_roster_changed.emit()

func _make_pet_from_monster(monster_data: MonsterResource) -> PetResource:
	var pet := PetResource.new()
	pet.pet_id = _make_pet_id(monster_data)
	pet.pet_name = monster_data.monster_name
	pet.icon = null
	pet.sprite_frames = monster_data.sprite_frames
	return pet

## .tres 裡的 PetResource 常只填 icon 而沒有 sprite_frames，出戰會變透明
func _ensure_pet_inherits_monster_visual(pet_data: PetResource, monster_data: MonsterResource) -> void:
	if pet_data == null or monster_data == null:
		return
	if pet_data.sprite_frames != null:
		return
	if monster_data.sprite_frames != null:
		pet_data.sprite_frames = monster_data.sprite_frames

func _make_pet_id(monster_data: MonsterResource) -> String:
	if monster_data.resource_path != "":
		return monster_data.resource_path.get_file().get_basename()
	return monster_data.monster_name.to_lower().replace(" ", "_")

func _on_pet_active_requested(pet_data: PetResource) -> void:
	if pet_data == null:
		return
	if not captured_pets.has(pet_data):
		return
	_set_active_pet(pet_data)

func _on_pet_deploy_requested(pet_data: PetResource) -> void:
	if pet_data == null:
		return
	if not _is_on_roster(pet_data):
		push_warning("[PetManager] 出戰遭拒：寵物不在 captured_pets（或 pet_id 對不到）。")
		return
	_set_active_pet(pet_data)
	is_deployed = true
	deployed_pet = pet_data
	if SignalBus:
		SignalBus.pet_deployed_changed.emit(is_deployed)

func _is_on_roster(pet_data: PetResource) -> bool:
	if captured_pets.has(pet_data):
		return true
	if pet_data.pet_id.is_empty():
		return false
	for p in captured_pets:
		if p != null and p.pet_id == pet_data.pet_id:
			return true
	return false

func _on_pet_recall_requested() -> void:
	is_deployed = false
	deployed_pet = null
	if SignalBus:
		SignalBus.pet_deployed_changed.emit(is_deployed)

func _on_pet_release_requested(pet_data: PetResource) -> void:
	if pet_data == null:
		return
	var idx := captured_pets.find(pet_data)
	if idx < 0:
		return
	if deployed_pet == pet_data:
		is_deployed = false
		deployed_pet = null
		if SignalBus:
			SignalBus.pet_deployed_changed.emit(is_deployed)
	captured_pets.remove_at(idx)
	if active_pet == pet_data:
		active_pet = captured_pets[0] if captured_pets.size() > 0 else null
		if SignalBus:
			SignalBus.pet_active_changed.emit(active_pet)
	if SignalBus:
		SignalBus.pet_roster_changed.emit()

func _set_active_pet(pet_data: PetResource) -> void:
	if active_pet == pet_data:
		return
	active_pet = pet_data
	if SignalBus:
		SignalBus.pet_active_changed.emit(active_pet)
