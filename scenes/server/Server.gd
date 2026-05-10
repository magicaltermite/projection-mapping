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
# TODO: Measure all positions from the TekBuilding reference point and replace
#       these placeholders. Use the Godot editor to click on the navmesh and
#       read the 3D coordinates from the inspector.
const ROUTES: Dictionary = {
	"to_canteen":    {"label": "Canteen",    "from": Vector3( 0.0, 0.0,  0.0), "to": Vector3( 5.0, 0.0,  10.0)},
	"to_auditorium": {"label": "Auditorium", "from": Vector3( 0.0, 0.0,  0.0), "to": Vector3(-3.0, 0.0,  15.0)},
	"to_room_u10":   {"label": "Room U10",   "from": Vector3( 0.0, 0.0,  0.0), "to": Vector3( 8.0, 0.0,   5.0)},
	"to_room_u20":   {"label": "Room U20",   "from": Vector3( 0.0, 0.0,  0.0), "to": Vector3(-8.0, 0.0,   5.0)},
	"to_room_u40":   {"label": "Room U40",   "from": Vector3( 0.0, 0.0,  0.0), "to": Vector3( 0.0, 0.0, -10.0)},
	"to_library":    {"label": "Library",    "from": Vector3( 0.0, 0.0,  0.0), "to": Vector3(12.0, 0.0,   0.0)},
	"to_reception":  {"label": "Reception",  "from": Vector3( 0.0, 0.0,  0.0), "to": Vector3( 0.0, 0.0,   2.0)},
}

var _client_count: int = 0
var _scan_server: CardScanServer
var _nav_rid: RID
var _nav_ready: bool = false

@onready var _status: Label = $HUD/StatusLabel
@onready var _camera: Camera3D = $Camera3D
@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D

var MOUNT_ROLL: float = 0
var MOUNT_PITCH: float = -56

func _ready() -> void:
	NavigationServer3D.set_debug_enabled(true)
	_apply_projector_transform()
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
	print("[Server] Nav map ready — %d region(s)" % NavigationServer3D.map_get_regions(_nav_rid).size())

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
	#_camera.position = Vector3(1.1, 1.47, 0.76)
	_camera.rotation_degrees = Vector3(MOUNT_PITCH, proj.get("heading", 0.0), MOUNT_ROLL)
	#_camera.rotation_degrees = Vector3(-56.0, -72.0, 0)

func _refresh_status() -> void:
	_status.text = "Server running  |  clients: %d" % _client_count

func broadcast_state() -> void:
	SessionState.push_to_clients()

func _on_navigation_requested(uid: String) -> void:
	if not _nav_ready:
		push_warning("[Server] Nav map not ready — scan ignored (uid: %s)" % uid)
		return
	# TODO (Step 6): look up uid in users/schedule table -> resolve route key.
	# Hardcoded to a test route until schedule lookup is implemented.
	_navigate(uid, "to_canteen")

func _navigate(uid: String, route_key: String) -> void:
	if not ROUTES.has(route_key):
		push_warning("[Server] Unknown route: '%s'" % route_key)
		return

	var route: Dictionary = ROUTES[route_key]
	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		_nav_rid, route["from"], route["to"], true
	)

	if path.is_empty():
		push_warning("[Server] No path for route '%s' — verify from/to coords against navmesh" % route_key)
		return

	SessionState.active_paths[uid.hash()] = path
	SessionState.state_updated.emit()
	broadcast_state()
	print("[Server] Path: uid=%s  route=%s (%s)  %d waypoints" % [uid, route_key, route["label"], path.size()])
