# res://src腳本/components積木/InteractableComponent.gd
class_name InteractableComponent
extends Area2D

@export var item_data: ItemResource 
@export var interact_name: String = "採集物"

@export_group("採集設定")
@export var min_damage: int = 35
@export var max_damage: int = 100

var is_collected: bool = false # 🔴 安全鎖

func _ready() -> void:
	# 🔴 核心修正：主動去抓父節點的血量組件
	var health = get_parent().get_node_or_null("HealthComponent")
	if health:
		if not health.died.is_connected(_on_parent_died):
			health.died.connect(_on_parent_died)

func start_harvest() -> void:
	if is_collected: return # 已被採集就不再執行
	var health = get_parent().get_node_or_null("HealthComponent")
	if health:
		# --- 修改部分：引入隨機性 ---
		var random_dmg = randi_range(min_damage, max_damage)
		health.take_damage(random_dmg) 
		
		# 觸發飄字特效 (選配：讓玩家知道採集力道)
		SignalBus.damage_spawned.emit(global_position, random_dmg, false)
		
		print("[採集] %s 受到 %d 點挖掘，剩餘血量: %d" % [interact_name, random_dmg, health.current_hp])

func _on_parent_died() -> void:
	if is_collected: return
	is_collected = true # 🔴 鎖定，防止噴發兩次
	
	finish_harvest()
	
	# 給動畫留一點點物理緩衝時間，延遲一幀刪除父節點
	get_parent().set_deferred("process_mode", PROCESS_MODE_DISABLED) # 先禁用防重複
	get_parent().queue_free()

func finish_harvest() -> void:
	if item_data and item_data.icon:
		SignalBus.request_effect_collect.emit(global_position, item_data.icon)
		SignalBus.item_collected.emit(item_data)
		print("[採集] 噴出單個圖示: ", item_data.display_name)
