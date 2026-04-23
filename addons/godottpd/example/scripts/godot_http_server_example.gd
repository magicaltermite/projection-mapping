extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var server = HttpServer.new()
	server.register_router(_create_user_router())
	server.register_router(_create_user_location_router())
	server.register_router(_create_route_router())
	server.register_router(_create_compute_image_router())
	add_child(server)
	server.enable_cors(["http://localhost:8060"])
	server.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



var db = Database.new().get_instance()

var post_user = func (request: HttpRequest, response: HttpResponse): 
	var dto = JSON.parse_string(request.body)
	if dto == null || dto.name == null:
		response.send(400, "Invalid username")
		return false
	
	var id = db.query("INSERT INTO users (name) VALUES (%s) RETURNING id;" % dto.name)
	response.send(200, JSON.stringify({
		'id': id,
		'name': dto.name
		}))
	return true

var get_user = func (request: HttpRequest, response: HttpResponse):
	var id = request.parameters.get("id")
	if id == null:
		response.send(400, "Invalid user id")
		return false
	
	var user = db.query("SELECT * FROM users WHERE id = %s"%id)
	response.send(200, JSON.stringify(user))
	return JSON.stringify(user)


func _create_user_router() -> HttpRouter:
	return HttpRouter.new("/user/:id", {
		'post': post_user,
		'get': get_user,
		'delete': func (request: HttpRequest, response: HttpResponse):
			var id = request.parameters.get("id")
			if id == null:
				response.send(400, "Invalid user id")
				return false
			
			db.query("DELETE FROM users WHERE id = %s"%id)
			response.send(200, "User deleted successfully")
			return true
	})

func _create_user_location_router() -> HttpRouter:
	return HttpRouter.new("/user/:id/location", {
		'post': func (request: HttpRequest, response: HttpResponse):
			var id = request.parameters.get("id")
			if id == null:
				response.send(400, "Invalid user id")
				return false
			
			var dto = JSON.parse_string(request.body)
			if dto == null || dto.latitude == null || dto.longitude == null || dto.altitude == null:
				response.send(400, "Invalid location data")
				return false
			
			db.query("INSERT INTO locations (user_id, latitude, longitude, altitude) VALUES (%s, %s, %s, %s);" % [id, dto.latitude, dto.longitude, dto.altitude])
			response.send(200, "Location added successfully")
			return true
	})

func _create_route_router() -> HttpRouter:
	return HttpRouter.new("/route", {
		'post': func (request: HttpRequest, response: HttpResponse):
			var dto = JSON.parse_string(request.body)
			if dto == null || dto.destinationId == null || dto.userId == null:
				response.send(400, "Invalid route data")
				return false

			// Check if location exists
			var location = db.query("SELECT * FROM locations WHERE id = %s"%dto.destinationId)
			if location == null:
				response.send(400, "Destination location does not exist")
				return false

			// Check if the user is currently onroute to a location
			var current_route = db.query("SELECT * FROM routes WHERE user_id = %s AND destination_id != %s" % [id, dto.destinationId])
			if current_route != null:
				// If so, and its NOT the same delete the current route
				if current_route.destination_id != dto.destinationId:
					db.query("DELETE FROM routes WHERE id = %s" % current_route.id)
				else:
					// If so, and its the same, do nothing
					response.send(200, JSON.stringify(current_route))
					return true

			// Register new route
			var new_route = db.query("INSERT INTO routes (user_id, destination_id) VALUES (%s, %s);" % [id, dto.destinationId])
			response.send(200, JSON.stringify(new_route))
			return true

		'delete': func (request: HttpRequest, response: HttpResponse):
			var id = request.parameters.get("id")
			if id == null:
				response.send(400, "Invalid route id")
				return false
			
			db.query("DELETE FROM routes WHERE id = %s"%id)
			response.send(200, "Route deleted successfully")
			return true
	})

func _create_compute_image_router() -> HttpRouter:
	return HttpRouter.new("/compute-image", {
		'post': func (request: HttpRequest, response: HttpResponse):
			var dto = JSON.parse_string(request.body)
			if dto == null || dto.latitude == null || dto.longitude == null || dto.altitude == null || dto.rotation_x == null || dto.rotation_y == null || dto.rotation_z == null:
				response.send(400, "Invalid data")
				return false
			
			// 1. Check if a cached image exists for the given location and rotation
			// 2. If so, return the cached image

			var cached_image = db.query("""
				SELECT * FROM cached_generated_images 
				WHERE loc_latitude = %s AND loc_longitude = %s AND loc_altitude = %s 
				AND rotation_x = %s AND rotation_y = %s AND rotation_z = %s
			""" % [dto.latitude, dto.longitude, dto.altitude, dto.rotation_x, dto.rotation_y, dto.rotation_z])

			if cached_image != null:
				response.send(200, cached_image.blob, {"Content-Type": "image/png"}) // Any format that supports an alpha channel should work
				return true

			// 3. If not
			//		A: Place projector in the scene at the given location and rotation
			//		B: Render the scene from the projector's perspective to get the projected image
			//		C: Cache the generated image in the database for future requests
			//		D: Return the generated image

			response.send(500, "Not Implemented")
			return true
	})