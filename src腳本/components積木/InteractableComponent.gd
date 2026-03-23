# res://src腳本/components積木/InteractableComponent.gd
class_name InteractableComponent
extends Area2D

@export var item_data: ItemResource 
@export var interact_name: String = "採集物"

func _ready() -> void:
	# 🔴 核心修正：主動去抓父節點的血量組件
	var health = get_parent().get_node_or_null("HealthComponent")
	if health:
		if not health.died.is_connected(_on_parent_died):
			health.died.connect(_on_parent_died)

# 被主角呼叫
func start_harvest() -> void:
	var health = get_parent().get_node_or_null("HealthComponent")
	if health:
		# 🔴 修正：採集時扣血，我們扣多一點，讓採集快一點
		health.take_damage(20) 
		print("[採集] %s 剩餘血量: %d" % [interact_name, health.current_hp])

func _on_parent_died() -> void:
	finish_harvest()
	get_parent().queue_free()

func finish_harvest() -> void:
	if item_data and item_data.icon:
		SignalBus.request_effect_collect.emit(global_position, item_data.icon)
		SignalBus.item_collected.emit(item_data)
		print("[採集] %s 成功收進背包！" % interact_name)
