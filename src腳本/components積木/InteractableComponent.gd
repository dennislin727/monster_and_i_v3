# res://src/components/InteractableComponent.gd
class_name InteractableComponent
extends Area2D

@export_group("基礎設定")
@export var item_data: ItemResource 
@export var interact_name: String = "採集物"

@export_group("採集參數")
@export var max_hits: int = 3       # 需要敲幾下
@export var hit_interval: float = 0.4 # 每敲一下的間隔（防止瞬間敲完）

var current_hits: int = 0
var is_harvesting: bool = false

signal harvested(item: ItemResource, pos: Vector2)

func start_harvest() -> void:
	if is_harvesting or current_hits >= max_hits:
		return
	
	is_harvesting = true
	current_hits += 1
	
	# 執行敲擊動畫
	await play_hit_animation(current_hits == max_hits)
	
	if current_hits >= max_hits:
		finish_harvest()
	else:
		# 敲完一下，冷卻一小段時間才能敲下一波
		await get_tree().create_timer(hit_interval).timeout
		is_harvesting = false

func play_hit_animation(is_final: bool) -> void:
	var parent_node = get_parent()
	# 使用 TRANS_ELASTIC 或 TRANS_BOUNCE 增加 Q 彈感
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if is_final:
		# 最後一擊：先縮小再猛力放大，然後消失
		tween.tween_property(parent_node, "scale", Vector2(0.8, 0.8), 0.05)
		tween.tween_property(parent_node, "scale", Vector2(1.8, 1.8), 0.15)
		tween.parallel().tween_property(parent_node, "modulate:a", 0.0, 0.15)
		# 這裡多等一小段時間，讓玩家看清楚爆炸感
		await tween.finished
		await get_tree().create_timer(0.1).timeout 
	else:
		# 普通擊打：稍微壓扁再彈回
		parent_node.scale = Vector2(1.2, 0.8) # 瞬間壓扁
		tween.tween_property(parent_node, "scale", Vector2(1.0, 1.0), 0.2)
		
	await tween.finished

func finish_harvest() -> void:
	if item_data and item_data.icon:
		SignalBus.request_effect_collect.emit(global_position, item_data.icon)
		print("[Interactable] 已經發出噴發請求，位置：", global_position) # 加這行來確認
	
	SignalBus.item_collected.emit(item_data)
	get_parent().queue_free()
