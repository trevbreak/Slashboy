class_name Sector2
extends Level
## Sector 2 — UNDERCITY: rain-soaked city canyon at the bottom of the chasm. Hub sector.
## Lift plaza → neon market street → transit station → flooded tunnel → the Nest (Matriarch).
## The Gap (grapple) leads to the Foundry lift; the station's phase barrier to the Archives;
## the Spire lift on the far side of the Gap descends to the Bloom Heart.

const FACADE_H := 30.0
var m := {}


func configure_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.012, 0.022)
	env.ambient_light_color = Color(0.2, 0.2, 0.32)
	env.volumetric_fog_albedo = Color(0.65, 0.7, 0.85)
	env.volumetric_fog_anisotropy = 0.45


func build_content() -> void:
	sector_id = "s2"
	sector_name = "UNDERCITY"
	moon_max = 0.9
	moon.light_color = Color(0.45, 0.55, 0.9)
	moon.light_volumetric_fog_energy = 0.6
	moon.look_at_from_position(Vector3(80, 120, -40), Vector3(20, 0, -90), Vector3.UP)
	_materials()
	build_plaza()
	build_street()
	build_gap()
	build_station()
	build_tunnel()
	build_nest()
	build_backdrop()
	define_zones()
	entries = {
		"lift": {"pos": Vector3(0, 0, -9), "yaw": 0.0},
		"from_foundry": {"pos": Vector3(55, 0, -64), "yaw": PI / 2},
		"from_archives": {"pos": Vector3(-36, 0, -119), "yaw": -PI / 2},
		"from_heart": {"pos": Vector3(57, 0, -54), "yaw": PI / 2},
	}


func _materials() -> void:
	m.concrete = pbr("concrete", 0.0, 1.0)
	m.pavement = pbr("pavement", 0.0, 1.0)
	m.facade = pbr("facade", 0.6, 1.0)
	m.facade_metal = pbr("facade_metal", 0.85, 1.0)
	m.paint = plain(Color(0.08, 0.09, 0.11), 0.3, 0.7)
	m.paint2 = plain(Color(0.35, 0.08, 0.06), 0.35, 0.6)
	m.paint3 = plain(Color(0.1, 0.25, 0.3), 0.35, 0.6)
	m.glass = plain(Color(0.02, 0.03, 0.04), 0.05, 0.9)
	m.lit_warm = emissive(Color(1.0, 0.68, 0.35), 0.55)
	m.lit_cyan = emissive(Color(0.3, 0.85, 1.0), 0.45)
	m.lit_pink = emissive(Color(1.0, 0.3, 0.75), 0.45)
	m.tail = emissive(Color(1.0, 0.05, 0.05), 2.0)
	m.head = emissive(Color(1.0, 0.95, 0.8), 2.5)
	m.lantern = emissive(Color(1.0, 0.25, 0.12), 2.2)
	m.awning = plain(Color(0.25, 0.05, 0.08), 0.8, 0.0)
	m.water = StandardMaterial3D.new()
	m.water.albedo_color = Color(0.02, 0.04, 0.05, 0.8)
	m.water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.water.roughness = 0.02
	m.water.metallic = 0.3


# ===================================================================== props
func facade_dressing(x0: float, x1: float, z0: float, z1: float, along_x: bool, inward: float, rnd: RandomNumberGenerator, h := FACADE_H) -> void:
	## Lit windows, AC units, fire escapes and signs on a building face.
	var length := (x1 - x0) if along_x else (z1 - z0)
	var lit := [m.lit_warm, m.lit_cyan, m.lit_pink]
	for i in int(length * h / 16.0):
		var u: float = snappedf(rnd.randf(), 1.0 / max(1.0, length / 3.0))
		var y: float = snappedf(rnd.randf_range(3.0, h - 1.0), 3.0)
		var w := 1.2
		var mat: Material = lit[0] if rnd.randf() < 0.6 else lit[rnd.randi() % 3]
		if along_x:
			var x := lerpf(x0, x1, u)
			box(x - w / 2, y, z0 + inward * 0.05 - 0.06, x + w / 2, y + 0.9, z0 + inward * 0.05 + 0.06, mat, {"collide": false, "cast": false})
		else:
			var z := lerpf(z0, z1, u)
			box(x0 + inward * 0.05 - 0.06, y, z - w / 2, x0 + inward * 0.05 + 0.06, y + 0.9, z + w / 2, mat, {"collide": false, "cast": false})
	for i in int(length / 6.0):
		var u := rnd.randf()
		var y := rnd.randf_range(4.0, h - 4.0)
		if along_x:
			var x := lerpf(x0, x1, u)
			box(x - 0.5, y, z0, x + 0.5, y + 0.6, z0 + inward * 0.6, m.facade_metal, {"collide": false, "uv": 1.0})
		else:
			var z := lerpf(z0, z1, u)
			box(x0, y, z - 0.5, x0 + inward * 0.6, y + 0.6, z + 0.5, m.facade_metal, {"collide": false, "uv": 1.0})
	# fire-escape balconies
	for i in int(length / 14.0):
		var u := rnd.randf_range(0.1, 0.9)
		for k in 3:
			var y := 6.0 + k * 4.0
			if along_x:
				var x := lerpf(x0, x1, u)
				box(x - 1.5, y, z0, x + 1.5, y + 0.08, z0 + inward * 1.2, mats.dark_metal, {"collide": false})
				box(x - 1.5, y + 0.9, z0 + inward * 1.15, x + 1.5, y + 0.95, z0 + inward * 1.2, mats.dark_metal, {"collide": false})
			else:
				var z := lerpf(z0, z1, u)
				box(x0, y, z - 1.5, x0 + inward * 1.2, y + 0.08, z + 1.5, mats.dark_metal, {"collide": false})
				box(x0 + inward * 1.15, y + 0.9, z - 1.5, x0 + inward * 1.2, y + 0.95, z + 1.5, mats.dark_metal, {"collide": false})


