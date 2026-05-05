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

func _ready() -> void:
	Network.connected_to_server.connect(_on_connected)
	Network.disconnected_from_server.connect(_on_disconnected)
	SessionState.state_updated.connect(_on_state_updated)
	_apply_projector_transform()
	_connect_to_server()

func _apply_projector_transform() -> void:
	var file = FileAccess.open(PROJECTOR_CONFIG_PATH, FileAccess.READ)
	var proj: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	_camera.position = Vector3(proj.get("x", 0.0), proj.get("y", 0.0), proj.get("z", 0.0))
	_camera.rotation_degrees.y = proj.get("heading", 0.0)

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
	# Step 3: pass SessionState.active_paths to PathRenderer for rendering.
	for session_id: int in SessionState.active_paths:
		var path: PackedVector3Array = SessionState.active_paths[session_id]
		print("[Client] Path update — session %d: %d waypoints" % [session_id, path.size()])
