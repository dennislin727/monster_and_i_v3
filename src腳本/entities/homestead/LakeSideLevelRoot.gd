# res://src腳本/entities/homestead/LakeSideLevelRoot.gd
# 湖畔關卡：執行期以 TileMapLayer 鋪地（圖集欄 0~7），碰撞仍由場景內 StaticBody2D 負責。
extends "res://src腳本/entities/homestead/LevelRoot.gd"

const _ATLAS_PATH := "res://assets圖片_字體_音效/環境/tiles/lakeside_terrain_atlas.png"
const TILE_PX := 32

@onready var _water: TileMapLayer = $TerrainMap/Water
@onready var _ground: TileMapLayer = $TerrainMap/Ground
@onready var _walls: TileMapLayer = $TerrainMap/WallsDecor
@onready var _bg: Sprite2D = $Art/MapBase/Background

var _source_id: int = -1


func _ready() -> void:
	super._ready()
	if _uses_full_background():
		$TerrainMap.visible = false
		return
	_build_tileset()
	_paint_terrain()


func _uses_full_background() -> bool:
	return _bg != null and _bg.texture != null


func _build_tileset() -> void:
	var tex: Texture2D = load(_ATLAS_PATH) as Texture2D
	if tex == null:
		push_error("LakeSideLevelRoot: missing atlas at %s" % _ATLAS_PATH)
		return
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	_source_id = ts.add_source(src)
	_water.tile_set = ts
	_ground.tile_set = ts
	_walls.tile_set = ts


func _paint_terrain() -> void:
	if _source_id < 0:
		return
	# 圖集欄：0,1 水；2 沙岸；3 野地草；4 家園草；5 土徑；6 內牆；7 外牆
	_fill_water_checker(_water, Vector2(-450, -400), Vector2(900, 520))
	_fill_rect_atlas(_ground, Vector2(-450, 120), Vector2(900, 230), 2)
	_fill_rect_atlas(_ground, Vector2(-895, -320), Vector2(330, 620), 4)
	# 家園東側到湖畔：土徑（與原走廊／出入口帶對齊）
	_fill_rect_atlas(_ground, Vector2(-565, -320), Vector2(115, 620), 5)
	_paint_wall_decals()


func _fill_rect_atlas(layer: TileMapLayer, top_left: Vector2, size: Vector2, atlas_col: int) -> void:
	var x0 := int(floor(top_left.x / float(TILE_PX)))
	var y0 := int(floor(top_left.y / float(TILE_PX)))
	var x1 := int(floor((top_left.x + size.x - 0.001) / float(TILE_PX)))
	var y1 := int(floor((top_left.y + size.y - 0.001) / float(TILE_PX)))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			layer.set_cell(Vector2i(x, y), _source_id, Vector2i(atlas_col, 0))


func _fill_water_checker(layer: TileMapLayer, top_left: Vector2, size: Vector2) -> void:
	var x0 := int(floor(top_left.x / float(TILE_PX)))
	var y0 := int(floor(top_left.y / float(TILE_PX)))
	var x1 := int(floor((top_left.x + size.x - 0.001) / float(TILE_PX)))
	var y1 := int(floor((top_left.y + size.y - 0.001) / float(TILE_PX)))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var col := 0 if ((x + y) & 1) == 0 else 1
			layer.set_cell(Vector2i(x, y), _source_id, Vector2i(col, 0))


func _paint_wall_decals() -> void:
	var stone := 6
	var outer := 7
	# 與原 WallFill 外框對齊（世界座標）
	_fill_rect_atlas(_walls, Vector2(-450, -440), Vector2(900, 40), stone)
	_fill_rect_atlas(_walls, Vector2(-450, 350), Vector2(900, 40), stone)
	_fill_rect_atlas(_walls, Vector2(-490, -360), Vector2(40, 310), stone)
	_fill_rect_atlas(_walls, Vector2(-490, 70), Vector2(40, 310), stone)
	_fill_rect_atlas(_walls, Vector2(-937, -370), Vector2(44, 740), outer)
	_fill_rect_atlas(_walls, Vector2(-612, -63), Vector2(200, 22), stone)
	_fill_rect_atlas(_walls, Vector2(-612, 47), Vector2(200, 22), stone)
	_fill_rect_atlas(_walls, Vector2(450, -350), Vector2(40, 700), stone)