func neon_sign(pos: Vector3, rot_y: float, size: Vector2, tex: String, col: Color, light := true) -> void:
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color.BLACK
	nm.emission_enabled = true
	nm.emission_texture = load(TEX + tex + ".png")
	nm.emission = Color.WHITE
	nm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	nm.emission_energy_multiplier = 2.6
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new(); q.size = size
	var mi := node_mesh(q, nm, pos, null, false)
	mi.rotation.y = rot_y
	var back := BoxMesh.new(); back.size = Vector3(size.x + 0.2, size.y + 0.2, 0.15)
	var bk := node_mesh(back, mats.dark_metal, pos - Vector3(sin(rot_y), 0, cos(rot_y)) * 0.1, null, false)
	bk.rotation.y = rot_y
	if light:
		var l := OmniLight3D.new()
		l.position = pos + Vector3(sin(rot_y), 0, cos(rot_y)) * 1.2
		l.light_color = col
		l.light_energy = 2.2
		l.omni_range = 9.0
		l.light_volumetric_fog_energy = 1.0
		add_child(l)
		if randf() < 0.3:
			var ph := randf() * 10.0
			animated.append(func(t, _dt):
				var on := sin(t * 11.0 + ph) > -0.85 or fmod(t + ph, 6.0) > 0.4
				mi.visible = on
				l.visible = on)


func street_lamp(x: float, z: float, side: float, col := Color(1.0, 0.72, 0.4), mode := "steady") -> void:
	pipe(Vector3(x, 0, z), Vector3(x, 6.2, z), 0.08, mats.dark_metal)
	pipe(Vector3(x, 6.2, z), Vector3(x - side * 1.4, 6.6, z), 0.06, mats.dark_metal)
	fixture({"x": x - side * 1.5, "y": 6.55, "z": z, "color": col, "intensity": 6, "distance": 13, "size": Vector3(0.7, 0.12, 0.35), "mode": mode, "shadow": true, "fog": 0.9, "glow": 1.1})
	collider(x - 0.15, 0, z - 0.15, x + 0.15, 6.2, z + 0.15)


func car(x: float, z: float, rot: float, paint: Material) -> void:
	var b := Basis(Vector3.UP, rot)
	var parts := [
		[Vector3(2.0, 0.55, 4.4), Vector3(0, 0.62, 0), paint],
		[Vector3(1.8, 0.5, 2.2), Vector3(0, 1.15, 0.2), paint],
		[Vector3(1.7, 0.42, 2.0), Vector3(0, 1.17, 0.2), m.glass],
		[Vector3(1.9, 0.08, 0.05), Vector3(0, 0.72, 2.22), m.tail],
		[Vector3(1.6, 0.1, 0.05), Vector3(0, 0.7, -2.22), m.head],
	]
	for p in parts:
		var bm := BoxMesh.new(); bm.size = p[0]
		builder.mesh(bm, Transform3D(b, Vector3(x, 0, z) + b * p[1]), p[2])
	for wx in [-0.95, 0.95]:
		for wz in [-1.4, 1.4]:
			var w := CylinderMesh.new(); w.top_radius = 0.38; w.bottom_radius = 0.38; w.height = 0.3; w.radial_segments = 12
			builder.mesh(w, Transform3D(b * Basis(Vector3.BACK, PI / 2), Vector3(x, 0.38, z) + b * Vector3(wx, 0, wz)), mats.rubber)
	var e := Vector3(abs(cos(rot)) * 1.0 + abs(sin(rot)) * 2.2, 0, abs(sin(rot)) * 1.0 + abs(cos(rot)) * 2.2)
	collider(x - e.x, 0, z - e.z, x + e.x, 1.4, z + e.z)


