class_name Katana
extends Node
## First-person katana: rendered in its own SubViewport world so it never clips into walls.
## Poses use the same YXZ euler convention as Godot's Node3D (camera space, -Z forward).

const POSE := {
	"rest": [Vector3(0.27, -0.30, -0.50), Vector3(-1.0, 0.3, 0.2), -0.5],
	"s0a": [Vector3(0.44, -0.08, -0.42), Vector3(-1.05, -1.25, 0), 0.0],
	"s0b": [Vector3(-0.32, -0.32, -0.48), Vector3(-1.85, 1.3, 0), 0.0],
	"s1a": [Vector3(-0.32, -0.30, -0.42), Vector3(-1.9, 1.25, 0), PI],
	"s1b": [Vector3(0.42, -0.06, -0.48), Vector3(-1.15, -1.3, 0), PI],
	"s2a": [Vector3(0.15, 0.14, -0.32), Vector3(0.4, 0.05, 0), -PI / 2],
	"s2b": [Vector3(0.02, -0.46, -0.5), Vector3(-2.3, 0.05, 0), -PI / 2],
	"wavea": [Vector3(0.52, -0.15, -0.34), Vector3(-1.45, -1.6, 0), 0.0],
	"waveb": [Vector3(-0.46, -0.2, -0.44), Vector3(-1.45, 1.6, 0), 0.0],
	"charge": [Vector3(0.44, -0.22, -0.30), Vector3(-1.3, -1.45, 0), 0.0],
	"guard": [Vector3(0.16, -0.17, -0.46), Vector3(-0.15, 0, 1.45), -PI / 2],
	"dash": [Vector3(0.38, -0.42, -0.42), Vector3(-1.25, 0.35, 0.5), -0.3],
	"scan": [Vector3(0.36, -0.55, -0.45), Vector3(-0.4, 0.2, 0.5), -0.4],
}
const BLADE_LEN := 0.95
const TRAIL_N := 16

var viewport: SubViewport
var rect: TextureRect
var cam: Camera3D
var outer: Node3D
var inner: Node3D
var edge_mat: ShaderMaterial
var vm_light: OmniLight3D
var trail: MeshInstance3D
var trail_mesh: ImmediateMesh
var trail_base: Array[Vector3] = []
var trail_tip: Array[Vector3] = []
var trail_color := Color(0.15, 0.8, 1.05)
var flow_t := 0.0
var pose := {"p": Vector3(), "r": Vector3(), "tw": 0.0}


func build(layer: CanvasLayer) -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	rect = TextureRect.new()
	rect.texture = viewport.get_texture()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(rect)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.55, 0.65, 0.8)
	psm.sky_horizon_color = Color(0.35, 0.38, 0.45)
	psm.sky_energy_multiplier = 1.5
	psm.ground_bottom_color = Color(0.02, 0.02, 0.03)
	psm.ground_horizon_color = Color(0.08, 0.09, 0.12)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	cam = Camera3D.new()
	cam.fov = 55
	cam.near = 0.01
	cam.far = 10
	viewport.add_child(cam)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.75, 0.85, 1.0)
	key.light_energy = 1.4
	key.rotation = Vector3(-0.9, -0.5, 0)
	viewport.add_child(key)
	vm_light = OmniLight3D.new()
	vm_light.light_color = Color(0.5, 0.91, 1.0)
	vm_light.light_energy = 0.3
	vm_light.omni_range = 1.4
	vm_light.position = Vector3(0.1, -0.1, -0.3)
	viewport.add_child(vm_light)
	_build_model()
	_build_trail()
	set_pose(POSE.rest)


func resize(size: Vector2i) -> void:
	# cap the viewmodel buffer near 1600px wide; it's upscaled by the TextureRect
	var k: float = min(1.0, 1700.0 / max(1.0, float(size.x)))
	viewport.size = Vector2i(int(size.x * k), int(size.y * k))


