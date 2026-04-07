# res://src腳本/components積木/InteractableComponent.gd
class_name InteractableComponent
extends Area2D

@export var item_data: ItemResource 
@export var interact_name: String = "採集物"

@export_group("採集設定")
@export var min_damage: int = 35
@export var max_damage: int = 100

var is_collected: bool = false 

func _ready() -> void:
	var health = get_parent().get_node_or_null("HealthComponent")
	if health:
		if not health.died.is_connected(_on_parent_died):
			health.died.connect(_on_parent_died)

func start_harvest() -> void:
	if is_collected: return 
	var health = get_parent().get_node_or_null("HealthComponent")
	if health:
		# --- 核心數值聯動：上帝撥盤介入 ---
		var base_dmg = randi_range(min_damage, max_damage)
		
		# 💡 我們在這裡乘上採集倍率 (1.5倍)，讓採集節奏變快！
		var final_dmg = int(base_dmg * GlobalBalance.HARVEST_DAMAGE_MULTIPLIER)
		
		health.take_damage(final_dmg) 
		
		# 顯示加成後的傷害，讓玩家感覺到「我是採集大師」
		SignalBus.damage_spawned.emit(global_position, final_dmg, false)
		
		print("[採集] %s 受到 %d 點挖掘，倍率: %.1f" % [interact_name, final_dmg, GlobalBalance.HARVEST_DAMAGE_MULTIPLIER])

func _on_parent_died() -> void:
	if is_collected: return
	is_collected = true
	finish_harvest()
	var pr := get_parent()
	if pr == null:
		return
	if pr is CanvasItem:
		(pr as CanvasItem).visible = false
	pr.set_deferred("process_mode", PROCESS_MODE_DISABLED)
	pr.queue_free()

func finish_harvest() -> void:
	if item_data and item_data.icon:
		# --- 冠冠特餐：掉落數量倍率 ---
		# 💡 讓怪噴出多個物品，或是讓礦物噴出多顆石頭！
		for i in range(GlobalBalance.GLOBAL_DROP_QUANTITY_BONUS):
			SignalBus.request_effect_collect.emit(global_position, item_data.icon)
			SignalBus.item_collected.emit(item_data)
			
		print("[採集] 噴出物品數量: %d" % GlobalBalance.GLOBAL_DROP_QUANTITY_BONUS)