func stall(x: float, z: float, rot_y: float, rnd: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, rot_y)
	var counter := BoxMesh.new(); counter.size = Vector3(3.0, 1.0, 1.2)
	builder.mesh(counter, Transform3D(b, Vector3(x, 0.5, z)), m.facade_metal)
	var aw := BoxMesh.new(); aw.size = Vector3(3.4, 0.06, 2.0)
	builder.mesh(aw, Transform3D(b * Basis(Vector3.RIGHT, 0.25), Vector3(x, 2.6, z) + b * Vector3(0, 0, 0.3)), m.awning)
	for px in [-1.5, 1.5]:
		var post := CylinderMesh.new(); post.top_radius = 0.04; post.bottom_radius = 0.04; post.height = 2.6
		builder.mesh(post, Transform3D(b, Vector3(x, 1.3, z) + b * Vector3(px, 0, 1.1)), mats.dark_metal)
	for i in 3:
		var lan := SphereMesh.new(); lan.radius = 0.16; lan.height = 0.4
		builder.mesh(lan, Transform3D(b, Vector3(x, 2.15, z) + b * Vector3(-1.0 + i, 0, 1.2)), m.lantern, false)
	var l := OmniLight3D.new()
	l.position = Vector3(x, 1.9, z) + b * Vector3(0, 0, 1.4)
	l.light_color = Color(1.0, 0.35, 0.18)
	l.light_energy = 1.4
	l.omni_range = 5.5
	add_child(l)
	var e := Vector3(abs(cos(rot_y)) * 1.5 + abs(sin(rot_y)) * 0.6, 0, abs(sin(rot_y)) * 1.5 + abs(cos(rot_y)) * 0.6)
	collider(x - e.x, 0, z - e.z, x + e.x, 1.0, z + e.z)


# ===================================================================== U1 — Lift Plaza
func build_plaza() -> void:
	var rnd := RandomNumberGenerator.new(); rnd.seed = 201
	room({"x0": -12, "x1": 12, "z0": -24, "z1": 0, "h": FACADE_H, "ceil": null, "wall": m.facade, "floor": m.pavement,
		"open": {"n": [{"c": 0, "w": 16, "h": FACADE_H}]}})
	facade_dressing(-12, -12, -24, 0, false, 1, rnd)
	facade_dressing(12, 12, -24, 0, false, -1, rnd)
	facade_dressing(-12, 12, 0, 0, true, -1, rnd)
	elevator(Vector3(0, 0, -5), "s1", "lift", "ASCENDING TO RING C")
	save_station(Vector3(-8, 0, -18), "s2_plaza")
	hologram(Vector3(0, 7.5, -0.6), 0, 7, 2.8, [{"text": "下層 UNDERCITY", "y": 115, "size": 70}, {"text": "LEVEL -4000 // CHASM FLOOR", "y": 195}], Color(1.0, 0.42, 0.84), {"gain": 1.5})
	neon_sign(Vector3(-11.4, 9, -8), PI / 2, Vector2(6, 1.5), "neon_cyan", Color(0.3, 0.9, 1.0))
	neon_sign(Vector3(11.4, 12, -15), -PI / 2, Vector2(7, 1.8), "neon_pink", Color(1.0, 0.3, 0.8))
	street_lamp(-9, -4, -1)
	street_lamp(9, -12, 1, Color(0.4, 0.85, 1.0))
	car(6.5, -19, 0.3, m.paint2)
	# ki shard on a shop awning ledge: reachable from the car roof with Kage Leap
	box(8.6, 2.9, -22.5, 12, 3.1, -18.5, mats.dark_metal, {"uv": 1.0})
	item(Vector3(10.5, 3.9, -20.5), "shard", "s2_shard_plaza")
	steam_at(Vector3(-3, 0.05, -21))
	fixture({"x": 0, "y": 9.5, "z": -10, "color": Color(0.9, 0.95, 1.0), "intensity": 4, "distance": 18, "size": Vector3(0.6, 0.15, 0.6), "mode": "flicker"})


func steam_at(p: Vector3) -> void:
	if not points.has("steam_vents"):
		points.steam_vents = []
	points.steam_vents.append(p)
	box(p.x - 0.4, 0.0, p.z - 0.4, p.x + 0.4, 0.04, p.z + 0.4, mats.dark_metal, {"collide": false, "uv": 1.0})


