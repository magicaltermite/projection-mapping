## CardScanServer
##
## HTTP server for the phone NFC kiosk stander. Instantiated by Server.gd on
## the authoritative machine and runs on port 8080 alongside the ENet game
## server (port 7777).
##
## Routes:
##   GET  /scan     -> serves web/scan.html (the always-on kiosk UI)
##   POST /navigate -> accepts { uid: String }, emits navigation_requested
##
## Write path (visitor scan -> projector):
##   Visitor taps card to phone -> NDEFReader reads NFC UID ->
##   POST /navigate -> navigation_requested.emit(uid) ->
##   Server.gd looks up schedule -> NavigationServer3D.MapGetPath() ->
##   SessionState.active_paths -> broadcast_state() -> projectors light up.
##
## The /navigate response will include a "destination" field once schedule
## lookup is wired in (Step 6), so the kiosk UI can confirm the room name.

class_name CardScanServer
extends Node

const HTTP_PORT = 8080

signal navigation_requested(uid: String, forced_route: String, resolve: Callable)

var _server: HttpServer

func _ready() -> void:
	_server = HttpServer.new()
	_server.port = HTTP_PORT

	_server.register_router(HttpRouter.new("/scan", {
		"get": func(request: HttpRequest, response: HttpResponse) -> bool:
			var html := FileAccess.get_file_as_string("res://web/scan.html")
			if html.is_empty():
				response.send(500, "scan.html not found")
				return true
			response.send(200, html, "text/html; charset=utf-8")
			return true,
	}))

	_server.register_router(HttpRouter.new("/navigate", {
		"post": func(request: HttpRequest, response: HttpResponse) -> bool:
			var body = JSON.parse_string(request.body)
			if body == null:
				response.json(400, {"error": "invalid json"})
				return true
			var uid: String = body.get("uid", "")
			var forced_route: String = body.get("route", "")
			if uid.is_empty() and forced_route.is_empty():
				response.json(400, {"error": "missing uid or route"})
				return true
			var resolve := func(label: String) -> void:
				if label.is_empty():
					response.json(500, {"error": "navigation failed"})
				else:
					response.json(200, {"ok": true, "destination": label})
			navigation_requested.emit(uid, forced_route, resolve)
			return true,
	}))

	add_child(_server)
	_server.start()
	print("[CardScanServer] Listening on port %d : open http://<server-ip>:%d/scan on phone" % [HTTP_PORT, HTTP_PORT])
