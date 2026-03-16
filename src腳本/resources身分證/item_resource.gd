# res://src/resources/item_resource.gd
class_name ItemResource # 讓它出現在「建立資源」的選單中
extends Resource

# 使用枚舉來區分道具類型，方便後續邏輯判斷
enum ItemType { MATERIAL, CONSUMABLE, EQUIPMENT, QUEST, SEAL_TOOL }

@export_group("基礎資訊")
@export var item_id: String = "item_000"     # 內部 ID，用於存檔或索引
@export var display_name: String = "新道具"    # 顯示給玩家看的名稱
@export var type: ItemType = ItemType.MATERIAL # 道具種類
@export_multiline var description: String = "" # 道具描述

@export_group("視覺視覺")
@export var icon: Texture2D                   # 背包中顯示的圖示
@export var world_texture: Texture2D          # 掉落在地上的圖示

@export_group("屬性")
@export var is_stackable: bool = true         # 是否可堆疊
@export var max_stack: int = 99               # 最大堆疊數

# 這個函數可以讓未來採集時，方便印出資訊偵錯
func _to_string() -> String:
	return "[道具] %s (ID: %s)" % [display_name, item_id]
