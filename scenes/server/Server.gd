## Server
##
## Runs on the authoritative machine (Laptop A). Responsibilities:
##   - Starts the ENet host via Network.start_server().
##   - Instantiates CardScanServer (HTTP :8080) for the phone kiosk stander.
##   - Positions its own Camera3D at the physical projector location so
##     Laptop A's display output is already the correct projection image.
##   - Tracks connected client count and updates the HUD.
##   - Exposes broadcast_state() to push updated SessionState to all clients.
##
## Navigation is triggered by CardScanServer.navigation_requested: Server.gd
## resolves the UID to a route key (Step 6: schedule lookup), selects the
## matching from->to pair from ROUTES, and computes the path via
## NavigationServer3D.MapGetPath() before writing it into SessionState.
##
## Nav map readiness: NavigationServer3D needs at least one physics frame after
## _ready() before the baked navmesh is queryable. _init_nav_map() mirrors the
## poll-until-ready pattern from DrawPath.cs — it yields physics frames until
## map_get_regions() returns a non-empty array, then sets _nav_ready.
##
## The digital twin (NavigationRegion3D) will be added as a child.

extends Node3D

const PROJECTOR_CONFIG_PATH = "user://projector.json"

# Preconfigured routes: each entry is a complete from->to pair in the digital
# twin's coordinate system. The stand's physical location is implicit in the
# route's "from" — the server does not need to know where any stand is.
# Key   : route identifier used by the schedule lookup (Step 6).
# from  : start position (metres from TekBuilding reference point).
# to    : destination position (metres from TekBuilding reference point).
# label : display name returned to the kiosk UI.
# TODO: Scan UIDs from group members' studiekort, and assign a default destination.

const ROUTES: Dictionary = {
	"to_canteen":   {"label": "Canteen",   "marker": "CanteenMarker3D"},
	"to_library":   {"label": "Library",   "marker": "LibraryMarker3D"},
	"to_toilet":    {"label": "Toilet",    "marker": "ToiletMarker3D"},
	"to_classroom": {"label": "Classroom", "marker": "ClassroomMarker3D"},
}

# Map NFC UIDs to route keys. UID is printed to console on first scan.
# Replace placeholders before the demo.
const UID_ROUTES: Dictionary = {
	"00:00:00:01": "to_classroom",  # TODO Member 1
	"00:00:00:02": "to_classroom",  # TODO Member 2
	"00:00:00:03": "to_classroom",  # TODO Member 3
}

var _client_count: int = 0
var _scan_server: CardScanServer
var _nav_rid: RID
var _nav_ready: bool = false
var _proj_window: Window = null
var _proj_viewport: SubViewport = null

@onready var _status: Label = $HUD/StatusLabel
@onready var _camera: Camera3D = $Camera3D
@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var _stand: Node3D = $NavigationRegion3D/StandMarker3D

func _ready() -> void:
	NavigationServer3D.set_debug_enabled(true)
	_apply_projector_transform()
	_spawn_projector_window()
	var err = Network.start_server()
	if err != OK:
		_status.text = "ERROR: Could not bind port %d" % Network.PORT
		return
	Network.client_connected.connect(_on_client_connected)
	Network.client_disconnected.connect(_on_client_disconnected)
	_refresh_status()

	_scan_server = CardScanServer.new()
	_scan_server.navigation_requested.connect(_on_navigation_requested)
	add_child(_scan_server)

	_init_nav_map()

func _init_nav_map() -> void:
	_nav_rid = _nav_region.get_navigation_map()
	while NavigationServer3D.map_get_regions(_nav_rid).is_empty():
		await get_tree().physics_frame
	_nav_ready = true
	print("[Server] Nav map ready : %d region(s)" % NavigationServer3D.map_get_regions(_nav_rid).size())

func _on_client_connected(peer_id: int) -> void:
	_client_count += 1
	_refresh_status()
	SessionState.push_to_client(peer_id)

func _on_client_disconnected(_peer_id: int) -> void:
	_client_count -= 1
	_refresh_status()

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
		print("[Server] Editor : skipping projector window")
		return
	var screen_count := DisplayServer.get_screen_count()
	if screen_count < 2:
		print("[Server] Single display : projector window skipped")
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

	print("[Server] Projector window on screen %d" % proj_screen)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _proj_window and is_instance_valid(_proj_window):
			_proj_window.queue_free()

func _refresh_status() -> void:
	_status.text = "Server running  |  clients: %d" % _client_count

func broadcast_state() -> void:
	SessionState.push_to_clients()

func _on_navigation_requested(uid: String, forced_route: String, resolve: Callable) -> void:
	if not _nav_ready:
		push_warning("[Server] Nav map not ready -> scan ignored (uid: %s)" % uid)
		resolve.call("")
		return
	print("[Server] Card scanned -> uid: %s" % uid)
	var route_key: String = forced_route if not forced_route.is_empty() \
		else UID_ROUTES.get(uid, "to_classroom")
	var effective_uid: String = uid if not uid.is_empty() else "btn_%s" % route_key
	_navigate(effective_uid, route_key, resolve)

func _navigate(uid: String, route_key: String, resolve: Callable) -> void:
	if not ROUTES.has(route_key):
		push_warning("[Server] Unknown route: '%s'" % route_key)
		resolve.call("")
		return

	var route: Dictionary = ROUTES[route_key]
	var dest: Node3D = _nav_region.get_node_or_null(route["marker"])
	if dest == null:
		push_warning("[Server] Destination marker not found: '%s'" % route["marker"])
		resolve.call("")
		return

	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		_nav_rid, _stand.global_position, dest.global_position, true
	)
	if path.is_empty():
		push_warning("[Server] No path for route '%s' : verify marker is on navmesh" % route_key)
		resolve.call("")
		return

	SessionState.active_paths[uid.hash()] = path
	SessionState.state_updated.emit()
	broadcast_state()
	resolve.call(route["label"])
	print("[Server] Path: uid=%s  route=%s (%s)  %d waypoints" % [uid, route_key, route["label"], path.size()])
