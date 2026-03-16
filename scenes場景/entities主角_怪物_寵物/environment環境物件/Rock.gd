# res://scenes場景/entities主角_怪物_寵物/environment環境物件/Rock.gd
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var interactable: InteractableComponent = $InteractableComponent

func _ready() -> void:
	# 核心邏輯：從數據(Resource)自動讀取貼圖
	if interactable and interactable.item_data:
		var data = interactable.item_data
		
		# 優先穿「世界外觀」，如果沒設，就穿「道具圖示」
		if data.world_texture:
			sprite.texture = data.world_texture
		elif data.icon:
			sprite.texture = data.icon
