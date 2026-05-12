## Client
##
## Runs on every non-authoritative machine (Laptop B and any future additions).
## Responsibilities:
##   - Reads user://projector.json (guaranteed present by Bootstrap) and
##     positions Camera3D to match the physical projector in the digital twin.
##   - Connects to the server via Network.connect_to_server().
##   - Listens to SessionState.state_updated and forwards active_paths to
##     PathRenderer (Step 3) whenever the server pushes a new state.
##
## The client carries no navigation logic and holds no copy of the NavMesh.
## It only renders what the server tells it to render.

extends Node3D

const PROJECTOR_CONFIG_PATH = "user://projector.json"

@onready var _status: Label = $HUD/StatusLabel
@onready var _camera: Camera3D = $Camera3D

var _proj_window: Window = null
var _proj_viewport: SubViewport = null

func _ready() -> void:
	Network.connected_to_server.connect(_on_connected)
	Network.disconnected_from_server.connect(_on_disconnected)
	SessionState.state_updated.connect(_on_state_updated)
	_apply_projector_transform()
	_spawn_projector_window()
	_connect_to_server()

func _apply_projector_transform() -> void:
	var file = FileAccess.open(PROJECTOR_CONFIG_PATH, FileAccess.READ)
	var proj: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	_camera.position = Vector3(proj.get("x", 0.0), proj.get("y", 0.0), proj.get("z", 0.0))
	_camera.rotation_degrees = Vector3(
		proj.get("pitch",   -55.0),
		proj.get("heading",   0.0),
		proj.get("roll",      0.0)
	)

func _spawn_projector_window() -> void:
	if OS.has_feature("editor"):
		print("[Client] Editor : skipping projector window")
		return
	var screen_count := DisplayServer.get_screen_count()
	if screen_count < 2:
		print("[Client] Single display : projector window skipped")
		return
	var proj_screen := screen_count - 1
	DisplayServer.window_set_current_screen(0)

	_proj_viewport = SubViewport.new()
	_proj_viewport.size = DisplayServer.screen_get_size(proj_screen)
	_proj_viewport.own_world_3d = false
	_proj_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_proj_viewport)

	var proj_cam := Camera3D.new()
	proj_cam.transform = _camera.global_transform
	proj_cam.fov = _camera.fov
	proj_cam.near = _camera.near
	proj_cam.far = _camera.far
	_proj_viewport.add_child(proj_cam)

	_proj_window = Window.new()
	_proj_window.unfocusable = true
	_proj_window.borderless = true
	_proj_window.current_screen = proj_screen
	_proj_window.mode = Window.MODE_FULLSCREEN
	get_tree().root.add_child(_proj_window)
	_proj_window.show()

	var tex_rect := TextureRect.new()
	tex_rect.texture = _proj_viewport.get_texture()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_proj_window.add_child(tex_rect)

	print("[Client] Projector window on screen %d" % proj_screen)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _proj_window and is_instance_valid(_proj_window):
			_proj_window.queue_free()

func _connect_to_server() -> void:
	var ip: String = SessionState.client_config.get("server_ip", "127.0.0.1")
	_status.text = "Connecting to %s..." % ip
	var err = Network.connect_to_server(ip)
	if err != OK:
		_status.text = "ERROR: Could not initiate connection"

func _on_connected() -> void:
	_status.text = "Connected"

func _on_disconnected() -> void:
	_status.text = "Lost connection to server"

func _on_state_updated() -> void:
	pass
