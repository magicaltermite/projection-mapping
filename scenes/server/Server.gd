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
## resolves the UID to a scheduled room, computes the path via
## NavigationServer3D.MapGetPath(), and writes it into SessionState.
##
## The digital twin (NavigationRegion3D) will be added as a child.

extends Node3D

const PROJECTOR_CONFIG_PATH = "user://projector.json"

var _client_count: int = 0
var _scan_server: CardScanServer

@onready var _status: Label = $HUD/StatusLabel
@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
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
	_camera.rotation_degrees.y = proj.get("heading", 0.0)

func _refresh_status() -> void:
	_status.text = "Server running  |  clients: %d" % _client_count

# Call this whenever paths change to push updated state to all clients.
func broadcast_state() -> void:
	SessionState.push_to_clients()

func _on_navigation_requested(uid: String) -> void:
	# TODO (Step 6): look up uid in users table -> get scheduled classroom ->
	# compute path with NavigationServer3D.MapGetPath() ->
	# write into SessionState.active_paths -> broadcast_state().
	print("[Server] Card scan — uid: %s" % uid)