# ===================================================================== U2 — Neon Market Street
func build_street() -> void:
	var rnd := RandomNumberGenerator.new(); rnd.seed = 202
	room({"x0": -8, "x1": 8, "z0": -104, "z1": -24.5, "h": FACADE_H, "ceil": null, "wall": m.facade, "floor": m.concrete, "floor_uv": 8.0,
		"walls": {"s": false, "n": false}, "open": {"e": [{"c": -60, "w": 5, "h": 9}], "w": [{"c": -44, "w": 3, "h": 3.5}]}})
	facade_dressing(-8, -8, -104, -24.5, false, 1, rnd)
	facade_dressing(8, 8, -104, -24.5, false, -1, rnd)
	# sidewalks / curbs
	box(-8, 0, -104, -5.5, 0.15, -24.5, m.pavement, {"uv": 3.0, "collide": false})
	box(5.5, 0, -104, 8, 0.15, -24.5, m.pavement, {"uv": 3.0, "collide": false})
	var signs := [["neon_pink", Color(1, 0.3, 0.8)], ["neon_cyan", Color(0.3, 0.9, 1)], ["neon_amber", Color(1, 0.7, 0.3)], ["neon_violet", Color(0.6, 0.45, 1)]]
	for i in 8:
		var z := -32.0 - i * 9.5
		var side := -1 if i % 2 == 0 else 1
		var sg: Array = signs[i % 4]
		neon_sign(Vector3(side * 7.35, rnd.randf_range(5.0, 11.0), z), PI / 2 if side < 0 else -PI / 2, Vector2(rnd.randf_range(4, 7), rnd.randf_range(1.2, 2.0)), sg[0], sg[1])
	for z in [-34, -58, -82, -100]:
		street_lamp(-6.6, z, -1)
		street_lamp(6.6, z + 12, 1, Color(0.45, 0.85, 1.0), "flicker" if z == -58 else "steady")
	car(-3.5, -40, 0.15, m.paint)
	car(3.2, -70, 2.9, m.paint3)
	car(-2.8, -90, 1.4, m.paint2)
	for s in [[-6.4, -50, PI / 2], [6.4, -48, -PI / 2], [-6.4, -76, PI / 2], [6.4, -88, -PI / 2]]:
		stall(s[0], s[1], s[2], rnd)
	hologram(Vector3(0, 11, -64), 0, 8, 3.4, [{"text": "夜市", "y": 110, "size": 90}, {"text": "NIGHT MARKET  ·  ALWAYS OPEN", "y": 200}], Color(1.0, 0.65, 0.25), {"gain": 1.4, "bob": 0.3})
	steam_at(Vector3(4.0, 0.05, -52))
	steam_at(Vector3(-4.5, 0.05, -96))
	# phase-sealed shop with an energy tank
	room({"x0": -16, "x1": -8.5, "z0": -50, "z1": -38, "h": 4, "walls": {"e": false}, "wall": m.facade_metal})
	phase_barrier(-8.48, 0, -45.5, -8.02, 3.5, -42.5)
	item(Vector3(-13.5, 1.0, -44), "tank", "s2_tank_shop")
	fixture({"x": -12, "y": 3.9, "z": -44, "color": Color(1.0, 0.4, 0.6), "intensity": 3, "distance": 8, "mode": "broken"})
	scannable(Vector3(-8.3, 1.8, -44), "PHASE LOCK // SHOP SHUTTER",
		"A Bloom-tuned phase barrier. Matter can't cross it in this frame of reference.\nSomething, or someone, would have to step outside of it.")
	scannable(Vector3(0, 11, -64), "NIGHT MARKET",
		"Three hundred stalls, power still on, food still warm in the vending racks.\nPersonnel tracking shows 0 of 11,000 residents present.\nThe rain is condensate from the arcology's dying climate system. It has not stopped in nine days.")


# ===================================================================== U3 — The Gap
func build_gap() -> void:
	var rnd := RandomNumberGenerator.new(); rnd.seed = 203
	room({"x0": 8.5, "x1": 20, "z0": -62.5, "z1": -57.5, "h": 12, "ceil": null, "wall": m.facade, "floor": m.concrete, "walls": {"w": false, "e": false}})
	room({"x0": 20.5, "x1": 32, "z0": -76, "z1": -44, "h": 20, "ceil": null, "wall": m.facade, "floor": m.concrete, "walls": {"e": false},
		"open": {"w": [{"c": -60, "w": 5, "h": 12}]}})
	box(20, 0, -62.9, 20.5, 12, -62.5, m.facade)
	box(20, 0, -57.5, 20.5, 12, -57.1, m.facade)
	# broken overpass edge + railing
	for z in range(-76, -43, 2):
		box(31.7, 0, z, 31.9, 1.1, z + 0.08, mats.dark_metal, {"collide": false})
	box(31.6, 1.05, -76, 32.0, 1.12, -44, mats.dark_metal, {"collide": false})
	collider(31.9, 0, -76, 32.1, 1.2, -44)
	box(32, -1.2, -66, 36, 0.0, -54, m.concrete, {"collide": false})
	# far platform with the Foundry lift and the Spire lift
	room({"x0": 48, "x1": 62, "z0": -72, "z1": -48, "h": 20, "ceil": null, "wall": m.facade_metal, "floor": m.concrete, "walls": {"w": false}})
	box(44, -1.0, -66, 48, 0.0, -54, m.concrete, {"collide": false})
	elevator(Vector3(55, 0, -62), "s3", "lift", "DESCENDING TO THE FOUNDRY")
	elevator(Vector3(57, 0, -52), "s5", "lift", "DESCENDING TO THE BLOOM HEART", func(): return G.progress.bosses.has("warden") and G.progress.bosses.has("archivist"))
	hologram(Vector3(55, 4.5, -71.5), 0, 4, 1.4, [{"text": "鋳造所", "y": 110, "size": 70}, {"text": "FOUNDRY LIFT", "y": 195}], Color(1.0, 0.55, 0.2))
	hologram(Vector3(61.5, 4.5, -52), -PI / 2, 4, 1.4, [{"text": "心臓", "y": 110, "size": 70}, {"text": "SPIRE LIFT // SEALED", "y": 195}], Color(1.0, 0.3, 0.6))
	fixture({"x": 55, "y": 8, "z": -62, "color": Color(1.0, 0.6, 0.3), "intensity": 6, "distance": 14, "size": Vector3(1, 0.1, 1), "shadow": true})
	fixture({"x": 26, "y": 9, "z": -60, "color": Color(0.5, 0.85, 1.0), "intensity": 7, "distance": 18, "size": Vector3(1, 0.1, 1)})
	street_lamp(30.5, -46, 1)
	street_lamp(30.5, -74, 1, Color(0.45, 0.85, 1.0))
	street_lamp(49.5, -70, -1)
	street_lamp(49.5, -50, -1, Color(0.45, 0.85, 1.0))
	neon_sign(Vector3(61.4, 9, -60), -PI / 2, Vector2(8, 2), "neon_amber", Color(1, 0.7, 0.3))
	# grapple chain across the chasm
	grapple_point(Vector3(39, 7.2, -60))
	grapple_point(Vector3(49.5, 6.4, -60))
	# floating girder with an energy tank, via an anchor above it
	box(38, 8.8, -72, 42, 9.2, -68, mats.dark_metal, {"uv": 1.0})
	grapple_point(Vector3(40, 12.2, -70))
	item(Vector3(40, 10.0, -70), "tank", "s2_tank_gap")
	# the chasm: girders and lights falling away into the fog
	for i in 14:
		var gx := rnd.randf_range(30, 52)
		var gz := rnd.randf_range(-90, -30)
		var gy := rnd.randf_range(-60, -8)
		box(gx - 0.4, gy, gz - rnd.randf_range(2, 9), gx + 0.4, gy + 0.8, gz + rnd.randf_range(2, 9), mats.dark_metal, {"collide": false, "uv": 1.0})
	for i in 30:
		var gl := MeshInstance3D.new()
		var q := QuadMesh.new(); q.size = Vector2.ONE * rnd.randf_range(1.5, 4.0)
		gl.mesh = q
		gl.material_override = glow_material([Color(1, 0.6, 0.3), Color(0.3, 0.8, 1.0), Color(1, 0.3, 0.7)][i % 3] * 1.2)
		gl.position = Vector3(rnd.randf_range(30, 50), rnd.randf_range(-80, -15), rnd.randf_range(-95, -25))
		add_child(gl)
	scannable(Vector3(39, 7.2, -60), "ANCHOR RING",
		"Maintenance tether point. Rated for 4 tonnes.\nA chain-kunai could bite into this and haul a body across the gap.")
	scannable(Vector3(55, 1.4, -62), "FOUNDRY LIFT",
		"Freight lift to the arcology's foundry decks.\nAccess across the gap only. The overpass collapsed on day 2.")


