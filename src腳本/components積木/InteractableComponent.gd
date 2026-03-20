# res://src腳本/components積木/InteractableComponent.gd
class_name InteractableComponent
extends Area2D

@export var item_data: ItemResource 
@export var interact_name: String = "採集物"

# 被主角呼叫：執行傷害
func start_harvest() -> void:
	var health = get_parent().get_node_or_null("HealthComponent")
	if health:
		health.take_damage(1)

# 🔴 核心修復：當血量為 0 時由 Rock.gd 呼叫此函數
func finish_harvest() -> void:
	if item_data and item_data.icon:
		# 發出噴發特效請求
		SignalBus.request_effect_collect.emit(global_position, item_data.icon)
		# 通知背包收進道具
		SignalBus.item_collected.emit(item_data)
		print("[Interactable] %s 採集完成並存入背包" % interact_name)
