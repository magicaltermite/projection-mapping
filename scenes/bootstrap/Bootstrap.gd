## Bootstrap
##
## First scene loaded on every machine. Reads two config files from user://
## and branches accordingly:
##
##   user://config.json     -> role ("server" / "client") and server IP.
##                             Written once on first launch via the role panel.
##
##   user://projector.json  -> this machine's projector position (x, y, z) and
##                             heading in degrees. Written once on first launch
##                             via the projector panel. Applies to both server
##                             and client machines since each drives one projector.
##
## Launch sequence:
##   1. If config.json missing -> show role panel -> write config.json
##   2. If projector.json missing -> show projector panel -> write projector.json
##   3. Both files present -> change scene to Server.tscn or Client.tscn
##
## Every launch ends at Calibration.tscn so the operator can verify alignment
## before going live. Calibration's "Save & Launch" button routes to the final
## scene based on SessionState.client_config["role"].
##
## To reconfigure role:      delete user://config.json and relaunch.
## To recalibrate projector: delete user://projector.json and relaunch.

extends Control

const CONFIG_PATH = "user://config.json"
const PROJECTOR_CONFIG_PATH = "user://projector.json"
const SERVER_SCENE = "res://scenes/server/Server.tscn"
const CLIENT_SCENE = "res://scenes/client/Client.tscn"
const CALIBRATION_SCENE = "res://scenes/calibration/Calibration.tscn"

var _pending_launch_config: Dictionary = {}

var _role_option: OptionButton
var _ip_row: HBoxContainer
var _ip_field: LineEdit

var _x_field: LineEdit
var _y_field: LineEdit
var _z_field: LineEdit
var _heading_field: LineEdit
var _pitch_field: LineEdit
var _roll_field: LineEdit

func _ready() -> void:
	var config = _load_json(CONFIG_PATH)
	if config.is_empty():
		_show_role_panel()
	else:
		_pending_launch_config = config
		var proj = _load_json(PROJECTOR_CONFIG_PATH)
		if proj.is_empty():
			_show_projector_panel()
		else:
			_launch(config)

# Role panel

func _show_role_panel() -> void:
	_clear_children()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.custom_minimum_size = Vector2(380, 220)
	add_child(panel)

	var margin = _make_margin(panel)
	var vbox = _make_vbox(margin)

	var title = Label.new()
	title.text = "Campus Navigation"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var role_row = HBoxContainer.new()
	vbox.add_child(role_row)
	var role_label = Label.new()
	role_label.text = "Role"
	role_label.custom_minimum_size.x = 120
	role_row.add_child(role_label)
	_role_option = OptionButton.new()
	_role_option.add_item("Server", 0)
	_role_option.add_item("Client", 1)
	_role_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role_option.item_selected.connect(_on_role_selected)
	role_row.add_child(_role_option)

	_ip_row = HBoxContainer.new()
	vbox.add_child(_ip_row)
	var ip_label = Label.new()
	ip_label.text = "Server IP"
	ip_label.custom_minimum_size.x = 120
	_ip_row.add_child(ip_label)
	_ip_field = LineEdit.new()
	_ip_field.placeholder_text = "192.168.1.x"
	_ip_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_row.add_child(_ip_field)

	vbox.add_child(HSeparator.new())

	var next_btn = Button.new()
	next_btn.text = "Next"
	next_btn.pressed.connect(_on_role_confirmed)
	vbox.add_child(next_btn)

	_on_role_selected(0)

func _on_role_selected(index: int) -> void:
	_ip_row.visible = index == 1

func _on_role_confirmed() -> void:
	if _role_option.selected == 0:
		_pending_launch_config = {"role": "server"}
	else:
		var ip = _ip_field.text.strip_edges()
		if ip.is_empty():
			return
		_pending_launch_config = {"role": "client", "server_ip": ip}
	_save_json(CONFIG_PATH, _pending_launch_config)
	_show_projector_panel()

# Projector panel

func _show_projector_panel() -> void:
	_clear_children()

	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.custom_minimum_size = Vector2(380, 280)
	add_child(panel)

	var margin = _make_margin(panel)
	var vbox = _make_vbox(margin)

	var title = Label.new()
	title.text = "Projector Setup"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var note = Label.new()
	note.text = "Measure this projector's position from the reference point in the twin."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(note)
	vbox.add_child(HSeparator.new())

	var pos_row = HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 8)
	vbox.add_child(pos_row)
	for axis in ["X", "Y", "Z"]:
		var lbl = Label.new()
		lbl.text = axis
		pos_row.add_child(lbl)
		var field = LineEdit.new()
		field.placeholder_text = "0.0"
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pos_row.add_child(field)
		match axis:
			"X": _x_field = field
			"Y": _y_field = field
			"Z": _z_field = field

	for pair in [["Heading (°)", "0.0"], ["Pitch (°)", "-55.0"], ["Roll (°)", "0.0"]]:
		var row = HBoxContainer.new()
		vbox.add_child(row)
		var lbl = Label.new()
		lbl.text = pair[0]
		lbl.custom_minimum_size.x = 120
		row.add_child(lbl)
		var field = LineEdit.new()
		field.placeholder_text = pair[1]
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(field)
		match pair[0]:
			"Heading (°)": _heading_field = field
			"Pitch (°)":   _pitch_field   = field
			"Roll (°)":    _roll_field    = field

	vbox.add_child(HSeparator.new())

	var save_btn = Button.new()
	save_btn.text = "Save & Launch"
	save_btn.pressed.connect(_on_projector_confirmed)
	vbox.add_child(save_btn)

func _on_projector_confirmed() -> void:
	var proj = {
		"x":       _x_field.text.to_float(),
		"y":       _y_field.text.to_float(),
		"z":       _z_field.text.to_float(),
		"heading": _heading_field.text.to_float(),
		"pitch":   _pitch_field.text.to_float() if not _pitch_field.text.is_empty() else -55.0,
		"roll":    _roll_field.text.to_float()  if not _roll_field.text.is_empty()  else 0.0,
	}
	_save_json(PROJECTOR_CONFIG_PATH, proj)
	# Make role available to Calibration regardless of server/client path.
	SessionState.client_config = _pending_launch_config
	get_tree().change_scene_to_file(CALIBRATION_SCENE)

# Launch

func _launch(config: Dictionary) -> void:
	SessionState.client_config = config
	get_tree().change_scene_to_file(CALIBRATION_SCENE)

# Helpers

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if not result is Dictionary:
		return {}
	return result

func _save_json(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()

func _make_margin(parent: Control) -> MarginContainer:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	parent.add_child(margin)
	return margin

func _make_vbox(parent: Control) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	parent.add_child(vbox)
	return vbox
