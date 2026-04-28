## Network
##
## Autoload singleton. Thin wrapper around ENetMultiplayerPeer.
## All peers (server and clients) communicate exclusively through this node.
##
## Server usage:
##   Network.start_server() -> binds ENet on PORT, emits client_connected /
##   client_disconnected as peers join or leave.
##
## Client usage:
##   Network.connect_to_server(ip) -> initiates ENet connection, emits
##   connected_to_server or disconnected_from_server accordingly.
##
## Nothing outside this file should touch multiplayer.multiplayer_peer directly.

extends Node

const PORT = 7777
const MAX_CLIENTS = 8

signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal connected_to_server()
signal disconnected_from_server()

func start_server() -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("[Network] Failed to start server: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(id): client_connected.emit(id))
	multiplayer.peer_disconnected.connect(func(id): client_disconnected.emit(id))
	print("[Network] Server listening on port %d" % PORT)
	return OK

func connect_to_server(ip: String) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	if err != OK:
		push_error("[Network] Failed to connect: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func(): connected_to_server.emit())
	multiplayer.connection_failed.connect(func(): push_error("[Network] Connection to server failed"))
	multiplayer.server_disconnected.connect(func(): disconnected_from_server.emit())
	print("[Network] Connecting to %s:%d" % [ip, PORT])
	return OK

func is_host() -> bool:
	return multiplayer.is_server()

func get_peers() -> Array:
	return multiplayer.get_peers()
