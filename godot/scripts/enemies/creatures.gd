class_name Creatures
extends RefCounted
## Creature art: organic noise-displaced meshes, shader materials (iridescent chitin, veined
## flesh, refractive cloak, iris), and the three model builders.

const TEX := "res://assets/textures/"
static var _tex := {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(TEX + name + ".png")
	return _tex[name]


## Displace a primitive mesh along its normals with fractal noise: lumpy, organic silhouettes.
static func organic(mesh: PrimitiveMesh, amp := 0.05, freq := 3.0, seed := 0) -> ArrayMesh:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq * 0.25
	n.fractal_octaves = 2
	for i in verts.size():
		verts[i] += norms[i] * n.get_noise_3dv(verts[i] * 4.0) * amp * 2.0
	arrays[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func sphere(r: float, seg := 32, rings := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r; s.height = r * 2; s.radial_segments = seg; s.rings = rings
	return s


static func cone(r: float, h: float, seg := 6) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0; c.bottom_radius = r; c.height = h; c.radial_segments = seg; c.rings = 1
	return c


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r; c.height = h + r * 2; c.radial_segments = 10; c.rings = 4
	return c


## Tapered limb segment lying along +X from the origin.
static func limb(length: float, r0: float, r1: float, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r1; cm.bottom_radius = r0; cm.height = length; cm.radial_segments = 8; cm.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.rotation.z = -PI / 2
	mi.position.x = length / 2
	return mi


static func add(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ materials (one set per enemy, for hit flash)
static func chitin() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/chitin.gdshader")
	m.set_shader_parameter("albedo_tex", tex("chitin_albedo"))
	m.set_shader_parameter("normal_tex", tex("chitin_normal"))
	m.set_shader_parameter("orm_tex", tex("chitin_orm"))
	return m


static func flesh(vein := Color(0.7, 0.3, 1.0), strength := 2.6, tint := Color(0.75, 0.35, 0.8)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/veins.gdshader")
	m.set_shader_parameter("albedo_tex", tex("flesh_albedo"))
	m.set_shader_parameter("normal_tex", tex("flesh_normal"))
	m.set_shader_parameter("orm_tex", tex("flesh_orm"))
	m.set_shader_parameter("vein_color", vein)
	m.set_shader_parameter("vein_strength", strength)
	m.set_shader_parameter("tint", tint)
	return m


static func stalker_body() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/veins.gdshader")
	m.set_shader_parameter("albedo_tex", tex("stalker_albedo"))
	m.set_shader_parameter("normal_tex", tex("stalker_normal"))
	m.set_shader_parameter("orm_tex", tex("stalker_orm"))
	m.set_shader_parameter("tint", Color(0.55, 0.5, 0.7))
	m.set_shader_parameter("vein_color", Color(0.85, 0.75, 1.0))
	m.set_shader_parameter("vein_strength", 1.4)
	m.set_shader_parameter("vein_freq", 4.5)
	m.set_shader_parameter("pulse_speed", 1.4)
	m.set_shader_parameter("rim_color", Color(0.6, 0.5, 1.0))
	m.set_shader_parameter("rim", 0.25)
	m.set_shader_parameter("roughness", 0.55)
	m.set_shader_parameter("metallic", 0.35)
	m.set_shader_parameter("clearcoat", 1.0)
	return m


static func cloak() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/cloak.gdshader")
	return m


static func mech(col := Color(0.55, 0.58, 0.63)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("mech_albedo")
	m.albedo_color = col
	m.normal_enabled = true
	m.normal_texture = tex("mech_normal")
	var orm := tex("mech_orm")
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = orm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic = 1.0
	m.roughness = 0.9
	m.uv1_scale = Vector3(2, 2, 1)
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.0
	return m


static func emissive(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func glow_quad(c: Color, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2.ONE
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/glow_add.gdshader")
	m.set_shader_parameter("tex", tex("glow"))
	m.set_shader_parameter("color", c)
	mi.material_override = m
	mi.scale = Vector3.ONE * size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------ Crawler
static func build_crawler(e) -> Node3D:
	var chit := chitin()
	var fl := flesh()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.04, 0.06); dark.roughness = 0.3; dark.metallic = 0.5
	dark.clearcoat_enabled = true
	dark.emission_enabled = true; dark.emission = Color.WHITE; dark.emission_energy_multiplier = 0.0
	e.flash_mats = [chit, fl, dark]
	var body := Node3D.new()
	add(body, organic(sphere(0.34, 40, 24), 0.08, 4, 1), chit, Vector3.ZERO, Vector3(1, 0.62, 1.2))
	for i in 5:
		var plate := SphereMesh.new()
		plate.radius = 0.38 - i * 0.02; plate.height = plate.radius; plate.is_hemisphere = true; plate.radial_segments = 28; plate.rings = 8
		add(body, plate, chit, Vector3(0, 0.08 + sin(i * 0.8) * 0.03, -0.2 + i * 0.22), Vector3(1.08, 0.7, 0.75), Vector3(-0.25 + i * 0.12, 0, 0))
	e.abdomen = add(body, organic(sphere(0.44, 40, 24), 0.1, 3.5, 7), fl, Vector3(0, 0.1, 0.72), Vector3(1.05, 0.8, 1.35))
	for i in 7:
		var k := sin(i / 6.0 * PI)
		add(body, cone(0.03, 0.22 + k * 0.18, 5), dark, Vector3(0, 0.22 + k * 0.06, -0.25 + i * 0.16), Vector3.ONE, Vector3(0.7, 0, 0))
	var head := Node3D.new(); head.position = Vector3(0, 0.04, -0.46); body.add_child(head)
	e.head = head
	add(head, organic(sphere(0.21, 32, 18), 0.05, 6, 3), chit, Vector3.ZERO, Vector3(1.15, 0.8, 1.4))
	e.eye_mat = emissive(Color(1.0, 0.05, 0.03), 2.2)
	for p in [[-0.07, 0.07, -0.25, 0.034], [0.07, 0.07, -0.25, 0.034], [-0.13, 0.03, -0.2, 0.025], [0.13, 0.03, -0.2, 0.025], [-0.04, 0.12, -0.2, 0.018], [0.04, 0.12, -0.2, 0.018]]:
		add(head, sphere(p[3], 10, 6), e.eye_mat, Vector3(p[0], p[1], p[2]))
	e.eye_glow = glow_quad(Color(0.7, 0.05, 0.03), 0.22)
	e.eye_glow.position = Vector3(0, 0.07, -0.3)
	head.add_child(e.eye_glow)
	e.mandibles = []
	for s in [-1, 1]:
		var m := Node3D.new(); m.position = Vector3(s * 0.08, -0.06, -0.24); head.add_child(m)
		add(m, cone(0.04, 0.2, 6), dark, Vector3(0, 0, -0.08), Vector3.ONE, Vector3(-PI / 2, 0, 0))
		add(m, cone(0.022, 0.16, 5), dark, Vector3(-s * 0.04, 0, -0.2), Vector3.ONE, Vector3(-PI / 2, 0, -s * 0.9))
		e.mandibles.append(m)
	e.feelers = []
	for s in [-1, 1]:
		var parent: Node3D = head
		var chain: Array = []
		for i in 5:
			var seg := Node3D.new()
			seg.position = Vector3(s * 0.07 if i == 0 else 0.0, 0.14 if i == 0 else 0.13, -0.15 if i == 0 else 0.0)
			if i == 0:
				seg.rotation = Vector3(-0.9, s * 0.4, 0)
			var rod := CylinderMesh.new(); rod.top_radius = 0.006 * (1 - i * 0.15); rod.bottom_radius = 0.008 * (1 - i * 0.15); rod.height = 0.13; rod.radial_segments = 4
			add(seg, rod, dark, Vector3(0, 0.065, 0))
			parent.add_child(seg)
			chain.append(seg)
			parent = seg
		e.feelers.append({"chain": chain, "s": s})
	var leg_mats := {"limb": chit, "joint": dark, "claw": dark}
	e.legs = []
	var idx := 0
	for s in [-1, 1]:
		for z in [-0.3, 0.02, 0.32]:
			var group := 0 if idx in [0, 4, 2] else 1
			e.legs.append(IKLeg.new(body, Vector3(s * 0.24, 0, z), Vector3(s * 0.95, -0.55, z * 1.9 - 0.05), 0.55, 0.72, leg_mats, 0.05, group))
			idx += 1
	body.position.y = 0.55
	return body


# ------------------------------------------------------------------ Sentinel
static func build_sentinel(e) -> Node3D:
	var shell := mech(Color(0.62, 0.66, 0.72))
	var dark := mech(Color(0.2, 0.22, 0.26))
	e.flash_mats = [shell, dark]
	var g := Node3D.new()
	add(g, sphere(0.4, 32, 16), dark)
	e.petals = []
	e.trim_mat = emissive(Color(0.15, 0.75, 1.0), 2.0)
	for i in 4:
		var pivot := Node3D.new()
		g.add_child(pivot)
		var a := i * PI / 2 + PI / 4
		pivot.set_meta("dir", Vector3(cos(a), sin(a), 0))
		# a quarter shell: hemisphere scaled flat, rotated around the forward axis
		var hemi := SphereMesh.new(); hemi.radius = 0.58; hemi.height = 0.58; hemi.is_hemisphere = true; hemi.radial_segments = 24; hemi.rings = 8
		var petal := add(pivot, hemi, shell, Vector3.ZERO, Vector3(0.62, 1.0, 1.0), Vector3(0, 0, -PI / 2 + a))
		petal.position = Vector3(cos(a), sin(a), 0) * 0.02
		var trim := TorusMesh.new(); trim.inner_radius = 0.575; trim.outer_radius = 0.59; trim.rings = 24; trim.ring_segments = 4
		add(pivot, trim, e.trim_mat, Vector3(0, 0, -0.12), Vector3(0.62, 1, 0.62), Vector3(PI / 2, 0, a))
		e.petals.append(pivot)
	var iris_mat := ShaderMaterial.new()
	iris_mat.shader = preload("res://shaders/iris.gdshader")
	e.iris_mat = iris_mat
	var q := QuadMesh.new(); q.size = Vector2(0.4, 0.4)
	add(g, q, iris_mat, Vector3(0, 0, -0.405), Vector3.ONE, Vector3(0, PI, 0))
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(0.53, 0.67, 0.8, 0.22)
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens.roughness = 0.02
	lens.clearcoat_enabled = true
	var lm := SphereMesh.new(); lm.radius = 0.22; lm.height = 0.22; lm.is_hemisphere = true
	add(g, lm, lens, Vector3(0, 0, -0.38), Vector3.ONE, Vector3(-PI / 2, 0, 0))
	e.eye_glow = glow_quad(Color(0.15, 0.7, 1.0), 0.55)
	e.eye_glow.position = Vector3(0, 0, -0.55)
	g.add_child(e.eye_glow)
	e.ring_light_mat = emissive(Color(1.0, 0.2, 0.12), 1.2)
	e.rings = []
	for cfg in [[0.86, 0.0], [0.98, PI / 2]]:
		var holder := Node3D.new(); g.add_child(holder)
		var ring := Node3D.new(); ring.rotation.y = cfg[1]; holder.add_child(ring)
		var tm := TorusMesh.new(); tm.inner_radius = cfg[0] - 0.03; tm.outer_radius = cfg[0] + 0.03; tm.rings = 48; tm.ring_segments = 8
		add(ring, tm, dark, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
		for i in 8:
			var a := i * PI / 4
			var bm := BoxMesh.new(); bm.size = Vector3(0.07, 0.07, 0.1)
			add(ring, bm, shell if i % 2 else e.ring_light_mat, Vector3(cos(a) * cfg[0], sin(a) * cfg[0], 0), Vector3.ONE, Vector3(0, 0, a))
		e.rings.append({"holder": holder, "ring": ring})
	var back := CylinderMesh.new(); back.top_radius = 0.16; back.bottom_radius = 0.24; back.height = 0.25
	add(g, back, dark, Vector3(0, 0, 0.45), Vector3.ONE, Vector3(PI / 2, 0, 0))
	e.blink_mat = emissive(Color(1, 0.07, 0.07), 3.0)
	for s in [-1, 1]:
		var ant := CylinderMesh.new(); ant.top_radius = 0.008; ant.bottom_radius = 0.012; ant.height = 0.55; ant.radial_segments = 4
		add(g, ant, dark, Vector3(s * 0.12, 0.38, 0.38), Vector3.ONE, Vector3(0.5, 0, -s * 0.25))
		add(g, sphere(0.022, 6, 4), e.blink_mat, Vector3(s * 0.19, 0.62, 0.52))
	var thr := CylinderMesh.new(); thr.top_radius = 0.12; thr.bottom_radius = 0.08; thr.height = 0.14
	add(g, thr, dark, Vector3(0, -0.48, 0))
	e.thruster_glow = glow_quad(Color(0.3, 0.9, 2.2), 0.7)
	e.thruster_glow.position = Vector3(0, -0.62, 0)
	g.add_child(e.thruster_glow)
	return g


# ------------------------------------------------------------------ Stalker
static func build_stalker(e) -> Node3D:
	var body_mat := stalker_body()
	e.body_mat = body_mat
	e.cloak_mat = cloak()
	e.flash_mats = [body_mat]
	e.parts = []
	var P := func(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
		var mi := add(parent, mesh, body_mat, pos, scl, rot)
		e.parts.append(mi)
		return mi
	var root := Node3D.new()
	var hips := Node3D.new(); hips.position.y = 1.3; root.add_child(hips)
	e.hips = hips
	P.call(hips, organic(sphere(0.19, 20, 12), 0.06, 5, 2), Vector3.ZERO, Vector3.ZERO, Vector3(1.3, 0.8, 0.9))
	var torso := Node3D.new(); torso.position.y = 0.1; torso.rotation.x = -0.35; hips.add_child(torso)
	e.torso = torso
	# lathe torso: pinched waist flaring to a broad chest
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof: Array = []
	for i in 17:
		var t := i / 16.0
		var r = 0.09 + sin(t * PI * 0.95) * 0.17 + max(0.0, t - 0.55) * 0.18 - max(0.0, t - 0.9) * 1.2
		prof.append(Vector2(max(0.02, r), t * 1.15))
	var SEG := 24
	for i in 16:
		for j in SEG:
			var a0 := TAU * j / SEG; var a1 := TAU * (j + 1) / SEG
			var p := [
				Vector3(cos(a0) * prof[i].x, prof[i].y, sin(a0) * prof[i].x), Vector3(cos(a1) * prof[i].x, prof[i].y, sin(a1) * prof[i].x),
				Vector3(cos(a1) * prof[i + 1].x, prof[i + 1].y, sin(a1) * prof[i + 1].x), Vector3(cos(a0) * prof[i + 1].x, prof[i + 1].y, sin(a0) * prof[i + 1].x)]
			var uv := [Vector2(float(j) / SEG, i / 16.0), Vector2(float(j + 1) / SEG, i / 16.0), Vector2(float(j + 1) / SEG, (i + 1) / 16.0), Vector2(float(j) / SEG, (i + 1) / 16.0)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uv[k])
				st.add_vertex(p[k])
	st.index()
	st.generate_normals()
	st.generate_tangents()
	P.call(torso, st.commit(), Vector3.ZERO, Vector3.ZERO, Vector3(1.25, 1, 0.75))
	for i in 5:
		var tm := TorusMesh.new(); tm.inner_radius = 0.19 - abs(i - 2) * 0.02; tm.outer_radius = tm.inner_radius + 0.036; tm.rings = 20; tm.ring_segments = 6
		P.call(torso, tm, Vector3(0, 0.5 + i * 0.1, -0.03), Vector3(0.2, 0, 0), Vector3(1.35, 1, 1.0))
	for i in 8:
		P.call(torso, cone(0.035, 0.24 - abs(i - 4) * 0.02, 4), Vector3(0, 0.2 + i * 0.12, 0.17), Vector3(1.0, 0, 0))
	var neck := Node3D.new(); neck.position.y = 1.15; torso.add_child(neck)
	e.neck = neck
	var nk := CylinderMesh.new(); nk.top_radius = 0.05; nk.bottom_radius = 0.07; nk.height = 0.18
	P.call(neck, nk, Vector3(0, 0.03, 0))
	P.call(neck, organic(sphere(0.16, 28, 16), 0.04, 6, 4), Vector3(0, 0.14, -0.1), Vector3(0.3, 0, 0), Vector3(0.85, 0.9, 2.2))
	for i in 4:
		P.call(neck, cone(0.025, 0.3, 4), Vector3((1 if i % 2 else -1) * 0.05 * (1 + (i >> 1)), 0.22, 0.12 + i * 0.03), Vector3(-2.2, 0, (-1 if i % 2 else 1) * 0.3))
	e.jaw = []
	for s in [-1, 1]:
		var j := Node3D.new(); j.position = Vector3(s * 0.05, 0.06, -0.15); neck.add_child(j)
		P.call(j, cone(0.035, 0.36, 5), Vector3(0, 0, -0.16), Vector3(-PI / 2, 0, 0), Vector3(1, 1, 0.6))
		e.jaw.append({"g": j, "s": s})
	e.eye_mat = emissive(Color(1, 1, 1.2), 2.5)
	var eb := BoxMesh.new(); eb.size = Vector3(0.018, 0.17, 0.02)
	e.eye = add(neck, eb, e.eye_mat, Vector3(0, 0.15, -0.44))
	e.eye_glow = glow_quad(Color(0.6, 0.6, 0.9), 0.16)
	e.eye_glow.position = Vector3(0, 0.15, -0.47)
	neck.add_child(e.eye_glow)
	e.tip_mat = emissive(Color(1, 0.87, 1.13), 3.0)
	e.arms = []
	for s in [-1, 1]:
		var sh := Node3D.new(); sh.position = Vector3(s * 0.34, 0.95, 0); torso.add_child(sh)
		P.call(sh, organic(sphere(0.09, 14, 8), 0.04, 6, s), Vector3.ZERO)
		P.call(sh, organic(capsule(0.065, 0.5), 0.05, 9, s), Vector3(0, -0.32, 0))
		var el := Node3D.new(); el.position.y = -0.65; sh.add_child(el)
		P.call(el, organic(capsule(0.05, 0.56), 0.04, 10, s + 3), Vector3(0, -0.32, 0))
		P.call(el, cone(0.03, 0.5, 4), Vector3(s * 0.05, -0.2, 0.05), Vector3(0.2, 0, s * 0.15), Vector3(0.5, 1, 1))
		var hand := Node3D.new(); hand.position.y = -0.68; el.add_child(hand)
		for k in [-1, 0, 1]:
			P.call(hand, cone(0.022, 0.62, 5), Vector3(k * 0.05, -0.3, 0), Vector3(PI, 0, k * 0.12), Vector3(1, 1, 0.45))
			add(hand, sphere(0.012, 6, 4), e.tip_mat, Vector3(k * 0.05 + sin(k * 0.12) * 0.3, -0.6, 0))
		e.arms.append({"sh": sh, "el": el, "s": s})
	e.legs = []
	for s in [-1, 1]:
		var hip := Node3D.new(); hip.position = Vector3(s * 0.15, 0, 0); hips.add_child(hip)
		P.call(hip, organic(capsule(0.095, 0.42), 0.06, 7, s + 5), Vector3(0, -0.3, 0), Vector3.ZERO, Vector3(1, 1, 1.25))
		P.call(hip, cone(0.03, 0.2, 4), Vector3(0, -0.62, 0.08), Vector3(1.9, 0, 0))
		var knee := Node3D.new(); knee.position.y = -0.62; hip.add_child(knee)
		P.call(knee, organic(capsule(0.06, 0.46), 0.04, 9, s + 7), Vector3(0, -0.3, 0))
		var ank := Node3D.new(); ank.position.y = -0.62; knee.add_child(ank)
		var foot := BoxMesh.new(); foot.size = Vector3(0.09, 0.05, 0.3)
		P.call(ank, foot, Vector3(0, -0.03, -0.1))
		for k in [-1, 1]:
			P.call(ank, cone(0.018, 0.14, 4), Vector3(k * 0.03, -0.04, -0.3), Vector3(-PI / 2, 0, 0))
		e.legs.append({"hip": hip, "knee": knee, "ank": ank, "s": s})
	e.tendrils = []
	for cfg in [[-0.12, 0.16], [0.12, 0.16], [0.0, 0.2]]:
		var parent: Node3D = torso
		var chain: Array = []
		for i in 7:
			var seg := Node3D.new()
			seg.position = Vector3(cfg[0] if i == 0 else 0.0, 1.0 if i == 0 else -0.14, cfg[1] if i == 0 else 0.0)
			if i == 0:
				seg.rotation.x = 2.4
			P.call(seg, capsule(0.022 * (1 - i * 0.1), 0.1), Vector3(0, -0.07, 0))
			parent.add_child(seg)
			chain.append(seg)
			parent = seg
		e.tendrils.append({"chain": chain, "ph": randf() * 6.0})
	return root
