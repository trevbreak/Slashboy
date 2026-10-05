class_name Level
extends Node3D
## Generic sector engine: geometry helpers, practical lights, doors, scannables, zones,
## fog volumes, reflection probes, and progression props (save stations, items, elevators,
## grapple anchors, phase barriers, hazards). Sectors subclass this and fill build_content().

const T := 0.5
const TEX := "res://assets/textures/"
const ENERGY := 0.42          # three.js intensity -> Godot light_energy

var mats := {}
var builder := MeshBuilder.new()
var world_body: StaticBody3D
var doors := {}
var scannables: Array = []
var fixtures: Array = []
var animated: Array[Callable] = []
var zones: Array = []
var points := {}
var moon: DirectionalLight3D
var moon_level := 0.0
var moon_target := 0.0
var moon_max := 2.2
var time := 0.0
var glow_tex: Texture2D
var glow_shader := preload("res://shaders/glow_add.gdshader")
var holo_shader := preload("res://shaders/hologram.gdshader")
var fog_shader := preload("res://shaders/fog_noise.gdshader")
var ui_font: Font
var lift_ring_mat: StandardMaterial3D
var leviathan: Node3D
var lev_lights: StandardMaterial3D
var merged_calls := 0
var sector_id := ""
var sector_name := ""
var kill_y := -30.0
var entries := {}
var map_rooms: Array = []        # [x0, z0, x1, z1, y0, h]
var save_points: Array = []
var items: Array = []
var elevators: Array = []
var grapple_points: Array = []
var barriers: Array = []
var hazards: Array = []
var hazard_t := 0.0
var barrier_shader := preload("res://shaders/phase_barrier.gdshader")


func build() -> void:
	world_body = StaticBody3D.new()
	world_body.name = "World"
	world_body.collision_layer = 1
	world_body.collision_mask = 0
	add_child(world_body)
	glow_tex = load(TEX + "glow.png")
	var base_font := load("res://assets/fonts/ShareTechMono-Regular.ttf") as FontFile
	var cjk := SystemFont.new()
	cjk.font_names = PackedStringArray(["Hiragino Sans", "Hiragino Kaku Gothic ProN", "PingFang SC", "Noto Sans CJK JP"])
	base_font.fallbacks = [cjk]
	ui_font = base_font
	make_materials()
	make_lights()
	build_content()
	build_zone_volumes()
	merged_calls = builder.commit(self)


# ----- overridden by sectors
func configure_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_SKY
	env.background_energy_multiplier = 1.0
	env.ambient_light_color = Color(0.18, 0.24, 0.32)
	env.volumetric_fog_albedo = Color(0.7, 0.75, 0.85)
	env.volumetric_fog_anisotropy = 0.55
	(env.sky.sky_material as PanoramaSkyMaterial).energy_multiplier = 1.2


func build_content() -> void:
	pass


func script(_d) -> void:
	pass


func on_enter(_d, _entry: String, _first_time: bool) -> void:
	pass


func sector_update(_d, _dt: float) -> void:
	pass


