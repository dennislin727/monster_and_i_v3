# 命令列一鍵產生怪物／寵物 .tres
# godot --headless --path <專案根> -s res://tools/run_monster_pack_cli.gd
extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gd: GDScript = load("res://tools/MonsterPackBuilder.gd") as GDScript
	if gd == null:
		push_error("run_monster_pack_cli: 無法載入 MonsterPackBuilder.gd")
		quit(1)
		return
	var builder: Variant = gd.new()
	if builder == null or not builder.has_method("run_all"):
		push_error("run_monster_pack_cli: 無法建立建置器")
		quit(1)
		return
	var n: int = int(builder.call("run_all"))
	quit(0 if n >= 0 else 1)
