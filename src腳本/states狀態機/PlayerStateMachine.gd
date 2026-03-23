# res://src腳本/states狀態機/PlayerStateMachine.gd
extends Node

var current_state: Node
@onready var player: PlayerController = get_parent()

func _ready() -> void:
	await get_tree().process_frame
	for state in get_children():
		if state is Node:
			state.player = player
			state.set_process(false)
	change_state($Move)

func _process(_delta: float) -> void:
	if not player: return
	
	# --- 1. 演繹保護 (Happy/Sad/Attack 中絕對鎖定) ---
	var current_anim = player.anim_sprite.animation
	
	# 如果正在播結算動畫，鎖死
	if current_anim in ["happy", "sad"] and player.anim_sprite.is_playing():
		return 
		
	# 🔴 核心修復：如果正在攻擊中，鎖死狀態機，不准進行任何切換判定
	if current_state == $Attack:
		if current_state.get("is_swinging") == true:
			return # 這一招沒揮完，誰都不准動！

	# --- 2. 封印模式邏輯 ---
	var manager = get_tree().get_first_node_in_group("seal_manager")
	var is_pressing = manager.is_pressing_target if manager else false

	if player.is_seal_mode:
		# 🟢 只有在「沒在按壓怪物」時，才檢查是否要攻擊
		if not is_pressing and (player.current_enemy or player.current_target):
			if _is_target_valid_for_attack():
				change_state($Attack)
				return
		
		# 否則維持在 Move (負責走路或封印姿勢)
		if current_state != $Move: change_state($Move)
		return 

	# --- 3. 正常模式邏輯 ---
	if (player.current_enemy or player.current_target) and _is_target_valid_for_attack():
		change_state($Attack)
	else:
		change_state($Move)

func _is_target_valid_for_attack() -> bool:
	if player.current_enemy and is_instance_valid(player.current_enemy.get_parent()):
		var m = player.current_enemy.get_parent()
		if m.get("is_dead") == true: return false
		return true
	if player.current_target: return true
	return false

func change_state(new_state: Node) -> void:
	if not new_state or current_state == new_state: return
	
	# 🔴 攻擊狀態鎖定 (二次保險)
	if current_state == $Attack:
		if current_state.get("is_swinging") == true: return

	if current_state:
		if current_state.has_method("exit"): current_state.exit()
		current_state.set_process(false)
	
	current_state = new_state
	current_state.set_process(true)
	if current_state.has_method("enter"): current_state.enter()
