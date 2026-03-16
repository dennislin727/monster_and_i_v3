# res://src腳本/components積木/EffectManager.gd
extends Node2D

func _ready() -> void:
	SignalBus.request_effect_collect.connect(_on_collect_effect)

func _on_collect_effect(world_pos: Vector2, texture: Texture2D) -> void:
	# 1. 建立圖示
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(0.5, 0.5)
	# 掛載飛行動畫腳本
	sprite.set_script(load("res://src腳本/components積木/CollectEffect.gd"))
	add_child(sprite)
	
	# 2. 【核心修復】將「世界座標」轉換為「螢幕座標」
	# 這樣不論攝影機在哪，圖示都會從石頭在螢幕上的位置噴出來
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	sprite.global_position = screen_pos
	
	# 3. 設定目標位置（例如螢幕左上角 50, 50）
	var target_screen_pos = Vector2(50, 50)
	
	# 呼叫開始飛行
	sprite.start_flying(screen_pos, target_screen_pos)
