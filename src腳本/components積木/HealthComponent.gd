# res://src腳本/components積木/HealthComponent.gd
class_name HealthComponent
extends Node

signal health_changed(current_hp: int, max_hp: int)
signal died

@export var max_hp: int = 100
@onready var current_hp: int = max_hp:
	set(value):
		current_hp = clamp(value, 0, max_hp)
		health_changed.emit(current_hp, max_hp)
		# 確保主角扣血時，電台訊號 100% 發出
		if get_parent().is_in_group("player"):
			SignalBus.player_health_changed.emit(current_hp, max_hp)
			print("[Health] 主角血量更新: ", current_hp)

func take_damage(amount: int) -> void:
	if current_hp <= 0: return
	
	var parent = get_parent()
	
	# 🔴 核心修復：攔截霸體狀態
	# 如果父節點（例如史萊姆）正處於施法保護中，則完全不扣血
	if parent.get("is_casting_protected") == true:
		# 雖然不扣血，但我們依然呼叫動畫函式，讓 MonsterBase 去噴出 "Guarded!!" 文字
		if parent.has_method("play_hit_animation"):
			parent.play_hit_animation(false)
		return # 直接結束函式，血量不變
	
	# 正常扣血流程
	self.current_hp -= amount
	
	# 觸發正常的受擊或死亡動畫
	if parent.has_method("play_hit_animation"):
		parent.play_hit_animation(current_hp <= 0)
	
	if current_hp <= 0:
		died.emit()

func heal(amount: int) -> void:
	if amount <= 0 or current_hp <= 0:
		return
	var parent := get_parent()
	self.current_hp = mini(max_hp, current_hp + amount)
	var pos := Vector2.ZERO
	if parent is Node2D:
		pos = (parent as Node2D).global_position
	SignalBus.heal_spawned.emit(pos, amount)
