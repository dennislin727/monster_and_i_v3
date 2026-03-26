# --- 修改後的 Rock.gd ---
extends Node2D

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var health: HealthComponent = $HealthComponent
@onready var health_bar: ProgressBar = $UIAnchor/HealthBar

func _ready() -> void:
	if interactable and interactable.item_data:
		$Sprite2D.texture = interactable.item_data.icon

	if health and health_bar:
		health_bar.setup(health)

func _physics_process(delta: float) -> void:
	if health_bar == null or health == null:
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	var engaged := player != null and player.current_target == interactable
	var should_show := engaged or health.current_hp < health.max_hp
	health_bar.modulate.a = move_toward(health_bar.modulate.a, 1.0 if should_show else 0.0, delta * 2.0)

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
