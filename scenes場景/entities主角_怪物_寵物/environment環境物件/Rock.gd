# res://scenes場景/entities主角_怪物_寵物/environment環境物件/Rock.gd
extends Node2D

@onready var interactable = $InteractableComponent
@onready var health = $HealthComponent

func _ready() -> void:
	# 1. 設置圖片 (之前的邏輯)
	if interactable and interactable.item_data:
		$Sprite2D.texture = interactable.item_data.icon
	
	# 2. 監聽死亡訊號
	if health:
		health.died.connect(_on_rock_destroyed)

# 🔴 當血量歸零時觸發
func _on_rock_destroyed() -> void:
	# 呼叫原本在 InteractableComponent 裡的噴發與消失邏輯
	if interactable:
		interactable.finish_harvest() # 噴發小石頭圖示
	
	# 石頭本體消失
	queue_free()

# 🔴 被 HealthComponent 呼叫的動畫函數
func play_hit_animation(is_final: bool) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if is_final:
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
	else:
		# 壓扁彈起效果 (重心在底部)
		scale = Vector2(1.2, 0.8) 
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
