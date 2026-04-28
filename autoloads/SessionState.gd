## SessionState
##
## Autoload singleton. Holds all shared navigation state and owns the RPC (Remote Procedure Call)
## that synchronises it from server to clients.
##
## Because autoloads live at the same node path (/root/SessionState) on every
## peer, RPCs defined here are correctly routed by Godot's multiplayer system ->
## unlike RPCs on scene-root nodes whose paths differ between server and client.
##
## Write path (server only):
##   Modify active_paths / path_progress, then call push_to_clients() or
##   push_to_client(peer_id) to replicate.
##
## Read path (clients):
##   Listen to state_updated to react to incoming data.

extends Node

signal state_updated()

# Set by Bootstrap before scene change on client machines
var client_config: Dictionary = {}

# Keyed by session_id (int). Each value is a PackedVector3Array of waypoints.
var active_paths: Dictionary = {}

# Scroll offset for the hologram animation, driven by server each physics tick.
var path_progress: float = 0.0

# Called by server to push full state to all connected clients.
func push_to_clients() -> void:
	_receive_state.rpc(active_paths, path_progress)

# Called by server to push state to one specific peer (e.g. on fresh connect).
func push_to_client(peer_id: int) -> void:
	_receive_state.rpc_id(peer_id, active_paths, path_progress)

@rpc("authority", "call_remote", "reliable")
func _receive_state(paths: Dictionary, progress: float) -> void:
	active_paths = paths
	path_progress = progress
	state_updated.emit()
