# res://src腳本/components積木/EffectManager.gd
extends Node2D

func _ready() -> void:
	SignalBus.request_effect_collect.connect(_on_collect_effect)
	SignalBus.damage_spawned.connect(_on_damage_spawned)

func _on_damage_spawned(world_pos: Vector2, value: int, is_player: bool) -> void:
	# 1. 建立 Label 實體
	var label = Label.new()
	label.set_script(load("res://src腳本/components積木/FloatingNumber.gd"))
	add_child(label)
	
	# 2. 將世界座標轉為螢幕座標 (考慮相機 Zoom 與位置)
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	label.global_position = screen_pos
	
	# 3. 根據對象決定顏色
	var color = Color.ORANGE if is_player else Color.YELLOW
	label.start(value, color)

func _on_collect_effect(world_pos: Vector2, texture: Texture2D) -> void:
	if texture == null: return
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.z_index = 100 
	sprite.set_script(load("res://src腳本/components積木/CollectEffect.gd"))
	add_child(sprite)
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	sprite.global_position = screen_pos
	sprite.start_flying(screen_pos, Vector2(70, 70))
