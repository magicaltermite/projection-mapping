## Server
##
## Runs on the authoritative machine (Laptop A). Responsibilities:
##   - Starts the ENet host via Network.start_server().
##   - Positions its own Camera3D at the physical projector location so
##     Laptop A's display output is already the correct projection image.
##   - Tracks connected client count and updates the HUD.
##   - Exposes broadcast_state() for upstream logic (path computation, Arduino
##     hook for standers) to call whenever SessionState.active_paths changes.
##
## The digital twin (NavigationRegion3D) will be added as a child.

extends Node3D

const PROJECTOR_CONFIG_PATH = "user://projector.json"

var _client_count: int = 0

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
