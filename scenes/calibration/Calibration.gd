## Calibration
##
## Shown after the projector panel on first launch (and whenever
## user://projector.json is deleted to force recalibration).
##
## Laptop screen: left half = live camera preview, right half = controls.
## Projector (screen 1): borderless Window showing the same camera view
## fullscreen. Falls back to the primary display if only one screen is present,
## which is useful for local testing without a projector connected.
##
## Changing any SpinBox updates the Camera3D live so the operator can see
## the projection shift on the physical surface in real time.
##
## On Save: writes corrected values to user://projector.json, closes the
## projector window, then forwards to Server.tscn or Client.tscn based on
## SessionState.client_config["role"].

extends Node

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


# ── Config ────────────────────────────────────────────────────────────────────

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


# ── Camera ────────────────────────────────────────────────────────────────────

func _apply_camera(proj: Dictionary) -> void:
	_camera.position = Vector3(
		proj.get("x", 0.0),
		proj.get("y", 0.0),
		proj.get("z", 0.0)
	)
	_camera.rotation_degrees.y = proj.get("heading", 0.0)


func _on_value_changed(_v: float) -> void:
	_camera.position = Vector3(_x_spin.value, _y_spin.value, _z_spin.value)
	_camera.rotation_degrees.y = _heading_spin.value


# ── Projector window ──────────────────────────────────────────────────────────

func _spawn_projector_window() -> void:
	_proj_window = Window.new()
	_proj_window.borderless = true
	_proj_window.always_on_top = true
	_proj_window.unfocusable = true

	var screen := 1 if DisplayServer.get_screen_count() > 1 else 0
	_proj_window.current_screen = screen
	_proj_window.position = DisplayServer.screen_get_position(screen)
	_proj_window.size = DisplayServer.screen_get_size(screen)

	get_tree().root.add_child(_proj_window)
	_proj_window.show()

	var tex_rect := TextureRect.new()
	tex_rect.texture = _viewport.get_texture()
	tex_rect.expand_mode = TextureRect.EXPAND_FILL_PARENT
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_proj_window.add_child(tex_rect)


func _cleanup_window() -> void:
	if _proj_window and is_instance_valid(_proj_window):
		_proj_window.queue_free()
		_proj_window = null


# ── Laptop UI ─────────────────────────────────────────────────────────────────

func _build_laptop_ui(proj: Dictionary) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var split := HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.split_offset = 860
	root.add_child(split)

	# Left — camera preview
	var preview := TextureRect.new()
	preview.texture = _viewport.get_texture()
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(preview)

	# Right — control panel
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Projector Calibration"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var note := Label.new()
	note.text = "Adjust until virtual building edges align with physical surfaces. Changes apply live."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(note)

	vbox.add_child(HSeparator.new())

	# SpinBoxes: [label, min, max, step, initial_value]
	var spin_defs := [
		["X (m)", -100.0, 100.0, 0.01, proj.get("x", 0.0)],
		["Y (m)", -100.0, 100.0, 0.01, proj.get("y", 0.0)],
		["Z (m)", -100.0, 100.0, 0.01, proj.get("z", 0.0)],
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

	var screen_count := DisplayServer.get_screen_count()
	var screen_note := Label.new()
	screen_note.text = "Projector output on display %d / %d" % [
		2 if screen_count > 1 else 1, screen_count
	]
	screen_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(screen_note)


func _on_save_pressed() -> void:
	_save_projector_config()
	_cleanup_window()
	var role: String = SessionState.client_config.get("role", "server")
	if role == "server":
		get_tree().change_scene_to_file(SERVER_SCENE)
	else:
		get_tree().change_scene_to_file(CLIENT_SCENE)