# ===================================================================== materials
func pbr(name: String, metal := 0.85, rough := 1.0, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + name + "_albedo.png")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX + name + "_normal.png")
	m.normal_scale = 1.0
	var orm: Texture2D = load(TEX + name + "_orm.png")
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = 0.25
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = rough
	m.metallic_texture = orm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = metal
	m.metallic_specular = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func emissive(c: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


func plain(c: Color, rough := 0.4, metal := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func glow_material(c: Color, gain := 1.0, billboard := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = glow_shader
	m.set_shader_parameter("tex", glow_tex)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("gain", gain)
	m.set_shader_parameter("billboard", billboard)
	return m


func make_materials() -> void:
	mats.wall = pbr("wall")
	mats.wall_dark = pbr("wall_dark")
	mats.ceil = pbr("ceiling", 0.85, 1.1)
	mats.floor = pbr("floor", 0.9)
	mats.door = pbr("door", 0.9)
	mats.dark_metal = plain(Color(0.14, 0.15, 0.18), 0.38, 0.9)
	mats.pipe = plain(Color(0.24, 0.21, 0.17), 0.35, 0.85)
	mats.rubber = plain(Color(0.04, 0.04, 0.045), 0.9, 0.0)
	mats.cyan = emissive(Color(0.15, 0.8, 1.0), 2.0)
	mats.cyan_dim = emissive(Color(0.11, 0.78, 1.0), 0.45)
	mats.red = emissive(Color(1.0, 0.05, 0.07), 3.0)
	mats.red_dim = emissive(Color(1.0, 0.05, 0.08), 0.6)
	mats.amber = emissive(Color(1.0, 0.5, 0.08), 2.4)
	mats.purple = emissive(Color(0.5, 0.11, 1.0), 2.6)
	mats.white = emissive(Color(1, 1, 1.05), 3.0)
	mats.green_dim = emissive(Color(0.08, 1.0, 0.25), 0.6)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.53, 0.67, 0.8, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.9
	glass.roughness = 0.05
	mats.glass = glass
	var bloom := StandardMaterial3D.new()
	bloom.albedo_color = Color(0.1, 0.03, 0.13)
	bloom.emission_enabled = true
	bloom.emission = Color(0.55, 0.08, 1.0)
	bloom.emission_energy_multiplier = 0.5
	bloom.roughness = 0.3
	bloom.clearcoat_enabled = true
	mats.bloom = bloom
	mats.bloom_flesh = plain(Color(0.07, 0.025, 0.06), 0.35, 0.2)


# ===================================================================== lights
func make_lights() -> void:
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.71, 1.0)
	moon.light_energy = 0.0
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.directional_shadow_max_distance = 90.0
	moon.light_volumetric_fog_energy = 1.2
	moon.shadow_bias = 0.04
	add_child(moon)
	moon.look_at_from_position(Vector3(94, 70, -37), Vector3(34, 0, -45), Vector3.UP)


func fixture(o: Dictionary) -> Dictionary:
	var pos := Vector3(o.x, o.y, o.z)
	var col: Color = o.get("color", Color(0.81, 0.91, 1.0))
	var size: Vector3 = o.get("size", Vector3(1.2, 0.08, 0.3))
	var mat: StandardMaterial3D = null
	if o.get("mesh", true):
		mat = emissive(col, 3.0)
		mat.set_meta("glow", o.get("glow", 3.0))
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pos
		add_child(mi)
		var housing := MeshInstance3D.new()
		var hm := BoxMesh.new(); hm.size = Vector3(size.x + 0.12, 0.1, size.z + 0.12)
		housing.mesh = hm
		housing.material_override = mats.dark_metal
		housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		housing.position = pos + Vector3(0, 0.08, 0)
		add_child(housing)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, o.get("light_y", -0.25), 0)
	l.light_color = col
	l.omni_range = o.get("distance", 10.0) * 1.15
	l.omni_attenuation = 1.2
	l.shadow_enabled = o.get("shadow", false)
	l.shadow_bias = 0.05
	l.shadow_normal_bias = 1.5
	l.light_volumetric_fog_energy = o.get("fog", 1.0)
	l.light_specular = 0.6
	add_child(l)
	var f := {
		"light": l, "mat": mat, "color": col, "base": o.get("intensity", 6.0) * ENERGY, "mode": o.get("mode", "steady"),
		"group": o.get("group", ""), "k": 1.0, "on": true, "t": randf() * 10.0, "flick_t": randf_range(2.0, 8.0),
		"flicking": 0.0, "sub": 0.0, "sub_on": true, "speed": o.get("speed", 2.0), "pos": l.position,
	}
	fixtures.append(f)
	return f


func set_group(group: String, state: String) -> void:
	for f in fixtures:
		if f.group != group:
			continue
		if state == "off":
			f.on = false
		elif state == "on":
			f.on = true
		else:
			f.mode = state
			f.on = true


func update_fixtures(dt: float, player_pos: Vector3) -> void:
	for f in fixtures:
		f.t += dt
		var k := 1.0
		match f.mode:
			"flicker":
				f.flick_t -= dt
				if f.flick_t <= 0.0:
					f.flicking = randf_range(0.15, 0.75)
					f.flick_t = randf_range(2.5, 9.5)
					if f.pos.distance_to(player_pos) < 12.0:
						G.audio.play3d("buzz", f.pos, -6.0)
				if f.flicking > 0.0:
					f.flicking -= dt
					f.sub -= dt
					if f.sub <= 0.0:
						f.sub = randf_range(0.03, 0.1)
						f.sub_on = randf() < 0.45
					k = 1.0 if f.sub_on else 0.05
			"broken":
				f.flick_t -= dt
				if f.flick_t <= 0.0:
					f.flicking = randf_range(0.1, 0.45)
					f.flick_t = randf_range(3.0, 9.0)
					if f.pos.distance_to(player_pos) < 14.0:
						G.audio.play3d("buzz", f.pos, -6.0)
						if randf() < 0.5:
							G.audio.play3d("sparks", f.pos, -4.0)
				k = 0.0
				if f.flicking > 0.0:
					f.flicking -= dt
					f.sub -= dt
					if f.sub <= 0.0:
						f.sub = randf_range(0.03, 0.08)
						f.sub_on = randf() < 0.5
					k = 0.9 if f.sub_on else 0.0
			"pulse":
				k = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(f.t * f.speed), 2.0)
			"emergency":
				k = 0.3 + 0.7 * (1.0 if sin(f.t * 4.0) > 0.0 else 0.2)
		if not f.on:
			k = 0.0
		f.k += (k - f.k) * min(1.0, dt * 30.0)
		f.light.light_energy = f.base * f.k
		f.light.visible = f.k > 0.005
		if f.mat:
			f.mat.emission_energy_multiplier = 0.06 + f.k * float(f.mat.get_meta("glow", 3.0))


