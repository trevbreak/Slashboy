class_name MeshBuilder
extends RefCounted
## Accumulates static level geometry into one mesh per (16 m chunk, material, shadow flag):
## a few dozen draw calls for the whole station, with frustum culling still effective.

const CHUNK := 16.0
const FRONT_CLOCKWISE := true   # Godot treats clockwise winding as front-facing

var tools := {}     # key -> {st: SurfaceTool, mat: Material, cast: bool}
var count := 0


func _tool(center: Vector3, mat: Material, cast: bool) -> SurfaceTool:
	var key := "%d,%d|%d|%s" % [floori(center.x / CHUNK), floori(center.z / CHUNK), mat.get_instance_id(), cast]
	if not tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = {"st": st, "mat": mat, "cast": cast}
	return tools[key].st


func _quad(st: SurfaceTool, p: Array, n: Vector3, uv: Array) -> void:
	var ccw = (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0
	var order := [0, 2, 1, 0, 3, 2] if (ccw == FRONT_CLOCKWISE) else [0, 1, 2, 0, 2, 3]
	for i in order:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])


## Axis-aligned box with world-space UVs (uv_scale metres per texture repeat).
func box(a: Vector3, b: Vector3, mat: Material, uv_scale := 3.0, cast := true) -> void:
	var st := _tool((a + b) * 0.5, mat, cast)
	var s := 1.0 / uv_scale
	var U := func(x: float, y: float) -> Vector2: return Vector2(x * s, y * s)
	# +X / -X
	_quad(st, [Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(b.x, b.y, a.z)], Vector3.RIGHT,
		[U.call(-a.z, -a.y), U.call(-b.z, -a.y), U.call(-b.z, -b.y), U.call(-a.z, -b.y)])
	_quad(st, [Vector3(a.x, a.y, a.z), Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, b.z), Vector3(a.x, b.y, a.z)], Vector3.LEFT,
		[U.call(a.z, -a.y), U.call(b.z, -a.y), U.call(b.z, -b.y), U.call(a.z, -b.y)])
	# +Y / -Y
	_quad(st, [Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)], Vector3.UP,
		[U.call(a.x, a.z), U.call(b.x, a.z), U.call(b.x, b.z), U.call(a.x, b.z)])
	_quad(st, [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)], Vector3.DOWN,
		[U.call(a.x, -a.z), U.call(b.x, -a.z), U.call(b.x, -b.z), U.call(a.x, -b.z)])
	# +Z / -Z
	_quad(st, [Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)], Vector3.BACK,
		[U.call(a.x, -a.y), U.call(b.x, -a.y), U.call(b.x, -b.y), U.call(a.x, -b.y)])
	_quad(st, [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z)], Vector3.FORWARD,
		[U.call(-a.x, -a.y), U.call(-b.x, -a.y), U.call(-b.x, -b.y), U.call(-a.x, -b.y)])
	count += 1


## Merge an arbitrary primitive mesh (cylinders, tubes, branches...) into the static set.
func mesh(m: Mesh, xform: Transform3D, mat: Material, cast := true) -> void:
	var st := _tool(xform.origin, mat, cast)
	st.append_from(m, 0, xform)
	count += 1


func commit(parent: Node3D) -> int:
	var calls := 0
	for key in tools:
		var t: Dictionary = tools[key]
		var st: SurfaceTool = t.st
		st.index()
		st.generate_tangents()
		var arr := st.commit()
		var mi := MeshInstance3D.new()
		mi.mesh = arr
		mi.material_override = t.mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if t.cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		calls += 1
	tools.clear()
	return calls
