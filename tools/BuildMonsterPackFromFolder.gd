# =============================================================================
# 從「怪物圖檔根目錄」批次產生：SpriteFrames、pet_*.tres、{id}.tres（MonsterResource）
#
# 【編輯器】開本檔 → 執行 EditorScript（Run）。
# 【命令列】見 run_monster_pack_cli.gd（免開編輯器）。
# 設定列表在 MonsterPackBuilder.gd 的 BUILD_SPECS。
# =============================================================================
@tool
extends EditorScript

const _PackBuilder := preload("res://tools/MonsterPackBuilder.gd")


func _run() -> void:
	_PackBuilder.new().run_all()
