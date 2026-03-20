# res://src腳本/components積木/HealthComponent.gd
class_name HealthComponent
extends Node

signal health_changed(current_hp: int, max_hp: int)
signal died

@export var max_hp: int = 3
@onready var current_hp: int = max_hp

func take_damage(amount: int) -> void:
	if current_hp <= 0: return
	
	current_hp -= amount
	health_changed.emit(current_hp, max_hp)
	print("[Health] %s 受傷了，剩餘血量: %d" % [get_parent().name, current_hp])
	
	# 🔴 觸發父節點的受擊效果 (不論是石頭還是怪物)
	var parent = get_parent()
	if parent.has_method("play_hit_animation"):
		# 傳入 True 代表沒血了，觸發粉碎動畫
		parent.play_hit_animation(current_hp <= 0)
	
	if current_hp <= 0:
		died.emit()
