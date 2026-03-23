# --- 修改後的 Rock.gd ---
extends Node2D

@onready var interactable = $InteractableComponent
@onready var health = $HealthComponent

func _ready() -> void:
	# 設置圖片
	if interactable and interactable.item_data:
		$Sprite2D.texture = interactable.item_data.icon
	
	# 🔴 刪除原本在這裡的 health.died 連接邏輯
	# 因為 InteractableComponent 內部已經有連接並處理 queue_free 了

# 🔴 僅保留被 HealthComponent 呼叫的動畫函數
func play_hit_animation(is_final: bool) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if is_final:
		# 死亡時的收縮動畫，讓它看起來是消失而不是直接不見
		tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.1)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
	else:
		# 壓扁彈起效果
		scale = Vector2(1.2, 0.8) 
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
