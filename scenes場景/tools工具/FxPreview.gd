extends Node2D

const LIB_PATH := "res://resources身分證/skill_fx_templates/FxTemplateLibrary.gd"
const FX_NODE_SCRIPT := "res://src腳本/components積木/ProceduralFxNode.gd"
const TEMPLATE_IDS: Array[String] = [
	"warning_circle",
	"warning_line",
	"fissure",
	"fan_wave",
	"smoke",
	"fire",
	"golden_motes",
	"falling_leaves",
	"rain",
	"afterimage_trail",
	"purple_trail",
	"water_column",
	"projectile_tail"
]

@onready var info_label: Label = $CanvasLayer/Info
@onready var anchor_firefly: Marker2D = $Anchors/Firefly
@onready var anchor_fire: Marker2D = $Anchors/Fire
@onready var anchor_center: Marker2D = $Anchors/Center

var _current_idx: int = 0

func _ready() -> void:
	_replay_current()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_replay_current()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_spawn_template("golden_motes", anchor_firefly.global_position, Vector2.RIGHT)
		elif event.keycode == KEY_2:
			_spawn_template("fire", anchor_fire.global_position, Vector2.UP)
		elif event.keycode == KEY_Q or event.keycode == KEY_COMMA:
			_shift_template(-1)
		elif event.keycode == KEY_E or event.keycode == KEY_PERIOD:
			_shift_template(1)
		elif event.is_action_pressed("ui_left"):
			_shift_template(-1)
		elif event.is_action_pressed("ui_right"):
			_shift_template(1)

func _replay_current() -> void:
	_clear_fx()
	var template_id: String = TEMPLATE_IDS[_current_idx]
	_spawn_template(template_id, anchor_center.global_position, _facing_for(template_id))
	_spawn_template("golden_motes", anchor_firefly.global_position, Vector2.RIGHT)
	_spawn_template("fire", anchor_fire.global_position, Vector2.UP)
	_show_help()

func _shift_template(step: int) -> void:
	_current_idx = posmod(_current_idx + step, TEMPLATE_IDS.size())
	_replay_current()

func _spawn_template(template_id: String, world_pos: Vector2, facing: Vector2) -> void:
	var lib: Variant = load(LIB_PATH)
	if lib == null:
		return
	var res: Resource = lib.make_template(template_id)
	if res == null:
		return
	var fx_node := Node2D.new()
	fx_node.set_script(load(FX_NODE_SCRIPT))
	fx_node.add_to_group("fx_preview_runtime")
	add_child(fx_node)
	fx_node.global_position = world_pos
	if fx_node.has_method("setup"):
		fx_node.setup(res, facing)

func _clear_fx() -> void:
	for n in get_tree().get_nodes_in_group("fx_preview_runtime"):
		if is_instance_valid(n):
			n.queue_free()

func _show_help() -> void:
	var current_id: String = TEMPLATE_IDS[_current_idx]
	info_label.text = (
		"FX Preview - 13 Templates\n"
		+ "Current: %s (%d/%d)\n"
		+ "[Q/E] or [</>] or [Left/Right] switch\n"
		+ "[Enter] replay current + ambience\n"
		+ "[1] firefly  [2] fire"
	) % [current_id, _current_idx + 1, TEMPLATE_IDS.size()]

func _facing_for(template_id: String) -> Vector2:
	match template_id:
		"warning_line", "fissure", "afterimage_trail", "purple_trail", "projectile_tail":
			return Vector2.RIGHT
		"fan_wave":
			return Vector2(-0.6, -0.2).normalized()
		"water_column", "rain", "fire", "golden_motes", "smoke", "falling_leaves":
			return Vector2.UP
		_:
			return Vector2.RIGHT
