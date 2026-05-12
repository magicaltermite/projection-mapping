## PathRenderer
##
## Draws each active navigation path as a flat ribbon on the navmesh surface.
## UV.x = cumulative metres along the path (used by the shader for chevron scale
## and scroll speed). UV.y = 0 at the left edge, 1 at the right edge.
## One MeshInstance3D is created per path and rebuilt whenever state changes.

extends Node3D

const RIBBON_WIDTH := 0.4          # metres across
const Y_OFFSET     := Vector3(0.0, 0.03, 0.0)

var _meshes: Array[MeshInstance3D] = []
var _shader := preload("res://shaders/hologram_path.gdshader")

func _ready() -> void:
	SessionState.state_updated.connect(_on_state_updated)

func _on_state_updated() -> void:
	_clear()
	for path: PackedVector3Array in SessionState.active_paths.values():
		_draw_path(path)

func _clear() -> void:
	for node in _meshes:
		node.queue_free()
	_meshes.clear()

func _draw_path(path: PackedVector3Array) -> void:
	if path.size() < 2:
		return

	# Cumulative arc-length along the path for UV.x
	var cum := PackedFloat32Array()
	cum.append(0.0)
	for i in range(1, path.size()):
		cum.append(cum[i - 1] + path[i - 1].distance_to(path[i]))

	var mesh := ImmediateMesh.new()
	var mat  := ShaderMaterial.new()
	mat.shader = _shader

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)

	for i in range(path.size() - 1):
		var a   := path[i]     + Y_OFFSET
		var b   := path[i + 1] + Y_OFFSET
		var dir := b - a
		if dir.length_squared() < 0.0001:
			continue
		# Ribbon perpendicular lies flat on the floor (cross with world UP)
		var right := dir.normalized().cross(Vector3.UP).normalized() * (RIBBON_WIDTH * 0.5)

		var al := a - right;  var ar := a + right
		var bl := b - right;  var br := b + right
		var u0 := cum[i];     var u1 := cum[i + 1]

		# First triangle
		mesh.surface_set_uv(Vector2(u0, 0.0)); mesh.surface_add_vertex(al)
		mesh.surface_set_uv(Vector2(u0, 1.0)); mesh.surface_add_vertex(ar)
		mesh.surface_set_uv(Vector2(u1, 1.0)); mesh.surface_add_vertex(br)
		# Second triangle
		mesh.surface_set_uv(Vector2(u0, 0.0)); mesh.surface_add_vertex(al)
		mesh.surface_set_uv(Vector2(u1, 1.0)); mesh.surface_add_vertex(br)
		mesh.surface_set_uv(Vector2(u1, 0.0)); mesh.surface_add_vertex(bl)

	mesh.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_meshes.append(mi)