# ===================================================================== U4 — Transit Station
func build_station() -> void:
	var rnd := RandomNumberGenerator.new(); rnd.seed = 204
	room({"x0": -14, "x1": 14, "z0": -134, "z1": -104.5, "h": 10, "wall": mats.wall, "floor": mats.floor,
		"open": {"s": [{"c": 0, "w": 6, "h": 6}], "w": [{"c": -119, "w": 3, "h": 3.5}], "n": [{"c": 0, "w": 4, "h": 4}]}})
	ribs_z(-14, -134, -104.5, 4, 10, 0.4, [[-121, -117]])
	ribs_z(14, -134, -104.5, 4, 10, -0.4)
	var z := -132.0
	while z < -105:
		box(-14, 9.3, z - 0.3, 14, 10, z + 0.3, mats.dark_metal, {"collide": false})
		z += 4.0
	# dead trains along both platforms
	for side in [-1, 1]:
		var x = side * 10.5
		box(x - 1.6, 0, -132, x + 1.6, 3.6, -107, m.paint3 if side < 0 else m.paint2, {"uv": 2.0})
		for wz in range(-130, -108, 3):
			box(x - side * 1.62, 1.6, wz, x - side * 1.6 + side * 0.0 + (0.01 if side > 0 else -0.01), 2.6, wz + 2.0, m.lit_cyan if rnd.randf() < 0.3 else m.glass, {"collide": false, "cast": false})
	# turnstiles
	for x in range(-6, 7, 2):
		box(x - 0.15, 0, -111, x + 0.15, 1.1, -109.5, mats.dark_metal, {"uv": 1.0})
	for i in 5:
		fixture({"x": 0, "y": 9.2, "z": -108 - i * 6, "color": Color(0.85, 0.95, 1.0), "intensity": 8, "distance": 15, "size": Vector3(4, 0.1, 0.3), "mode": "flicker" if i == 3 else "steady", "group": "station", "shadow": i == 2})
	hologram(Vector3(0, 6.5, -133.4), 0, 6, 2.2, [{"text": "環状線", "y": 110, "size": 72}, {"text": "LOOP LINE  ·  ALL SERVICES SUSPENDED", "y": 195}], Color(0.4, 0.9, 1.0))
	save_station(Vector3(-8, 0, -126), "s2_station")
	screen(Vector3(6, 2.6, -104.8), PI, 3.2, 1.6, "screen_cyan")
	scannable(Vector3(6, 2.6, -104.8), "DEPARTURES BOARD",
		"LOOP LINE: suspended. ARCHIVE SPUR: SEALED BY PHASE LOCK (AI ORDER 0091).\nSPIRE LIFT: SEALED UNTIL FOUNDRY AND ARCHIVE AUTHORITIES CONCUR.\nLast message: \"Nest growth on platform 4. Do not take the tunnel.\"")
	points.station_vents = [Vector3(-6, 9.4, -118), Vector3(6, 9.4, -124), Vector3(0, 9.4, -130)]
	for v in points.station_vents:
		vent_grate(v.x, 9.98, v.z)
	# archive spur (phase barrier) and lift hall
	room({"x0": -31.5, "x1": -14.5, "z0": -121, "z1": -117, "h": 4, "walls": {"e": false, "w": false}, "wall": mats.wall_dark})
	phase_barrier(-22.2, 0, -121, -21.8, 4, -117)
	room({"x0": -44, "x1": -32, "z0": -125, "z1": -113, "h": 7, "wall": mats.wall_dark, "open": {"e": [{"c": -119, "w": 4, "h": 4}]}})
	elevator(Vector3(-38, 0, -119), "s4", "lift", "DESCENDING TO THE ARCHIVES")
	fixture({"x": -38, "y": 6.8, "z": -119, "color": Color(0.7, 0.85, 1.0), "intensity": 5, "distance": 10, "size": Vector3(1, 0.08, 1)})
	hologram(Vector3(-43.5, 4.5, -119), PI / 2, 4, 1.4, [{"text": "記録庫", "y": 110, "size": 70}, {"text": "ARCHIVE SPUR", "y": 195}], Color(0.6, 0.85, 1.0))