func _build_model() -> void:
	outer = Node3D.new()
	outer.rotation_order = EULER_ORDER_YXZ
	outer.scale = Vector3.ONE * 0.62
	cam.add_child(outer)
	inner = Node3D.new()
	outer.add_child(inner)
	# blade: diamond cross-section, curved (sori), tapered, with a polished hamon texture
	var steel := StandardMaterial3D.new()
	steel.albedo_texture = load("res://assets/textures/blade_albedo.png")
	steel.albedo_color = Color(0.85, 0.88, 0.92)
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	steel.roughness_texture = load("res://assets/textures/blade_rough.png")
	steel.metallic = 1.0
	steel.roughness = 0.4
	steel.clearcoat_enabled = true
	steel.clearcoat = 0.5
	steel.clearcoat_roughness = 0.1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N := 32
	var rows: Array = []
	for i in N + 1:
		var t := float(i) / N
		var w := 0.03 * (1.0 - 0.25 * t)
		var th := 0.0035 * (1.0 - 0.5 * t)
		var off := 0.035 * t * t
		var y := 0.1 + t * BLADE_LEN
		var tip = clamp((t - 0.92) / 0.08, 0.0, 1.0)
		var edge_x = -w / 2 + w * tip * tip * 0.9
		var spine_x := w / 2
		var ridge_x := w * 0.12
		rows.append({"t": t, "y": y, "spine": spine_x + off, "ridge": ridge_x + off, "edge": edge_x + off, "th": th * (1.0 - tip * 0.8), "w": w})
	for i in N:
		var a: Dictionary = rows[i]; var b: Dictionary = rows[i + 1]
		for side in [1.0, -1.0]:
			# edge -> ridge (bevel) and ridge -> spine (flat), both faces
			var pts := [
				[Vector3(a.edge, a.y, 0), Vector3(a.ridge, a.y, a.th * side), Vector3(b.ridge, b.y, b.th * side), Vector3(b.edge, b.y, 0)],
				[Vector3(a.ridge, a.y, a.th * side), Vector3(a.spine, a.y, a.th * side * 0.8), Vector3(b.spine, b.y, b.th * side * 0.8), Vector3(b.ridge, b.y, b.th * side)],
			]
			for q in pts:
				var order := [0, 1, 2, 0, 2, 3] if side < 0 else [0, 2, 1, 0, 3, 2]
				for k in order:
					var p: Vector3 = q[k]
					var ww: float = a.w if k < 2 else b.w
					st.set_uv(Vector2(clamp((p.x - (a.edge if k < 2 else b.edge)) / max(ww, 0.001), 0.0, 1.0), a.t if k < 2 else b.t))
					st.add_vertex(p)
		# spine face
		var sq := [Vector3(a.spine, a.y, a.th * 0.8), Vector3(a.spine, a.y, -a.th * 0.8), Vector3(b.spine, b.y, -b.th * 0.8), Vector3(b.spine, b.y, b.th * 0.8)]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_uv(Vector2(1, a.t))
			st.add_vertex(sq[k])
	st.generate_normals()
	var blade := MeshInstance3D.new()
	blade.mesh = st.commit()
	blade.material_override = steel
	inner.add_child(blade)
	# energy edge: thin strip along the cutting edge
	edge_mat = ShaderMaterial.new()
	edge_mat.shader = preload("res://shaders/energy_edge.gdshader")
	var es := SurfaceTool.new()
	es.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in N - 2:
		var a: Dictionary = rows[i]; var b: Dictionary = rows[i + 1]
		var q := [Vector3(a.edge - 0.002, a.y, 0.0012), Vector3(a.edge - 0.002, a.y, -0.0012), Vector3(b.edge - 0.002, b.y, -0.0012), Vector3(b.edge - 0.002, b.y, 0.0012)]
		var q2 := [Vector3(a.edge - 0.004, a.y, 0), Vector3(a.edge + 0.003, a.y, 0), Vector3(b.edge + 0.003, b.y, 0), Vector3(b.edge - 0.004, b.y, 0)]
		for quad in [q, q2]:
			for k in [0, 1, 2, 0, 2, 3]:
				es.set_uv(Vector2(0, a.t if k < 2 else b.t))
				es.add_vertex(quad[k])
	var edge := MeshInstance3D.new()
	edge.mesh = es.commit()
	edge.material_override = edge_mat
	edge_mat.set_shader_parameter("color", Color(0.3, 1.6, 2.1))
	inner.add_child(edge)
	# fittings
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.35, 0.29, 0.17); gold.metallic = 0.9; gold.roughness = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.09, 0.11); dark.roughness = 0.7; dark.metallic = 0.3
	var tsuba := Node3D.new(); tsuba.position.y = 0.075; inner.add_child(tsuba)
	var ring := TorusMesh.new(); ring.inner_radius = 0.042; ring.outer_radius = 0.058; ring.rings = 24; ring.ring_segments = 6
	_mi(ring, gold, Vector3.ZERO, tsuba)
	var disc := CylinderMesh.new(); disc.top_radius = 0.03; disc.bottom_radius = 0.03; disc.height = 0.012
	_mi(disc, gold, Vector3.ZERO, tsuba)
	for i in 6:
		var a := i * PI / 3
		var sp := BoxMesh.new(); sp.size = Vector3(0.03, 0.008, 0.006)
		_mi(sp, gold, Vector3(cos(a) * 0.036, 0, sin(a) * 0.036), tsuba).rotation.y = -a
	var inlay := TorusMesh.new(); inlay.inner_radius = 0.0395; inlay.outer_radius = 0.0445; inlay.rings = 24; inlay.ring_segments = 4
	var inlay_mat := StandardMaterial3D.new()
	inlay_mat.albedo_color = Color.BLACK; inlay_mat.emission_enabled = true; inlay_mat.emission = Color(0.15, 0.8, 1.0); inlay_mat.emission_energy_multiplier = 1.8
	_mi(inlay, inlay_mat, Vector3(0, 0.007, 0), tsuba)
	var hab := BoxMesh.new(); hab.size = Vector3(0.034, 0.025, 0.012)
	_mi(hab, gold, Vector3(0, 0.095, 0), inner)
	var handle := CylinderMesh.new(); handle.top_radius = 0.017; handle.bottom_radius = 0.019; handle.height = 0.27
	_mi(handle, dark, Vector3(0, -0.065, 0), inner)
	var wrap_mat := StandardMaterial3D.new(); wrap_mat.albedo_color = Color(0.05, 0.16, 0.2); wrap_mat.roughness = 0.8
	for i in 7:
		var w := TorusMesh.new(); w.inner_radius = 0.0155; w.outer_radius = 0.0235; w.rings = 10; w.ring_segments = 4
		_mi(w, wrap_mat, Vector3(0, -0.18 + i * 0.035, 0), inner)
	var pommel := CylinderMesh.new(); pommel.top_radius = 0.022; pommel.bottom_radius = 0.02; pommel.height = 0.025
	_mi(pommel, gold, Vector3(0, -0.21, 0), inner)
	# armoured glove + forearm (on outer, so it doesn't twist with the blade)
	var armor := StandardMaterial3D.new(); armor.albedo_color = Color(0.1, 0.11, 0.14); armor.roughness = 0.45; armor.metallic = 0.6
	var hand := BoxMesh.new(); hand.size = Vector3(0.06, 0.1, 0.05)
	_mi(hand, armor, Vector3(0.026, -0.03, 0.012), outer)
	for i in 4:
		var f := TorusMesh.new(); f.inner_radius = 0.0145; f.outer_radius = 0.0335; f.rings = 10; f.ring_segments = 6
		var fm := _mi(f, armor, Vector3(0.0, -0.075 + i * 0.024, 0.0), outer)
		fm.scale = Vector3(1, 0.6, 1)
	var plate := BoxMesh.new(); plate.size = Vector3(0.05, 0.085, 0.012)
	_mi(plate, armor, Vector3(0.05, -0.03, 0.012), outer).rotation.y = 0.3
	var glowmat := StandardMaterial3D.new(); glowmat.albedo_color = Color.BLACK; glowmat.emission_enabled = true; glowmat.emission = Color(0.2, 1.3, 1.7); glowmat.emission_energy_multiplier = 1.4
	var knuck := BoxMesh.new(); knuck.size = Vector3(0.074, 0.02, 0.02)
	_mi(knuck, glowmat, Vector3(0.006, -0.02, -0.04), outer)
	var fore := CylinderMesh.new(); fore.top_radius = 0.04; fore.bottom_radius = 0.05; fore.height = 0.42
	_mi(fore, armor, Vector3(0.02, -0.2, 0.15), outer).rotation.x = 0.85
	var cuff := CylinderMesh.new(); cuff.top_radius = 0.052; cuff.bottom_radius = 0.052; cuff.height = 0.03
	_mi(cuff, glowmat, Vector3(0.02, -0.1, 0.06), outer).rotation.x = 0.85