# ===================================================================== geometry helpers
func box(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, mat: Material, o := {}) -> void:
	if x1 - x0 <= 0.001 or y1 - y0 <= 0.001 or z1 - z0 <= 0.001:
		return
	if o.get("visual", true):
		builder.box(Vector3(x0, y0, z0), Vector3(x1, y1, z1), mat, o.get("uv", 3.0), o.get("cast", true))
	if o.get("collide", true):
		collider(x0, y0, z0, x1, y1, z1)


func collider(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(x1 - x0, y1 - y0, z1 - z0)
	cs.shape = bs
	cs.position = Vector3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	world_body.add_child(cs)
	return cs


func strip(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, mat: Material) -> void:
	box(x0, y0, z0, x1, y1, z1, mat, {"collide": false, "cast": false})


## Rectangular room; openings per side as [{c, w, h, y, glass}] in absolute coordinates.
func room(o: Dictionary) -> void:
	var x0: float = o.x0; var x1: float = o.x1; var z0: float = o.z0; var z1: float = o.z1
	var y0: float = o.get("y0", 0.0); var h: float = o.h
	var W := {"n": true, "s": true, "e": true, "w": true}
	W.merge(o.get("walls", {}), true)
	var open: Dictionary = o.get("open", {})
	var wall: Material = o.get("wall", mats.wall)
	if o.get("map", true):
		map_rooms.append([x0, z0, x1, z1, y0, h])
	var fx0 := x0 - (T if W.w else 0.0)
	var fx1 := x1 + (T if W.e else 0.0)
	var fz0 := z0 - (T if W.n else 0.0)
	var fz1 := z1 + (T if W.s else 0.0)
	if o.get("floor", mats.floor) != null:
		box(fx0, y0 - 0.5, fz0, fx1, y0, fz1, o.get("floor", mats.floor), {"cast": false, "uv": o.get("floor_uv", 4.0)})
	if o.get("ceil", mats.ceil) != null:
		box(fx0, y0 + h, fz0, fx1, y0 + h + 0.5, fz1, o.get("ceil", mats.ceil), {"uv": 4.0})
	var side := func(s: String, a0: float, a1: float, fa: float, fb: float, along_x: bool) -> void:
		var ops: Array = open.get(s, []).duplicate()
		ops.sort_custom(func(p, q): return p.c < q.c)
		var cur := a0
		var mk := func(b0: float, b1: float, ya: float, yb: float) -> void:
			if along_x:
				box(b0, ya, fa, b1, yb, fb, wall)
			else:
				box(fa, ya, b0, fb, yb, b1, wall)
		for op in ops:
			var s0: float = op.c - op.w / 2.0
			var s1: float = op.c + op.w / 2.0
			var oy: float = op.get("y", 0.0)
			mk.call(cur, s0, y0, y0 + h)
			if oy > 0.0:
				mk.call(s0, s1, y0, y0 + oy)
			mk.call(s0, s1, y0 + oy + op.h, y0 + h)
			if op.get("glass", false):
				var gm := MeshInstance3D.new()
				var qm := QuadMesh.new(); qm.size = Vector2(op.w, op.h)
				gm.mesh = qm
				gm.material_override = mats.glass
				gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var mid := (fa + fb) / 2.0
				if along_x:
					gm.position = Vector3(op.c, y0 + oy + op.h / 2.0, mid)
					collider(s0, y0 + oy, fa, s1, y0 + oy + op.h, fb)
				else:
					gm.position = Vector3(mid, y0 + oy + op.h / 2.0, op.c)
					gm.rotation.y = PI / 2
					collider(fa, y0 + oy, s0, fb, y0 + oy + op.h, s1)
				add_child(gm)
			cur = s1
		mk.call(cur, a1, y0, y0 + h)
	if W.n: side.call("n", fx0, fx1, z0 - T, z0, true)
	if W.s: side.call("s", fx0, fx1, z1, z1 + T, true)
	if W.w: side.call("w", z0, z1, x0 - T, x0, false)
	if W.e: side.call("e", z0, z1, x1, x1 + T, false)


func ribs_z(x: float, z0: float, z1: float, every: float, h: float, inward: float, skip := []) -> void:
	var z := z0 + every / 2.0
	while z < z1:
		var skipped := false
		for s in skip:
			if z > s[0] - 0.6 and z < s[1] + 0.6:
				skipped = true
		if not skipped:
			box(min(x, x + inward), 0, z - 0.18, max(x, x + inward), h, z + 0.18, mats.dark_metal, {"uv": 1.0})
		z += every


func ribs_x(z: float, x0: float, x1: float, every: float, h: float, inward: float, skip := []) -> void:
	var x := x0 + every / 2.0
	while x < x1:
		var skipped := false
		for s in skip:
			if x > s[0] - 0.6 and x < s[1] + 0.6:
				skipped = true
		if not skipped:
			box(x - 0.18, 0, min(z, z + inward), x + 0.18, h, max(z, z + inward), mats.dark_metal, {"uv": 1.0})
		x += every


func cyl_xform(a: Vector3, b: Vector3) -> Transform3D:
	var dir := b - a
	var basis := Basis(Quaternion(Vector3.UP, dir.normalized())) if dir.normalized().cross(Vector3.UP).length() > 0.001 else (Basis() if dir.y > 0 else Basis(Vector3.RIGHT, PI))
	return Transform3D(basis, a + dir * 0.5)


func pipe(a: Vector3, b: Vector3, r: float, mat: Material = null) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = a.distance_to(b); cm.radial_segments = 12; cm.rings = 1
	builder.mesh(cm, cyl_xform(a, b), mat if mat else mats.pipe)


func cable(a: Vector3, b: Vector3, sag: float, r := 0.025) -> void:
	var prev := a
	for i in range(1, 13):
		var t := i / 12.0
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		var cm := CylinderMesh.new()
		cm.top_radius = r; cm.bottom_radius = r; cm.height = prev.distance_to(p) + 0.01; cm.radial_segments = 6; cm.rings = 1
		builder.mesh(cm, cyl_xform(prev, p), mats.rubber)
		prev = p


func node_mesh(m: Mesh, mat: Material, pos: Vector3, parent: Node3D = null, cast := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func boxmesh(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func screen(pos: Vector3, rot_y: float, w: float, h: float, tex_name: String) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission_texture = load(TEX + tex_name + ".png")
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 1.6
	var qm := QuadMesh.new(); qm.size = Vector2(w, h)
	var mi := node_mesh(qm, m, pos, null, false)
	mi.rotation.y = rot_y


func console(x: float, z: float, rot_y: float, tex_name: String) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, 0, z)
	g.rotation.y = rot_y
	add_child(g)
	node_mesh(boxmesh(Vector3(1.2, 1.0, 0.6)), mats.dark_metal, Vector3(0, 0.5, 0), g)
	var top := node_mesh(boxmesh(Vector3(1.2, 0.08, 0.7)), mats.dark_metal, Vector3(0, 1.0, 0.05), g)
	top.rotation.x = -0.35
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission_texture = load(TEX + tex_name + ".png")
	m.emission_energy_multiplier = 1.4
	var qm := QuadMesh.new(); qm.size = Vector2(0.95, 0.6)
	var scr := node_mesh(qm, m, Vector3(0, 1.35, -0.18), g, false)
	scr.rotation.x = -0.25
	scr.rotation.y = PI
	node_mesh(boxmesh(Vector3(0.08, 0.5, 0.08)), mats.dark_metal, Vector3(0, 1.1, -0.22), g)
	var c := cos(rot_y); var s := sin(rot_y)
	var hx: float = abs(0.6 * c) + abs(0.35 * s); var hz: float = abs(0.6 * s) + abs(0.35 * c)
	collider(x - hx, 0, z - hz, x + hx, 1.05, z + hz)


func crate(x: float, z: float, s := 1.0, y := 0.0) -> void:
	box(x - s / 2, y, z - s / 2, x + s / 2, y + s, z + s / 2, mats.wall_dark, {"uv": 1.5})


func scannable(pos: Vector3, title: String, text: String, o := {}) -> Dictionary:
	var s := {"pos": pos, "title": title, "text": text, "scanned": false, "radius": o.get("radius", 0.6), "on_scan": o.get("on_scan", Callable()), "critical": o.get("critical", false)}
	scannables.append(s)
	return s


func bloom_growth(x: float, y: float, z: float, size: float, rnd: RandomNumberGenerator) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, y, z)
	add_child(g)
	for i in 3 + rnd.randi() % 5:
		var r := size * rnd.randf_range(0.3, 1.0)
		var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2; sm.radial_segments = 12; sm.rings = 6
		var mi := node_mesh(sm, mats.bloom if rnd.randf() < 0.35 else mats.bloom_flesh, Vector3(rnd.randf_range(-1, 1) * size, rnd.randf_range(-1, 1) * size, rnd.randf_range(-1, 1) * size), g)
		mi.scale = Vector3(1, rnd.randf_range(0.6, 1.2), 1)
	var ph := x * 3.0 + z
	animated.append(func(t, _dt): g.scale = Vector3.ONE * (1.0 + sin(t * 1.3 + ph) * 0.04))


func tendril(pts: Array, r := 0.06) -> void:
	for i in pts.size() - 1:
		pipe(pts[i], pts[i + 1], r, mats.bloom_flesh)
		pipe(pts[i], pts[i + 1], r * 0.4, mats.purple)


func vent_grate(x: float, y: float, z: float) -> void:
	box(x - 0.55, y - 0.07, z - 0.55, x + 0.55, y - 0.01, z + 0.55, mats.dark_metal, {"collide": false, "uv": 1.0})
	for i in range(-4, 5):
		box(x + i * 0.11 - 0.02, y - 0.09, z - 0.47, x + i * 0.11 + 0.02, y - 0.06, z + 0.47, mats.rubber, {"collide": false, "uv": 1.0})


func hologram(pos: Vector3, rot_y: float, w: float, h: float, lines: Array, color: Color, o := {}) -> MeshInstance3D:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	add_child(vp)
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = Vector2(6, 6)
	frame.size = Vector2(500, 244)
	vp.add_child(frame)
	for i in lines.size():
		var l := Label.new()
		l.text = lines[i].text
		l.add_theme_font_override("font", ui_font)
		l.add_theme_font_size_override("font_size", lines[i].get("size", 64 if i == 0 else 26))
		l.add_theme_color_override("font_color", Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(512, 100)
		l.position = Vector2(0, lines[i].y - (80 if i == 0 else 30))
		vp.add_child(l)
	var m := ShaderMaterial.new()
	m.shader = holo_shader
	m.set_shader_parameter("tex", vp.get_texture())
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("gain", o.get("gain", 2.2))
	m.set_shader_parameter("seed", randf() * 10.0)
	var qm := QuadMesh.new(); qm.size = Vector2(w, h)
	var mi := node_mesh(qm, m, pos, null, false)
	mi.rotation.y = rot_y
	if o.has("bob"):
		var bob: float = o.bob
		animated.append(func(t, _dt): mi.position.y = pos.y + sin(t * 0.8) * bob)
	return mi


# ===================================================================== zones: probes + fog volumes
func build_zone_volumes() -> void:
	for z in zones:
		if z.has("probe"):
			var probe := ReflectionProbe.new()
			probe.position = z.probe[0]
			probe.size = z.probe[1]
			probe.box_projection = true
			probe.interior = z.get("interior", true)
			probe.update_mode = ReflectionProbe.UPDATE_ONCE
			probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
			probe.ambient_color = z.get("probe_ambient", Color(0.05, 0.07, 0.1))
			probe.blend_distance = 1.5
			add_child(probe)
		if z.has("fog"):
			var fv := FogVolume.new()
			fv.position = z.fog[0]
			fv.size = z.fog[1]
			fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
			var fm := ShaderMaterial.new()
			fm.shader = fog_shader
			fm.set_shader_parameter("density", z.fog[2])
			fm.set_shader_parameter("albedo", z.fog[3])
			fm.set_shader_parameter("base_y", z.fog[0].y - z.fog[1].y / 2.0)
			if z.fog.size() > 4:
				fm.set_shader_parameter("emission", z.fog[4])
			fv.material = fm
			add_child(fv)
			z.fog_mat = fm


# ===================================================================== progression props
## Save station: step into the ring to save, heal and refill ki.
func save_station(pos: Vector3, id: String, rot_y := 0.0) -> void:
	var ring_mat := emissive(Color(0.2, 0.9, 1.0), 2.5)
	var pad := CylinderMesh.new(); pad.top_radius = 1.4; pad.bottom_radius = 1.5; pad.height = 0.18; pad.radial_segments = 40
	builder.mesh(pad, Transform3D(Basis(), pos + Vector3(0, 0.09, 0)), mats.dark_metal)
	collider(pos.x - 1.0, 0, pos.z - 1.0, pos.x + 1.0, 0.18, pos.z + 1.0)
	var tm := TorusMesh.new(); tm.inner_radius = 1.28; tm.outer_radius = 1.36; tm.rings = 48
	var ring := node_mesh(tm, ring_mat, pos + Vector3(0, 0.2, 0), null, false)
	var halo := TorusMesh.new(); halo.inner_radius = 1.1; halo.outer_radius = 1.16; halo.rings = 48
	var top := node_mesh(halo, ring_mat, pos + Vector3(0, 2.9, 0), null, false)
	for i in 3:
		var a := TAU * i / 3.0 + rot_y
		var post := BoxMesh.new(); post.size = Vector3(0.12, 2.8, 0.12)
		builder.mesh(post, Transform3D(Basis(), pos + Vector3(cos(a) * 1.3, 1.5, sin(a) * 1.3)), mats.dark_metal)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 1.6, 0)
	l.light_color = Color(0.35, 0.9, 1.0)
	l.light_energy = 1.6
	l.omni_range = 6.0
	add_child(l)
	hologram(pos + Vector3(0, 3.5, 0), rot_y, 1.6, 0.5, [{"text": "保存", "y": 110, "size": 72}, {"text": "SAVE STATION", "y": 195}], Color(0.4, 1.0, 1.0), {"gain": 1.6})
	var sp := {"pos": pos, "id": id, "inside": false, "ring": ring, "top": top}
	save_points.append(sp)
	animated.append(func(t, _dt):
		ring.rotation.y = t * 0.5
		top.position.y = pos.y + 2.9 + sin(t * 1.4) * 0.08)


## Collectible: "tank" (+25 max energy), "shard" (+15 max ki) or an ability ("grapple", "phase", "leap").
func item(pos: Vector3, kind: String, id: String) -> void:
	if G.progress.items.has(id):
		return
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var col := Color(0.3, 1.0, 1.0)
	match kind:
		"tank": col = Color(0.3, 1.0, 1.0)
		"shard": col = Color(0.75, 0.45, 1.0)
		_: col = Color(1.0, 0.75, 0.3)
	var core_mat := emissive(col, 3.0)
	if kind in ["tank", "shard"]:
		var gem := SphereMesh.new(); gem.radius = 0.22; gem.height = 0.6; gem.radial_segments = 4; gem.rings = 2
		node_mesh(gem, core_mat, Vector3.ZERO, root, false)
		var cage := TorusMesh.new(); cage.inner_radius = 0.34; cage.outer_radius = 0.38; cage.rings = 24
		node_mesh(cage, mats.dark_metal, Vector3.ZERO, root, false)
	else:
		var orb := SphereMesh.new(); orb.radius = 0.32; orb.height = 0.64
		node_mesh(orb, core_mat, Vector3.ZERO, root, false)
		for i in 3:
			var tm := TorusMesh.new(); tm.inner_radius = 0.55 + i * 0.12; tm.outer_radius = 0.58 + i * 0.12; tm.rings = 32
			var r := node_mesh(tm, emissive(col, 1.5), Vector3.ZERO, root, false)
			r.rotation = Vector3(randf() * PI, randf() * PI, 0)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.4
	l.omni_range = 5.0
	root.add_child(l)
	var it := {"pos": pos, "kind": kind, "id": id, "node": root, "taken": false}
	items.append(it)


## Lift pad to another sector. cond (optional Callable -> bool) gates it.
func elevator(pos: Vector3, sector: String, entry: String, label: String, cond := Callable()) -> void:
	var pad := CylinderMesh.new(); pad.top_radius = 2.6; pad.bottom_radius = 2.6; pad.height = 0.2; pad.radial_segments = 48
	builder.mesh(pad, Transform3D(Basis(), pos + Vector3(0, 0.1, 0)), mats.dark_metal, false)
	collider(pos.x - 1.8, 0, pos.z - 1.8, pos.x + 1.8, 0.2, pos.z + 1.8)
	var ring_mat := emissive(Color(1, 0.5, 0.08), 2.4)
	var tm := TorusMesh.new(); tm.inner_radius = 2.45; tm.outer_radius = 2.55; tm.rings = 64
	node_mesh(tm, ring_mat, pos + Vector3(0, 0.22, 0), null, false)
	elevators.append({"pos": pos, "sector": sector, "entry": entry, "label": label, "cond": cond, "t": 0.0, "mat": ring_mat})


func grapple_point(pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var mat := emissive(Color(1.0, 0.7, 0.25), 2.2)
	var tm := TorusMesh.new(); tm.inner_radius = 0.32; tm.outer_radius = 0.42; tm.rings = 32; tm.ring_segments = 8
	var ring := node_mesh(tm, mat, Vector3.ZERO, root, false)
	ring.rotation.x = PI / 2
	var hub := SphereMesh.new(); hub.radius = 0.14; hub.height = 0.28
	node_mesh(hub, mats.dark_metal, Vector3.ZERO, root, false)
	var arm := CylinderMesh.new(); arm.top_radius = 0.05; arm.bottom_radius = 0.05; arm.height = 1.2
	node_mesh(arm, mats.dark_metal, Vector3(0, 0.6, 0), root)
	var gp := {"pos": pos, "node": root, "mat": mat}
	grapple_points.append(gp)
	animated.append(func(t, _dt):
		var on: bool = G.has_ability("grapple")
		mat.emission_energy_multiplier = (1.6 + sin(t * 3.0) * 0.6) if on else 0.25)
	return gp


## Phase barrier: a crackling energy wall. Only a Phase Step dash passes through.
func phase_barrier(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(x1 - x0, y1 - y0, z1 - z0)
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	add_child(body)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = bs.size
	mi.mesh = bm
	var m := ShaderMaterial.new()
	m.shader = barrier_shader
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.15, 0.3)
	l.light_energy = 1.2
	l.omni_range = 6.0
	body.add_child(l)
	barriers.append({"body": body, "center": body.position})
	box(x0 - 0.2, y1, z0 - 0.2, x1 + 0.2, y1 + 0.2, z1 + 0.2, mats.dark_metal, {"collide": false})
	box(x0 - 0.2, y0 - 0.02, z0 - 0.2, x1 + 0.2, y0 + 0.1, z1 + 0.2, mats.dark_metal, {"collide": false})


## Damage volume (lava, acid, spores): dps applied while the player's feet are inside.
func hazard(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, dps: float, kind := "lava") -> void:
	hazards.append({"box": [x0, y0, z0, x1, y1, z1], "dps": dps, "kind": kind})


## Lava surface (visual + damage volume). Top at y; slight trench so the player can climb out.
func lava(x0: float, z0: float, x1: float, z1: float, y := -0.4, dps := 35.0) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(x1 - x0, z1 - z0); pm.subdivide_width = 1; pm.subdivide_depth = 1
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/lava.gdshader")
	mi.material_override = m
	mi.position = Vector3((x0 + x1) / 2, y, (z0 + z1) / 2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	box(x0, y - 1.0, z0, x1, y - 0.02, z1, mats.dark_metal, {"visual": false})
	hazard(x0, y - 1.0, z0, x1, y + 0.35, z1, dps, "lava")
	var step := 7.0
	var x := x0 + step / 2
	while x < x1:
		var z := z0 + step / 2
		while z < z1:
			var l := OmniLight3D.new()
			l.position = Vector3(x, y + 1.2, z)
			l.light_color = Color(1.0, 0.4, 0.1)
			l.light_energy = 2.2
			l.omni_range = 8.0
			l.light_volumetric_fog_energy = 1.4
			add_child(l)
			z += step
		x += step


## Hydraulic press: rises, holds, slams. Damage + knockback if caught under it.
func crusher(x0: float, z0: float, x1: float, z1: float, top: float, period := 3.2, phase := 0.0) -> void:
	var head := Node3D.new()
	add_child(head)
	var bm := BoxMesh.new(); bm.size = Vector3(x1 - x0, 1.2, z1 - z0)
	node_mesh(bm, mats.get("rust", mats.dark_metal), Vector3.ZERO, head)
	for sx in [-1, 1]:
		var stripe := BoxMesh.new(); stripe.size = Vector3(0.1, 0.25, z1 - z0 + 0.02)
		node_mesh(stripe, emissive(Color(1.0, 0.6, 0.1), 1.6), Vector3(sx * ((x1 - x0) / 2 - 0.2), -0.5, 0), head, false)
	var rod := CylinderMesh.new(); rod.top_radius = 0.3; rod.bottom_radius = 0.3; rod.height = top
	node_mesh(rod, mats.dark_metal, Vector3(0, top / 2 + 0.6, 0), head)
	var c := Vector3((x0 + x1) / 2, 0, (z0 + z1) / 2)
	var cr := {"head": head, "c": c, "box": [x0, z0, x1, z1], "top": top, "period": period, "t": phase, "slammed": false, "warned": false}
	crushers.append(cr)


var crushers: Array = []


func _update_crushers(dt: float, player_pos: Vector3) -> void:
	for cr in crushers:
		cr.t = fmod(cr.t + dt, cr.period)
		var p: float = cr.t / cr.period
		# 0-0.55 rise slowly, 0.55-0.75 hold up, 0.75-0.8 slam, 0.8-1.0 down
		var h: float
		if p < 0.55:
			h = lerpf(0.6, cr.top - 1.0, p / 0.55)
		elif p < 0.75:
			h = cr.top - 1.0 + sin(p * 80.0) * 0.02
			if not cr.warned:
				cr.warned = true
				G.audio.play3d("hydraulic", cr.c + Vector3(0, cr.top - 1, 0), -2.0)
		elif p < 0.8:
			h = lerpf(cr.top - 1.0, 0.6, (p - 0.75) / 0.05)
		else:
			h = 0.6
			if not cr.slammed:
				cr.slammed = true
				G.audio.play3d("crusher", cr.c, 6.0)
				G.fx.burst(cr.c, {"count": 30, "color": Color(2.5, 1.2, 0.4), "speed": 6.0, "life": 0.5, "size": 0.08})
				if player_pos.distance_to(cr.c) < 10.0:
					G.player.add_shake(0.4)
		if p < 0.75:
			cr.slammed = false
		if p < 0.55:
			cr.warned = false
		cr.head.position = cr.c + Vector3(0, h, 0)
		var b: Array = cr.box
		if h < 1.9 and player_pos.x > b[0] - 0.2 and player_pos.x < b[2] + 0.2 and player_pos.z > b[1] - 0.2 and player_pos.z < b[3] + 0.2 and p >= 0.75:
			var P = G.player
			if P.invuln <= 0.0 and not P.dead:
				P.receive_hit(30, cr.c + Vector3(0, 3, 0), "crush")
				var out: Vector3 = (player_pos - cr.c)
				out.y = 0
				if out.length() < 0.1:
					out = Vector3(0, 0, 1)
				var exit_z: float = b[3] + 0.8 if player_pos.z > cr.c.z else b[1] - 0.8
				P.global_position.z = exit_z


func update_props(dt: float, player_pos: Vector3) -> void:
	_update_crushers(dt, player_pos)
	var P = G.player
	if P == null or P.dead or G.state != "playing":
		return
	for sp in save_points:
		var inside: bool = Vector2(player_pos.x - sp.pos.x, player_pos.z - sp.pos.z).length() < 1.2 and abs(player_pos.y - sp.pos.y) < 1.0
		if inside and not sp.inside:
			G.save_at(sector_id, sp.pos + Vector3(0, 0.2, 0), P.yaw)
			P.hp = P.max_hp
			P.ki = P.max_ki
			G.audio.play("unlock", -2.0, 0.8)
			G.audio.play("scan_done", -4.0)
			G.fx.cyan_burst(sp.pos + Vector3(0, 1.0, 0), 40)
			G.hud.message("PROGRESS SAVED  ·  ENERGY RESTORED", 2.5)
		sp.inside = inside
	for it in items:
		if it.taken:
			continue
		it.node.rotation.y = time * 1.2
		it.node.position.y = it.pos.y + sin(time * 2.0) * 0.12
		if player_pos.distance_to(it.pos - Vector3(0, 0.6, 0)) < 1.3:
			it.taken = true
			it.node.queue_free()
			G.collect_item(it.kind, it.id)
	for e in elevators:
		var on_pad: bool = Vector2(player_pos.x - e.pos.x, player_pos.z - e.pos.z).length() < 2.0 and P.on_ground
		var ok: bool = (not e.cond.is_valid()) or e.cond.call()
		e.mat.emission_energy_multiplier = (2.4 + sin(time * 3.0)) if ok else 0.3
		if on_pad and ok:
			e.t += dt
			if e.t > 1.2:
				e.t = -999.0
				G.main.travel(e.sector, e.entry, e.label)
		elif e.t > -100.0:
			e.t = 0.0
	hazard_t -= dt
	for i in range(hazards.size() - 1, -1, -1):
		if hazards[i].has("until") and time > hazards[i].until:
			hazards.remove_at(i)
	for hz in hazards:
		var b: Array = hz.box
		if player_pos.x > b[0] and player_pos.x < b[3] and player_pos.y > b[1] - 0.2 and player_pos.y < b[4] and player_pos.z > b[2] and player_pos.z < b[5]:
			P.hazard_damage(hz.dps * dt, hz.kind)


func zone_at(p: Vector3):
	for z in zones:
		var b: Array = z.box
		if p.x >= b[0] and p.x <= b[2] and p.z >= b[1] and p.z <= b[3]:
			if b.size() > 4 and (p.y < b[4] or p.y > b[5]):
				continue
			return z
	return null


# ===================================================================== set pieces & life
func line_of_sight(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func update(dt: float, player_pos: Vector3) -> void:
	time += dt
	update_props(dt, player_pos)
	for fn in animated:
		fn.call(time, dt)
	for d in doors.values():
		d.update(dt, player_pos)
	update_fixtures(dt, player_pos)
	moon_level += (moon_target - moon_level) * min(1.0, dt * 1.5)
	moon.light_energy = moon_level * moon_max
	moon.visible = moon_level > 0.01
	if lift_ring_mat:
		lift_ring_mat.emission_energy_multiplier = 2.4 + sin(time * 3.0)