# ===================================================================== U5 — Flooded Tunnel
func build_tunnel() -> void:
	room({"x0": -3, "x1": 3, "z0": -180, "z1": -134.5, "h": 5, "walls": {"s": false}, "wall": mats.wall_dark, "ceil": mats.ceil,
		"open": {"n": [{"c": 0, "w": 4, "h": 4}]}})
	ribs_z(-3, -180, -134.5, 2.5, 5, 0.25)
	ribs_z(3, -180, -134.5, 2.5, 5, -0.25)
	for rx in [-0.75, 0.75]:
		box(rx - 0.05, 0.0, -180, rx + 0.05, 0.12, -134.5, mats.dark_metal, {"collide": false})
	var water := MeshInstance3D.new()
	var q := PlaneMesh.new(); q.size = Vector2(6, 45.5)
	water.mesh = q
	water.material_override = m.water
	water.position = Vector3(0, 0.1, -157.25)
	add_child(water)
	var z := -138.0
	var i := 0
	while z > -178:
		fixture({"x": 2.6, "y": 3.6, "z": z, "color": Color(1.0, 0.45, 0.2), "intensity": 3.5, "distance": 7, "size": Vector3(0.12, 0.25, 0.4), "group": "tunnel", "mode": "broken" if i % 3 == 2 else ("flicker" if i % 2 else "steady")})
		z -= 6.0
		i += 1
	var d := Door.new(); add_child(d); d.setup(self, Vector3(0, 0, -180.25), "x", 4, 4, false); doors.nest = d
	scannable(Vector3(-2.8, 1.6, -150), "CLAW-SCORED TILE",
		"Hundreds of overlapping scratches, all heading north.\nSomething large drags itself along this tunnel nightly.\nThe water here is warm.")


# ===================================================================== U6 — The Nest
func build_nest() -> void:
	var rnd := RandomNumberGenerator.new(); rnd.seed = 206
	room({"x0": -22, "x1": 22, "z0": -224, "z1": -180.5, "h": 18, "wall": mats.wall_dark, "floor": mats.floor,
		"open": {"s": [{"c": 0, "w": 4, "h": 4}]}})
	ribs_z(-22, -224, -180.5, 5, 18, 0.5)
	ribs_z(22, -224, -180.5, 5, 18, -0.5)
	ribs_x(-224, -22, 22, 5, 18, 0.5)
	for p in [[-11, -195], [11, -195], [-11, -210], [11, -210]]:
		box(p[0] - 1.3, 0, p[1] - 1.3, p[0] + 1.3, 18, p[1] + 1.3, mats.wall, {"uv": 2.0})
	var water := MeshInstance3D.new()
	var q := PlaneMesh.new(); q.size = Vector2(44, 43.5)
	water.mesh = q
	water.material_override = m.water
	water.position = Vector3(0, 0.08, -202.25)
	add_child(water)
	for i in 34:
		var a := rnd.randf() * TAU
		var on_wall := rnd.randf() < 0.6
		var p := Vector3(rnd.randf_range(-21, 21), rnd.randf_range(0.3, 6.0), rnd.randf_range(-223, -182))
		if on_wall:
			if rnd.randf() < 0.5:
				p.x = -21.6 if p.x < 0 else 21.6
			else:
				p.z = -223.6
		bloom_growth(p.x, p.y, p.z, rnd.randf_range(0.3, 0.8), rnd)
	for i in 6:
		tendril([Vector3(rnd.randf_range(-20, 20), 18, rnd.randf_range(-222, -183)), Vector3(rnd.randf_range(-15, 15), 12, rnd.randf_range(-218, -186)), Vector3(rnd.randf_range(-20, 20), 6, rnd.randf_range(-222, -183))], 0.12)
	for p in [[-16, -186], [16, -186], [-16, -218], [16, -218], [0, -202]]:
		fixture({"x": p[0], "y": 17.8, "z": p[1], "color": Color(0.9, 0.55, 0.25), "intensity": 6, "distance": 18, "size": Vector3(2, 0.1, 2), "group": "nest", "shadow": p[0] == 0})
	for p in [[-21.4, -202], [21.4, -202]]:
		var f := fixture({"x": p[0], "y": 8, "z": p[1], "color": Color(1.0, 0.1, 0.1), "intensity": 8, "distance": 20, "mode": "emergency", "size": Vector3(0.3, 0.3, 0.3), "group": "nest_alarm", "fog": 2.5})
		f.on = false
	points.nest_center = Vector3(0, 0, -204)
	scannable(Vector3(0, 0.6, -219), "EGG CLUSTER",
		"Thousands of crawler ova, fused to the platform in a warm membrane.\nThe brood mother is not far.", {"critical": true})


