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
	# 如果正在採集中，就跳過，防止一秒鐘被判定採集 60 次
	if is_harvesting: return
	
	is_harvesting = true
	current_hits += 1
	
	await play_hit_animation(current_hits >= max_hits)
	
	if current_hits >= max_hits:
		finish_harvest()
	else:
		# 🔴 這裡是關鍵：縮短 CD 時間，讓主角的五連砍能跟上
		await get_tree().create_timer(0.1).timeout 
		is_harvesting = false

func play_hit_animation(is_final: bool) -> void:
	var parent_node = get_parent()
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if is_final:
		# 最後一擊：猛力壓扁後向上噴發消失
		tween.tween_property(parent_node, "scale", Vector2(1.6, 0.4), 0.05) # 壓得超扁
		tween.tween_property(parent_node, "scale", Vector2(0.2, 2.0), 0.1)  # 向上拉長噴射
		tween.parallel().tween_property(parent_node, "modulate:a", 0.0, 0.1)
	else:
		# 普通敲擊：壓扁 (Y縮小) + 變寬 (X變大) -> 經典的 Q 彈感
		# 因為重心在底部，所以 Y 縮小時，頂部會往下掉，底部不動
		parent_node.scale = Vector2(1.3, 0.7) # 瞬間壓扁
		tween.tween_property(parent_node, "scale", Vector2(1.0, 1.0), 0.25)
		
		# 加上一點點隨機左右晃動，更有「受力」的感覺
		parent_node.rotation_degrees = randf_range(-10, 10)
		tween.parallel().tween_property(parent_node, "rotation_degrees", 0.0, 0.2)
	
	await tween.finished

func finish_harvest() -> void:
	if item_data and item_data.icon:
		SignalBus.request_effect_collect.emit(global_position, item_data.icon)
		print("[Interactable] 已經發出噴發請求，位置：", global_position) # 加這行來確認
	
	SignalBus.item_collected.emit(item_data)
	get_parent().queue_free()
