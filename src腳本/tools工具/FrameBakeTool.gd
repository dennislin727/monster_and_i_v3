extends Control

@export_group("Input")
@export var effect_scene: PackedScene
@export var auto_bake_on_ready: bool = false
@export var bake_trigger_action: StringName = &"ui_accept"

@export_group("Capture")
@export var viewport_size: Vector2i = Vector2i(512, 512)
@export var frame_count: int = 16
@export var capture_fps: float = 30.0
@export var warmup_frames: int = 1
@export var transparent_bg: bool = true

@export_group("Output")
@export var output_dir: String = "user://fx_bake"
@export var file_prefix: String = "frame"

@onready var viewport: SubViewport = $Root/SubViewportContainer/BakeViewport
@onready var capture_root: Node2D = $Root/SubViewportContainer/BakeViewport/CaptureRoot
@onready var hint_label: Label = $Root/Hud/Hint

var _effect_instance: Node2D = null
var _is_baking: bool = false

func _ready() -> void:
	_configure_viewport()
	_update_hint_text()
	if auto_bake_on_ready:
		call_deferred("start_bake")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(bake_trigger_action):
		start_bake()

func start_bake() -> void:
	if _is_baking:
		return
	if effect_scene == null:
		push_warning("[FrameBakeTool] 請先指定 effect_scene。")
		return
	if frame_count <= 0:
		push_warning("[FrameBakeTool] frame_count 必須 > 0。")
		return
	if capture_fps <= 0.0:
		push_warning("[FrameBakeTool] capture_fps 必須 > 0。")
		return

	_is_baking = true
	_configure_viewport()
	_reset_capture_root()
	_spawn_effect()
	await _bake_frames()
	_is_baking = false
	_update_hint_text()

func _configure_viewport() -> void:
	viewport.size = viewport_size
	viewport.transparent_bg = transparent_bg
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _reset_capture_root() -> void:
	for c in capture_root.get_children():
		c.queue_free()
	_effect_instance = null

func _spawn_effect() -> void:
	var node := effect_scene.instantiate()
	if node is Node2D:
		_effect_instance = node as Node2D
		_effect_instance.position = viewport_size / 2
		capture_root.add_child(_effect_instance)
	else:
		push_warning("[FrameBakeTool] effect_scene 根節點不是 Node2D。")

func _bake_frames() -> void:
	var absolute_dir := ProjectSettings.globalize_path(output_dir)
	var mk_err := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mk_err != OK:
		push_warning("[FrameBakeTool] 無法建立輸出目錄: %s (err=%d)" % [absolute_dir, mk_err])
		return

	var dt := 1.0 / capture_fps
	var warm := maxi(0, warmup_frames)
	for _i in warm:
		await get_tree().process_frame

	for i in frame_count:
		await get_tree().process_frame
		var img := viewport.get_texture().get_image()
		if img == null:
			continue
		var file_name := "%s%04d.png" % [file_prefix, i]
		var target_path := output_dir.path_join(file_name)
		var err := img.save_png(target_path)
		if err != OK:
			push_warning("[FrameBakeTool] 存檔失敗: %s (err=%d)" % [target_path, err])
		await get_tree().create_timer(dt).timeout

	print("[FrameBakeTool] 輸出完成：", absolute_dir)

func _update_hint_text() -> void:
	var scene_name := effect_scene.resource_path.get_file() if effect_scene else "（尚未指定）"
	var run_state := "烘焙中..." if _is_baking else "待命"
	hint_label.text = (
		"[FrameBakeTool]\n"
		+ "特效: %s\n"
		+ "輸出: %s\n"
		+ "幀數: %d @ %.1f fps\n"
		+ "按 Enter 開始烘焙 (%s)"
	) % [scene_name, output_dir, frame_count, capture_fps, run_state]
