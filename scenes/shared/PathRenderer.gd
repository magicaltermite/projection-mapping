## PathRenderer
##
## Drop into any scene that has a Camera3D and needs to display navigation paths.
## Connects to SessionState.state_updated and redraws all active paths each time
## state changes. Draws white ImmediateMesh lines slightly above the navmesh
## surface to avoid z-fighting with the floor mesh.

extends Node3D

const Y_OFFSET := Vector3(0.0, 0.02, 0.0)

var _segments: Array[MeshInstance3D] = []

func _ready() -> void:
	SessionState.state_updated.connect(_on_state_updated)

func _on_state_updated() -> void:
	_clear()
	for path: PackedVector3Array in SessionState.active_paths.values():
		_draw_path(path)

func _clear() -> void:
	for node in _segments:
		node.queue_free()
	_segments.clear()

func _draw_path(path: PackedVector3Array) -> void:
	for i in range(path.size() - 1):
		_add_segment(path[i] + Y_OFFSET, path[i + 1] + Y_OFFSET)

func _add_segment(from: Vector3, to: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	var mat := ORMMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_segments.append(mi)
