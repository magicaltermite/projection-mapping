extends Node
class_name Database

var database: SQLite


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	database = SQLite.new()
	database.path = "res://data.db"
	database.open_db()
	_init_schemas(database)
	_init_data(database)

func _init_schemas(db: SQLite) -> void:
	db.query("""
	CREATE TABLE IF NOT EXISTS users(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL
	);
	""")

	db.query("""
	CREATE TABLE IF NOT EXISTS locations(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		latitude REAL NOT NULL,
		longitude REAL NOT NULL,
		altitude REAL NOT NULL,
		timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
		description TEXT
	);
	""")

	db.query("""
	CREATE TABLE IF NOT EXISTS routes(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		destination_id INTEGER NOT NULL,
		FOREIGN KEY (user_id) REFERENCES users(id),
		FOREIGN KEY (destination_id) REFERENCES locations(id)
	);
	""")


	db.query("""
	CREATE TABLE IF NOT EXISTS cached_generated_images(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		image BLOB NOT NULL,
		loc_latitude REAL NOT NULL,
		loc_longitude REAL NOT NULL,
		loc_altitude REAL NOT NULL,
		rotation_x REAL NOT NULL,
		rotation_y REAL NOT NULL,
		rotation_z REAL NOT NULL,
		timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	""")

func _init_data(db: SQLite) -> void:
	// TODO: Insert known locations, location symbols, etc.
	// Remember to "ON CONFLICT IGNORE" to avoid duplicates on every startup
	pass

func get_instance() -> SQLite:
	if database == null: 
		_ready()
	return database
