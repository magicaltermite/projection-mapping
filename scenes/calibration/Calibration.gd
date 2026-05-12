## Calibration
##
## Shown after the projector panel on first launch (and whenever
## user://projector.json is deleted to force recalibration).
##
## Laptop screen: left half = live camera preview, right half = controls.
## Projector (screen 1): borderless Window showing the same camera view
## fullscreen. Skipped entirely when only one display is connected — the
## left-panel preview is sufficient for single-screen testing.
##
## Changing any SpinBox updates the Camera3D live so the operator can see
## the projection shift on the physical surface in real time.
##
## On Save: writes corrected values to user://projector.json, closes the
## projector window, then forwards to Server.tscn or Client.tscn based on
## SessionState.client_config["role"].

extends Control

const PROJECTOR_CONFIG_PATH = "user://projector.json"
const SERVER_SCENE = "res://scenes/server/Server.tscn"
const CLIENT_SCENE = "res://scenes/client/Client.tscn"

@onready var _viewport: SubViewport = $CalibViewport
@onready var _camera: Camera3D = $CalibViewport/CalibCamera

var _proj_window: Window = null
var _x_spin: SpinBox
var _y_spin: SpinBox
var _z_spin: SpinBox
var _heading_spin: SpinBox


func _ready() -> void:
	var proj = _load_projector_config()
	_apply_camera(proj)
	_build_laptop_ui(proj)
	_spawn_projector_window()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_window()


# Configuration --------------------------------

func _load_projector_config() -> Dictionary:
	if not FileAccess.file_exists(PROJECTOR_CONFIG_PATH):
		return {"x": 0.0, "y": 0.0, "z": 0.0, "heading": 0.0}
	var file = FileAccess.open(PROJECTOR_CONFIG_PATH, FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if not result is Dictionary:
		return {"x": 0.0, "y": 0.0, "z": 0.0, "heading": 0.0}
	return result


func _save_projector_config() -> void:
	var data = {
		"x": _x_spin.value,
		"y": _y_spin.value,
		"z": _z_spin.value,
		"heading": _heading_spin.value
	}
	var file = FileAccess.open(PROJECTOR_CONFIG_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


# Camera --------------------------------

func _mount_pitch() -> float:
	var role: String = SessionState.client_config.get("role", "server")
	return -56.0 if role == "server" else -52.0

func _apply_camera(proj: Dictionary) -> void:
	_camera.position = Vector3(
		proj.get("x", 0.0),
		proj.get("y", 0.0),
		proj.get("z", 0.0)
	)
	_camera.rotation_degrees = Vector3(_mount_pitch(), proj.get("heading", 0.0), 0.0)


func _on_value_changed(_v: float) -> void:
	_camera.position = Vector3(_x_spin.value, _y_spin.value, _z_spin.value)
	_camera.rotation_degrees = Vector3(_mount_pitch(), _heading_spin.value, 0.0)


# Projector window --------------------------------

func _spawn_projector_window() -> void:
	var screen_count := DisplayServer.get_screen_count()
	print("[Calibration] Screens detected: %d" % screen_count)
	for i in screen_count:
		print("  screen %d: size=%s pos=%s" % [i, DisplayServer.screen_get_size(i), DisplayServer.screen_get_position(i)])
	# In the editor the projector is never connected — skip to keep the desktop clean.
	if OS.has_feature("editor"):
		print("[Calibration] Running in editor — skipping projector window")
		return
	if screen_count < 2:
		print("[Calibration] Single display — skipping projector window")
		return
	# The projector is always plugged in last, so it appears as the highest screen index.
	var proj_screen := screen_count - 1
	print("[Calibration] Projector on screen %d" % proj_screen)
	_proj_window = Window.new()
	_proj_window.unfocusable = true
	_proj_window.current_screen = proj_screen
	_proj_window.mode = Window.MODE_FULLSCREEN

	get_tree().root.add_child(_proj_window)
	_proj_window.show()

	var tex_rect := TextureRect.new()
	tex_rect.texture = _viewport.get_texture()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_proj_window.add_child(tex_rect)


func _cleanup_window() -> void:
	if _proj_window and is_instance_valid(_proj_window):
		_proj_window.queue_free()
		_proj_window = null


# Backend UI --------------------------------

func _build_laptop_ui(proj: Dictionary) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)

	var vp := get_viewport().get_visible_rect().size
	var split_x := int(vp.x * 0.55)

	# Left -> camera preview
	var preview := TextureRect.new()
	preview.position = Vector2.ZERO
	preview.size = Vector2(split_x, vp.y)
	preview.texture = _viewport.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	canvas.add_child(preview)

	# Right -> control panel
	var panel_w := vp.x - split_x
	var panel := Panel.new()
	panel.position = Vector2(split_x, 0)
	panel.size = Vector2(panel_w, vp.y)
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.12, 0.14, 0.2)
	panel.add_theme_stylebox_override("panel", panel_bg)
	canvas.add_child(panel)

	var margin := MarginContainer.new()
	margin.position = Vector2(24, 24)
	margin.size = Vector2(panel_w - 48, vp.y - 48)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Projector Calibration"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var note := Label.new()
	note.text = "Adjust until virtual building edges align with physical surfaces. Changes apply live."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(note)

	vbox.add_child(HSeparator.new())

	var spin_defs := [
		["X (m)",       -100.0, 100.0, 0.01, proj.get("x",       0.0)],
		["Y (m)",       -100.0, 100.0, 0.01, proj.get("y",       0.0)],
		["Z (m)",       -100.0, 100.0, 0.01, proj.get("z",       0.0)],
		["Heading (°)", -180.0, 180.0, 0.5,  proj.get("heading", 0.0)],
	]
	var spins: Array[SpinBox] = []
	for def in spin_defs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)
		var lbl := Label.new()
		lbl.text = def[0]
		lbl.custom_minimum_size.x = 110
		lbl.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(lbl)
		var spin := SpinBox.new()
		spin.min_value = def[1]
		spin.max_value = def[2]
		spin.step = def[3]
		spin.value = def[4]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(_on_value_changed)
		row.add_child(spin)
		spins.append(spin)

	_x_spin = spins[0]
	_y_spin = spins[1]
	_z_spin = spins[2]
	_heading_spin = spins[3]

	vbox.add_child(HSeparator.new())

	var save_btn := Button.new()
	save_btn.text = "Save & Launch"
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)


func _on_save_pressed() -> void:
	_save_projector_config()
	_cleanup_window()
	var role: String = SessionState.client_config.get("role", "server")
	if role == "server":
		get_tree().change_scene_to_file(SERVER_SCENE)
	else:
		get_tree().change_scene_to_file(CLIENT_SCENE)
