# res://src腳本/components積木/EffectManager.gd
extends Node2D

func _ready() -> void:
	SignalBus.request_effect_collect.connect(_on_collect_effect)

func _on_collect_effect(world_pos: Vector2, texture: Texture2D) -> void:
	if texture == null:
		print("[EffectManager] 錯誤：沒有圖片資料！")
		return

	# 1. 建立 Sprite
	var sprite = Sprite2D.new()
	sprite.texture = texture
	# 確保它在最前面
	sprite.z_index = 100 
	sprite.set_script(load("res://src腳本/components積木/CollectEffect.gd"))
	add_child(sprite)
	
	# 2. 計算螢幕座標 (考慮相機位置)
	# get_canvas_transform() 會把相機移動過的「世界座標」轉成「螢幕座標」
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	
	# --- 偵錯用印出 ---
	print("石頭世界座標: ", world_pos)
	print("轉換後螢幕座標: ", screen_pos)
	# ----------------
	
	sprite.global_position = screen_pos
	
	# 目標點：螢幕左上角 (例如 70, 70)
	var target_pos = Vector2(70, 70)
	sprite.start_flying(screen_pos, target_pos)
