extends Node

var captured_pets: Array[PetResource] = []
var active_pet: PetResource = null

func _ready() -> void:
	if SignalBus and not SignalBus.seal_attempt_finished.is_connected(_on_seal_attempt_finished):
		SignalBus.seal_attempt_finished.connect(_on_seal_attempt_finished)

func _on_seal_attempt_finished(success: bool, data: Resource) -> void:
	if not success:
		return

	var monster_data := data as MonsterResource
	if monster_data == null:
		return

	var pet_data: PetResource = monster_data.pet_data
	if pet_data == null:
		pet_data = _make_pet_from_monster(monster_data)

	captured_pets.append(pet_data)
	if active_pet == null:
		active_pet = pet_data

	if SignalBus:
		SignalBus.pet_captured.emit(pet_data)

func _make_pet_from_monster(monster_data: MonsterResource) -> PetResource:
	var pet := PetResource.new()
	pet.pet_id = _make_pet_id(monster_data)
	pet.pet_name = monster_data.monster_name
	pet.icon = null
	pet.sprite_frames = monster_data.sprite_frames
	return pet

func _make_pet_id(monster_data: MonsterResource) -> String:
	if monster_data.resource_path != "":
		return monster_data.resource_path.get_file().get_basename()
	return monster_data.monster_name.to_lower().replace(" ", "_")

