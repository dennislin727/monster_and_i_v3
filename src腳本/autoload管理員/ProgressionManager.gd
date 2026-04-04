# res://src腳本/autoload管理員/ProgressionManager.gd
extends Node

signal player_progress_changed

var player_level: int = 1
## 累積於當前等級、指向下一級的經驗（非生涯總量）。
var player_xp: int = 0
## 點位元：第 i 隻湖畔環境寶寶（`AmbientBabyBirdMonster.lake_ambient_save_slot == i`）已成功封印；與 `GlobalBalance.LAKE_AMBIENT_BABY_BIRD_TOTAL` 對齊。
var lake_ambient_baby_bird_cleared_mask: int = 0


func _ready() -> void:
	pass


func get_player_xp_bar_ratio() -> float:
	if GlobalBalance == null:
		return 0.0
	var need := GlobalBalance.xp_needed_for_player_next_level(player_level)
	if need <= 0:
		return 1.0
	return clampf(float(player_xp) / float( need), 0.0, 1.0)


func add_player_xp(amount: int) -> void:
	if amount <= 0 or GlobalBalance == null:
		return
	player_xp += amount
	while true:
		var need := GlobalBalance.xp_needed_for_player_next_level(player_level)
		if player_xp < need:
			break
		player_xp -= need
		player_level += 1
	player_progress_changed.emit()


func add_pet_xp(pet_data: PetResource, amount: int) -> void:
	if pet_data == null or amount <= 0 or GlobalBalance == null:
		return
	if pet_data.level >= GlobalBalance.PET_MAX_LEVEL:
		return
	pet_data.experience += amount
	while pet_data.level < GlobalBalance.PET_MAX_LEVEL:
		var need := GlobalBalance.xp_needed_for_pet_next_level(pet_data.level)
		if pet_data.experience < need:
			break
		pet_data.experience -= need
		pet_data.level += 1
	if SignalBus:
		SignalBus.pet_party_changed.emit()
		SignalBus.pet_roster_changed.emit()


func distribute_kill_xp(pool: int) -> void:
	if pool <= 0:
		return
	var parts: Array = ["player"]
	for i in PetManager.PARTY_SLOT_COUNT:
		if i >= PetManager.party_slots.size():
			break
		var p: PetResource = PetManager.party_slots[i] as PetResource
		if p == null:
			continue
		if GlobalBalance and p.level >= GlobalBalance.PET_MAX_LEVEL:
			continue
		parts.append(p)
	var n := parts.size()
	if n <= 0:
		return
	# 浮點除再取整，避免 int/int 觸發 INTEGER_DIVISION 警告（結果與整數除法相同）。
	var each := int(pool / float(n))
	if each <= 0:
		return
	for entry in parts:
		if entry is String and entry == "player":
			add_player_xp(each)
		elif entry is PetResource:
			add_pet_xp(entry as PetResource, each)


func _lake_ambient_baby_bird_cap() -> int:
	if GlobalBalance != null:
		return GlobalBalance.LAKE_AMBIENT_BABY_BIRD_TOTAL
	return 2


func register_lake_ambient_baby_bird_slot_cleared(slot: int) -> void:
	var cap := _lake_ambient_baby_bird_cap()
	if slot < 0 or slot >= cap:
		return
	lake_ambient_baby_bird_cleared_mask |= (1 << slot)


func is_lake_ambient_baby_bird_slot_cleared(slot: int) -> bool:
	var cap := _lake_ambient_baby_bird_cap()
	if slot < 0 or slot >= cap:
		return true
	return (lake_ambient_baby_bird_cleared_mask & (1 << slot)) != 0


func get_save_snapshot() -> Dictionary:
	var cap := _lake_ambient_baby_bird_cap()
	var all_cleared_mask := (1 << cap) - 1
	return {
		"player_level": player_level,
		"player_xp": player_xp,
		"lake_ambient_baby_bird_cleared_mask": lake_ambient_baby_bird_cleared_mask,
		# 舊讀檔器：僅當「全部槽位都已封印」時視為已捕獲。
		"ambient_baby_bird_captured": (lake_ambient_baby_bird_cleared_mask & all_cleared_mask) == all_cleared_mask,
	}


func apply_save_snapshot(data: Dictionary) -> void:
	player_level = maxi(1, int(data.get("player_level", 1)))
	player_xp = maxi(0, int(data.get("player_xp", 0)))
	var cap := _lake_ambient_baby_bird_cap()
	var all_cleared_mask := (1 << cap) - 1
	if data.has("lake_ambient_baby_bird_cleared_mask"):
		lake_ambient_baby_bird_cleared_mask = int(data.get("lake_ambient_baby_bird_cleared_mask", 0)) & all_cleared_mask
	elif bool(data.get("ambient_baby_bird_captured", false)):
		# 舊存檔僅 1 隻環境寶寶語意：視為兩槽皆已清空（不再生成）。
		lake_ambient_baby_bird_cleared_mask = all_cleared_mask
	else:
		lake_ambient_baby_bird_cleared_mask = 0
	player_progress_changed.emit()