# ===================================================================== backdrop & zones
func build_backdrop() -> void:
	# the chasm walls: a vast lit cylinder far away, fading into haze above
	var wall_mat := StandardMaterial3D.new()
	wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_mat.albedo_texture = load(TEX + "chasm_wall.png")
	wall_mat.albedo_color = Color(0.9, 0.9, 1.0)
	wall_mat.uv1_scale = Vector3(6, 1, 1)
	wall_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	wall_mat.disable_fog = true
	var cyl := CylinderMesh.new(); cyl.top_radius = 700; cyl.bottom_radius = 700; cyl.height = 900; cyl.radial_segments = 48; cyl.cap_top = false; cyl.cap_bottom = false
	var mi := node_mesh(cyl, wall_mat, Vector3(20, 380, -100), null, false)
	# faint rain-haze glow overhead
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(900, 900)
	glow.mesh = q
	glow.material_override = glow_material(Color(0.25, 0.2, 0.4), 1.0, false)
	glow.rotation.x = PI / 2
	glow.position = Vector3(20, 160, -100)
	add_child(glow)


func define_zones() -> void:
	var city := [0.014, Color(0.06, 0.07, 0.12), 1.35, 0.65]
	zones = [
		{"id": "plaza", "box": [-13, -24.5, 13, 1], "amb": "undercity", "rain": true, "moon": 1.0, "mood": city, "title": "UNDERCITY", "sub": "CHASM FLOOR // LEVEL -4000",
			"fog": [Vector3(0, 6, -12), Vector3(24, 12, 24), 0.012, Color(0.7, 0.75, 0.9)], "probe": [Vector3(0, 3, -12), Vector3(24, 14, 24)], "interior": false},
		{"id": "street", "box": [-17, -104.25, 8.5, -24.5], "amb": "undercity", "rain": true, "moon": 1.0, "mood": [0.016, Color(0.08, 0.06, 0.11), 1.35, 0.65], "title": "NIGHT MARKET", "sub": "LOOP STREET",
			"fog": [Vector3(0, 6, -64), Vector3(16, 12, 80), 0.014, Color(0.8, 0.72, 0.85)], "probe": [Vector3(0, 3, -64), Vector3(16, 14, 80)], "interior": false, "checkpoint": {"pos": Vector3(0, 0, -28), "yaw": 0.0}},
		{"id": "gap", "box": [8.5, -80, 64, -40], "amb": "undercity", "rain": true, "moon": 1.0, "mood": [0.01, Color(0.06, 0.07, 0.12), 1.35, 0.65], "title": "THE GAP", "sub": "COLLAPSED OVERPASS",
			"fog": [Vector3(36, -10, -60), Vector3(60, 50, 50), 0.01, Color(0.65, 0.7, 0.9)], "checkpoint": {"pos": Vector3(15, 0, -60), "yaw": -PI / 2}},
		{"id": "station", "box": [-45, -134.25, 15, -104.25], "amb": "subway", "rain": false, "mood": [0.008, Color(0.05, 0.07, 0.09), 1.45, 0.75], "title": "LOOP LINE STATION", "sub": "PLATFORMS 3-4",
			"fog": [Vector3(0, 4, -119), Vector3(28, 9, 29), 0.02, Color(0.8, 0.85, 0.9)], "probe": [Vector3(0, 3, -119), Vector3(28.5, 10.2, 29.5)]},
		{"id": "tunnel", "box": [-3.5, -180.25, 3.5, -134.25], "amb": "subway", "rain": false, "mood": [0.012, Color(0.08, 0.05, 0.04), 1.35, 0.45], "title": "SERVICE TUNNEL 4", "sub": "FLOODED",
			"fog": [Vector3(0, 1.6, -157), Vector3(6, 4.5, 45), 0.04, Color(0.9, 0.8, 0.7)]},
		{"id": "nest", "box": [-23, -225, 23, -180.25], "amb": "subway", "rain": false, "mood": [0.01, Color(0.09, 0.06, 0.04), 1.3, 0.45], "title": "THE NEST", "sub": "PLATFORM 4",
			"fog": [Vector3(0, 3, -202), Vector3(44, 6, 43), 0.02, Color(0.9, 0.75, 0.6)], "probe": [Vector3(0, 4, -195), Vector3(44.5, 18.2, 44)]},
	]


