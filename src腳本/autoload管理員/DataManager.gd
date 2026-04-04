# res://src/autoload/DataManager.gd
extends Node

# 儲存所有道具的字典 [item_id, ItemResource]
var item_database: Dictionary = {}

# 道具存放的資料夾路徑
const ITEMS_PATH = "res://resources身分證/items/"

func _ready() -> void:
	print("[DataManager] 管理員已報到！正在掃描資源...")
	load_essential_data()

func load_essential_data() -> void:
	# 開始掃描資料夾
	var dir = DirAccess.open(ITEMS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				# 載入 Resource 檔案
				var resource = load(ITEMS_PATH + file_name)
				if resource is ItemResource:
					item_database[resource.item_id] = resource
					print("[DataManager] 已載入道具: ", resource.display_name)
			
			file_name = dir.get_next()
		
		print("[DataManager] 資料庫初始化完畢，共載入 %d 個項目。" % item_database.size())
	else:
		push_error("[DataManager] 找不到路徑: " + ITEMS_PATH)

# 安全取得道具的方法
func get_item(id: String) -> ItemResource:
	if item_database.has(id):
		return item_database[id]
	return null
