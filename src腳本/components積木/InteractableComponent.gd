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

# 敲擊動畫：如果是最後一下，彈得更大！
func play_hit_animation(is_final: bool) -> void:
	var parent_node = get_parent()
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	if is_final:
		# 最後一擊：變得很大然後縮小消失
		tween.tween_property(parent_node, "scale", Vector2(1.5, 1.5), 0.1)
		tween.parallel().tween_property(parent_node, "modulate:a", 0.0, 0.2)
	else:
		# 普通擊打：左右抖動 + 微微壓扁
		tween.tween_property(parent_node, "scale", Vector2(1.2, 0.8), 0.05)
		tween.tween_property(parent_node, "scale", Vector2(1.0, 1.0), 0.05)
		# 這裡可以加入 SignalBus.emit("play_sound", "hit_stone") 未來擴充音效
	
	await tween.finished

func finish_harvest() -> void:
	print("[Interactable] %s 採集完成！噴發物： %s" % [interact_name, item_data.display_name])
	
	# 這裡發送訊號給未來的「噴發特效系統」
	# SignalBus.request_effect_collect.emit(global_position, item_data.icon)
	
	SignalBus.item_collected.emit(item_data)
	get_parent().queue_free()