# ===================================================================== script
func script(d) -> void:
	var A = G.audio
	var H = G.hud
	var F: Dictionary = G.progress.flags

	# ---- market ambush: a hound pack spills out of the alleys
	if not F.has("s2_market"):
		d.encounters.market = Director.Encounter.new(d, "market", {
			"start": func(_e):
				A.play3d("crawler_hiss", Vector3(6, 1, -70), 6.0)
				A.play3d("skitter", Vector3(-6, 1, -66), 4.0),
			"first_delay": 0.9,
			"gaps": [2.0],
			"waves": [
				func(e):
					A.stinger("encounter"); A.set_combat(true)
					for p in [Vector3(14, 0, -60), Vector3(0, 0, -86), Vector3(-5, 0, -84), Vector3(5, 0, -90)]:
						e.spawn("hound", p)
					H.hint("Hounds hunt in packs. Keep moving  ·  hold [b]LMB[/b] for an Arc Wave", 6.0),
				func(e):
					e.spawn_later(0.0, "sentinel", Vector3(0, 6, -96), {}, func(s): A.play3d("sentinel_boot", s.global_position, 4.0))
					for i in 3:
						e.spawn_later(0.6 + i * 0.5, "hound", Vector3(-5 + i * 5, 0, -98)),
			],
			"clear": func(_e):
				A.set_combat(false)
				F.s2_market = true
				A.stinger("clear"),
			"reset": func(_e): A.set_combat(false),
		})
		d.trigger([-8, -60, 8, -50], func(): d.encounters.market.begin(), "market")

	# ---- station: crawlers drop through the ceiling vents
	if not F.has("s2_station"):
		var vents: Array = points.station_vents
		d.encounters.station = Director.Encounter.new(d, "station", {
			"start": func(e):
				A.duck(0.2, 0.4)
				e.later(0.4, func():
					set_group("station", "off")
					A.play("lights_out", 0.0)),
			"first_delay": 2.4,
			"waves": [func(e):
				set_group("station", "on")
				A.play("lights_on", -2.0); A.duck(1.0, 1.0)
				A.stinger("encounter"); A.set_combat(true)
				for i in vents.size():
					var v: Vector3 = vents[i]
					e.spawn_later(i * 0.6, "crawler", v, {"drop": true}, func(_c): A.play3d("grate_fall", v, 6.0))
				e.spawn_later(2.0, "hound", Vector3(0, 0, -133))],
			"clear": func(_e):
				A.set_combat(false)
				F.s2_station = true,
			"reset": func(_e):
				set_group("station", "on")
				A.set_combat(false); A.duck(1.0, 0.5),
		})
		d.trigger([-14, -126, 14, -114], func(): d.encounters.station.begin(), "station")

	# ---- tunnel scare
	d.trigger([-3, -160, 3, -150], func():
		A.duck(0.15, 0.3)
		A.stinger("scare")
		set_group("tunnel", "off")
		A.play3d("matriarch_roar", Vector3(0, 2, -200), 0.0)
		d.after(2.2, func():
			set_group("tunnel", "on")
			A.duck(1.0, 2.0)
			A.skitter_path(Vector3(0, 4.6, -175), Vector3(0, 4.6, -140), 1.6, 6.0)))

	# ---- the Nest: Matriarch
	if not G.progress.bosses.has("matriarch"):
		d.encounters.nest = Director.Encounter.new(d, "nest", {
			"start": func(e):
				doors.nest.lock(true)
				A.duck(0.1, 0.5)
				A.set_tension(0.8)
				e.later(1.5, func(): A.play("boss_intro", 0.0))
				e.later(2.0, func():
					set_group("nest_alarm", "on")
					H.area("MATRIARCH", "BROOD QUEEN")),
			"first_delay": 2.5,
			"waves": [func(e):
				var b = e.spawn("matriarch", Vector3(0, 0, -214), {"center": points.nest_center})
				b.facing = 0.0
				H.boss(b, b.boss_name)
				A.set_boss_music(true); A.duck(1.0, 1.0)
				d.after(5.0, func(): H.hint("Bait her charge into a pillar or wall  ·  strike the glowing sac while she's dazed", 7.0))],
			"clear": func(_e):
				A.set_boss_music(false)
				G.progress.bosses.matriarch = true
				d.after(3.0, func():
					set_group("nest_alarm", "off")
					A.stinger("clear")
					H.message("BROOD QUEEN SLAIN", 3.0)
					doors.nest.unlock(false)
					item(Vector3(0, 1.3, -204), "grapple", "ability_grapple")
					d.checkpoint = {"pos": Vector3(0, 0, -186), "yaw": 0.0}),
			"reset": func(_e):
				doors.nest.unlock(false)
				set_group("nest_alarm", "off")
				A.set_boss_music(false); A.duck(1.0, 0.5); A.set_tension(0.0)
				H.boss(null),
		})
		d.trigger([-20, -215, 20, -186], func(): d.encounters.nest.begin(), "nest")
	elif not G.progress.abilities.has("grapple"):
		item(Vector3(0, 1.3, -204), "grapple", "ability_grapple")


func on_enter(d, entry: String, first_time: bool) -> void:
	_update_rain(d)
	if entry == "lift" and first_time:
		d.after(1.5, func(): G.hud.hint("Rain, neon, nobody home  ·  [b]M[/b] opens the sector map", 6.0))


func _update_rain(d) -> void:
	var z = zone_at(G.player.global_position)
	G.fx.set_rain(z != null and z.get("rain", false))


func sector_update(d, _dt: float) -> void:
	_update_rain(d)