func _mi(m: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_trail() -> void:
	trail_mesh = ImmediateMesh.new()
	trail = MeshInstance3D.new()
	trail.mesh = trail_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.material_override = m
	cam.add_child(trail)


func set_pose(p: Array) -> void:
	pose.p = p[0]; pose.r = p[1]; pose.tw = p[2]


static func mix_pose(a: Dictionary, b: Array, k: float) -> Dictionary:
	return {"p": a.p.lerp(b[0], k), "r": a.r.lerp(b[1], k), "tw": lerp(a.tw, b[2], k)}


static func mix_poses(a: Array, b: Array, k: float) -> Dictionary:
	return {"p": a[0].lerp(b[0], k), "r": a[1].lerp(b[1], k), "tw": lerp(a[2], b[2], k)}


func apply(p: Dictionary, sway: Vector2, bob: float, bob_t: float, land_dip: float, jitter: float) -> void:
	outer.position = p.p + Vector3(-sway.x * 0.00025 + cos(bob_t) * 0.008 * bob + (randf() - 0.5) * jitter,
		sway.y * 0.00025 + abs(sin(bob_t)) * 0.01 * bob - land_dip * 0.3 + (randf() - 0.5) * jitter, 0)
	outer.rotation = p.r
	inner.rotation.y = p.tw


func update_trail(active: bool) -> void:
	if active:
		var xf := inner.global_transform
		trail_base.push_front(cam.global_transform.affine_inverse() * (xf * Vector3(0.0, 0.14, 0)))
		trail_tip.push_front(cam.global_transform.affine_inverse() * (xf * Vector3(0.035, 0.1 + BLADE_LEN, 0)))
	elif not trail_base.is_empty():
		trail_base.pop_back(); trail_tip.pop_back()
	while trail_base.size() > TRAIL_N:
		trail_base.pop_back(); trail_tip.pop_back()
	trail_mesh.clear_surfaces()
	var n := trail_base.size()
	if n < 2:
		return
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var b := trail_base[i]; var t := trail_tip[i]
		var a := pow(1.0 - float(i) / TRAIL_N, 1.6) * 0.45
		trail_mesh.surface_set_color(Color(0, 0, 0, 0))
		trail_mesh.surface_add_vertex(b.lerp(t, 0.6))
		trail_mesh.surface_set_color(Color(trail_color.r * a, trail_color.g * a, trail_color.b * a, a))
		trail_mesh.surface_add_vertex(t)
	trail_mesh.surface_end()


func set_glow(col: Color, light: float, dt: float) -> void:
	edge_mat.set_shader_parameter("color", col)
	flow_t += dt
	edge_mat.set_shader_parameter("flow_t", flow_t)
	vm_light.light_energy = light
	trail_color = col * 0.5
