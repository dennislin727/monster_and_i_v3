class_name HealthComponent
extends Node

signal health_changed(current_hp: int, max_hp: int)
signal died

@export var max_hp: int = 3
@onready var current_hp: int = max_hp:
	set(value):
		current_hp = clamp(value, 0, max_hp)
		health_changed.emit(current_hp, max_hp)

func take_damage(amount: int) -> void:
	if current_hp <= 0: return
	self.current_hp -= amount
	
	var parent = get_parent()
	if parent.has_method("play_hit_animation"):
		parent.play_hit_animation(current_hp <= 0)
	
	if current_hp <= 0:
		died.emit()
