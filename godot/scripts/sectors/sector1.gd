class_name Sector1
extends Level
## Sector 1 — KUROGANE-9 Ring C: arrival bay, maintenance spine, grand concourse,
## service throat, hydroponics vault, descent lift.

var atrium_time := 0.0
var on_lift := 0.0


func build_content() -> void:
	sector_id = "s1"
	sector_name = "RING C"
	build_bay()
	build_corridor()
	build_atrium()
	build_funnel()
	build_arena()
	build_final()
	build_city()
	define_zones()
	build_set_pieces()
	entries = {
		"start": {"pos": points.start, "yaw": 0.0},
		"lift": {"pos": Vector3(34, 0, -139), "yaw": PI},
	}


func define_zones() -> void:
	zones = [
		{"id": "bay", "box": [-6, -12.3, 6, 1], "amb": "bay", "moon": 0.0, "title": "ARRIVAL BAY 03", "sub": "KUROGANE-9 // DOCKING RING C", "probe": [Vector3(0, 2.5, -6), Vector3(10.5, 5.2, 12.5)], "fog": [Vector3(0, 2.5, -6), Vector3(10, 5, 12), 0.022, Color(0.75, 0.82, 0.95)]},
		{"id": "spine", "box": [-2, -41, 2, -12.3], "amb": "corridor", "moon": 0.0, "title": "MAINTENANCE SPINE", "sub": "SUBLEVEL 4", "probe": [Vector3(0, 1.6, -26), Vector3(3.2, 3.4, 28)], "fog": [Vector3(0, 1.6, -26.5), Vector3(3, 3.2, 28), 0.03, Color(0.8, 0.85, 0.9)]},
		{"id": "junction", "box": [2, -41, 14.25, -36.5], "amb": "corridor", "moon": 1.0, "probe": [Vector3(8, 1.6, -38.5), Vector3(12.5, 3.4, 3.2)], "fog": [Vector3(8, 1.6, -38.5), Vector3(12, 3.2, 3), 0.03, Color(0.8, 0.85, 0.9)]},
		{"id": "atrium", "box": [14.25, -70.25, 55, -9], "amb": "atrium", "moon": 1.0, "title": "GRAND CONCOURSE", "sub": "RING C // PUBLIC LEVEL", "probe": [Vector3(42, 3, -46), Vector3(40, 22, 60)], "fog": [Vector3(34, 6, -40), Vector3(39.5, 12, 60), 0.006, Color(0.7, 0.75, 0.95)]},
		{"id": "funnel", "box": [29, -99.75, 39, -70.25], "amb": "funnel", "moon": 0.5, "title": "SERVICE THROAT", "sub": "HYDROPONICS ACCESS", "probe": [Vector3(34, 2, -85), Vector3(8.5, 6, 29.5)], "fog": [Vector3(34, 2.5, -85), Vector3(8, 6, 29), 0.045, Color(0.95, 0.75, 0.8)]},
		{"id": "arena", "box": [19, -132.25, 49, -99.75], "amb": "arena", "moon": 0.0, "title": "HYDROPONICS VAULT", "sub": "CONTAINMENT LEVEL 2", "probe": [Vector3(34, 3, -107), Vector3(28.5, 12.2, 32.5)], "fog": [Vector3(34, 3, -116), Vector3(28, 6, 32), 0.018, Color(0.7, 0.95, 0.8)]},
		{"id": "final", "box": [28, -149, 40, -132.25], "amb": "final", "moon": 0.0, "title": "DESCENT LIFT", "sub": "TO SECTOR 2", "probe": [Vector3(34, 2, -138), Vector3(10.5, 7.2, 16)], "fog": [Vector3(34, 2, -140), Vector3(10, 4, 15.5), 0.018, Color(0.9, 0.8, 0.85)]},
	]

	# per-zone mood: volumetric fog density, fog tint, exposure, ambient energy
	var mood := {
		"bay":      [0.006, Color(0.07, 0.10, 0.14), 1.25, 0.55],
		"spine":    [0.008, Color(0.06, 0.08, 0.11), 1.3,  0.5],
		"junction": [0.008, Color(0.06, 0.08, 0.11), 1.3,  0.5],
		"atrium":   [0.004, Color(0.08, 0.11, 0.17), 1.15, 0.6],
		"funnel":   [0.01,  Color(0.10, 0.05, 0.07), 1.25, 0.45],
		"arena":    [0.006, Color(0.05, 0.09, 0.06), 1.2,  0.45],
		"final":    [0.005, Color(0.08, 0.07, 0.10), 1.15, 0.55],
	}
	var cps := {
		"spine": {"pos": Vector3(0, 0, -14), "yaw": 0.0},
		"atrium": {"pos": Vector3(17, 0, -38.5), "yaw": -PI / 2},
		"funnel": {"pos": Vector3(34, 0, -73), "yaw": 0.0},
		"final": {"pos": Vector3(34, 0, -135), "yaw": 0.0},
	}
	for z in zones:
		z.mood = mood[z.id]
		if cps.has(z.id):
			z.checkpoint = cps[z.id]


func build_bay() -> void:
	room({"x0": -5, "x1": 5, "z0": -12, "z1": 0, "h": 5, "open": {"n": [{"c": 0, "w": 3, "h": 3.5}], "w": [{"c": -5.5, "w": 5, "h": 2.2, "y": 1.3, "glass": true}]}})
	ribs_z(5, -12, 0, 3, 5, -0.3)
	ribs_x(0, -5, 5, 2.5, 5, -0.3)
	var z := -10.5
	while z < 0:
		box(-5, 4.5, z - 0.2, 5, 5, z + 0.2, mats.dark_metal, {"collide": false})
		z += 3
	box(-5.2, 1.1, -8.2, -4.7, 1.3, -2.8, mats.dark_metal, {"collide": false})
	strip(-4.98, 1.32, -8, -4.9, 1.36, -3, mats.cyan_dim)
	z = -1.5
	while z > -11.5:
		strip(-1.6, 0.0, z - 0.25, -1.45, 0.02, z + 0.25, mats.cyan_dim)
		strip(1.45, 0.0, z - 0.25, 1.6, 0.02, z + 0.25, mats.cyan_dim)
		z -= 1.2
	crate(3.6, -2, 1.2); crate(3.9, -3.4, 1.0); crate(3.7, -2.4, 0.8, 1.2)
	crate(-3.8, -10.4, 1.4); crate(-3.5, -9, 0.9)
	console(3.8, -8, -PI / 2, "screen_amber")
	pipe(Vector3(4.6, 0, -11.6), Vector3(4.6, 5, -11.6), 0.14)
	pipe(Vector3(4.3, 0, -11.6), Vector3(4.3, 5, -11.6), 0.09)
	pipe(Vector3(-4.6, 4.2, 0), Vector3(-4.6, 4.2, -12), 0.12)
	for i in 4:
		var g := node_mesh(boxmesh(Vector3(0.05, 1.1, 0.04)), plain(Color(0.02, 0.012, 0.012), 0.9, 0.0), Vector3(-2.2 + i * 0.13, 1.6 - i * 0.05, -11.97), null, false)
		g.rotation.z = 0.35

	# swaying hanging lamp casting moving shadows
	var lamp := Node3D.new()
	lamp.position = Vector3(0, 5, -6)
	add_child(lamp)
	var cord := CylinderMesh.new(); cord.top_radius = 0.01; cord.bottom_radius = 0.01; cord.height = 1.4
	node_mesh(cord, mats.rubber, Vector3(0, -0.7, 0), lamp)
	var shade := CylinderMesh.new(); shade.top_radius = 0.05; shade.bottom_radius = 0.35; shade.height = 0.3; shade.cap_bottom = false
	node_mesh(shade, mats.dark_metal, Vector3(0, -1.5, 0), lamp)
	var bulb_mat := emissive(Color(1, 0.87, 0.67), 4.0)
	var bulb := SphereMesh.new(); bulb.radius = 0.08; bulb.height = 0.16
	node_mesh(bulb, bulb_mat, Vector3(0, -1.6, 0), lamp, false)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, -1.62, 0)
	spot.rotation.x = -PI / 2
	spot.light_color = Color(1, 0.89, 0.75)
	spot.light_energy = 9.0
	spot.spot_range = 14.0
	spot.spot_angle = 50.0
	spot.spot_angle_attenuation = 0.6
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 2.5
	lamp.add_child(spot)
	var state := {"k": 1.0}
	animated.append(func(t, dt):
		var a := sin(t * 0.9) * 0.09 + sin(t * 2.3) * 0.015
		lamp.rotation.z = a
		lamp.rotation.x = sin(t * 0.7) * 0.04
		var flick := 0.1 if randf() < 0.012 else 1.0
		state.k += (flick - state.k) * min(1.0, dt * 25.0)
		spot.light_energy = 9.0 * state.k
		bulb_mat.emission_energy_multiplier = 4.0 * state.k + 0.05)

	# red rotating beacon above the door
	node_mesh(CylinderMesh.new(), mats.red, Vector3(2.2, 4.0, -11.8), null, false).scale = Vector3(0.24, 0.1, 0.24)
	var bspot := SpotLight3D.new()
	bspot.position = Vector3(2.2, 3.95, -11.6)
	bspot.light_color = Color(1, 0.12, 0.18)
	bspot.light_energy = 6.0
	bspot.spot_range = 16.0
	bspot.spot_angle = 22.0
	bspot.light_volumetric_fog_energy = 3.0
	add_child(bspot)
	animated.append(func(t, _dt):
		var a = t * 2.4
		bspot.look_at(Vector3(2.2 + cos(a) * 6.0, 1.0, -11.8 + abs(sin(a)) * 8.0)))
	fixture({"x": -3, "y": 4.85, "z": -2, "color": Color(0.66, 0.78, 1.0), "intensity": 4, "distance": 9, "mode": "broken"})
	fixture({"x": 0, "y": 4.85, "z": -9, "color": Color(0.62, 0.77, 1.0), "intensity": 3, "distance": 8, "mode": "flicker"})

	build_shuttle()
	scannable(Vector3(-6.5, 2.4, -5.5), "KESTREL // PERSONAL SHUTTLE",
		"Your ship. Hull cold, engines idle.\nDocking clamps engaged at 41:12:07, the exact moment the station went silent.\nAutopilot refuses to undock until a manual release is found inside.")
	scannable(Vector3(3.8, 1.3, -8), "DOCKING TERMINAL",
		"MANIFEST // RING C:\n  ARRIVALS (last 72h): 0\n  DEPARTURES: 0\n  PERSONNEL ONSITE: 4,118\n  BIOSIGNS RESPONDING: --\n\nLast entry: \"Maintenance AI requesting quarantine authority. Request... approved?\"")
	scannable(Vector3(-2, 1.6, -11.9), "GOUGE MARKS",
		"Four parallel cuts in tempered alloy, 2cm deep.\nSpacing inconsistent with any registered tool or drone.\nThey were made from this side. Something wanted out.", {"critical": true})
	var d := Door.new(); add_child(d); d.setup(self, Vector3(0, 0, -12.25), "x", 3, 3.5, false); doors.d1 = d
	points.start = Vector3(0, 0, -2.5)


func build_shuttle() -> void:
	var g := Node3D.new()
	g.position = Vector3(-16, 1.5, -5.5)
	g.rotation.y = 0.2
	add_child(g)
	var hull := plain(Color(0.54, 0.56, 0.6), 0.35, 0.8)
	var body := CapsuleMesh.new(); body.radius = 1.6; body.height = 10.2
	var b := node_mesh(body, hull, Vector3.ZERO, g)
	b.rotation.x = PI / 2
	b.scale = Vector3(1.2, 1, 0.6)
	var nose := CylinderMesh.new(); nose.top_radius = 0; nose.bottom_radius = 1.5; nose.height = 3
	var n := node_mesh(nose, hull, Vector3(0, 0, 6), g)
	n.rotation.x = PI / 2
	n.scale = Vector3(1.3, 1, 0.55)
	node_mesh(boxmesh(Vector3(9, 0.15, 2.5)), hull, Vector3(0, -0.3, -1), g)
	var canopy := SphereMesh.new(); canopy.radius = 0.9; canopy.height = 1.8; canopy.is_hemisphere = true
	node_mesh(canopy, emissive(Color(0.1, 0.5, 0.7), 1.2), Vector3(0, 0.6, 3.2), g).scale = Vector3(1, 0.6, 2)
	for s in [-1, 1]:
		var eng := CylinderMesh.new(); eng.top_radius = 0.5; eng.bottom_radius = 0.6; eng.height = 1.5
		node_mesh(eng, emissive(Color(0.15, 0.4, 1.0), 2.0), Vector3(s * 1.3, 0, -5), g).rotation.x = PI / 2
		var nav := SphereMesh.new(); nav.radius = 0.1; nav.height = 0.2
		node_mesh(nav, mats.red if s < 0 else emissive(Color(0.07, 1, 0.13), 3.0), Vector3(s * 4.5, -0.25, -1), g, false)
	node_mesh(boxmesh(Vector3(10, 1.2, 1.4)), mats.dark_metal, Vector3(-10, 2.2, -5.5))
	var flood := OmniLight3D.new()
	flood.position = Vector3(-9, 6, -2)
	flood.light_color = Color(1, 0.95, 0.85)
	flood.light_energy = 4.0
	flood.omni_range = 16.0
	add_child(flood)
	animated.append(func(t, _dt): g.position.y = 1.5 + sin(t * 0.4) * 0.05)


func build_corridor() -> void:
	room({"x0": -1.5, "x1": 1.5, "z0": -40, "z1": -12.5, "h": 3.2, "walls": {"s": false}, "open": {"e": [{"c": -38.5, "w": 3, "h": 3.2}]}, "wall": mats.wall_dark})
	ribs_z(-1.5, -40, -12.5, 2.4, 3.2, 0.22)
	ribs_z(1.5, -40, -12.5, 2.4, 3.2, -0.22, [[-40, -37]])
	var z := -13.7
	while z > -40:
		box(-1.5, 2.95, z - 0.18, 1.5, 3.2, z + 0.18, mats.dark_metal, {"collide": false})
		z -= 2.4
	pipe(Vector3(-1.15, 2.75, -12.5), Vector3(-1.15, 2.75, -40), 0.12)
	pipe(Vector3(-1.2, 2.45, -12.5), Vector3(-1.2, 2.45, -40), 0.07, mats.dark_metal)
	pipe(Vector3(1.15, 2.7, -12.5), Vector3(1.15, 2.7, -36.6), 0.1)
	cable(Vector3(-1.2, 3.1, -16), Vector3(1.2, 3.1, -19), 0.7)
	cable(Vector3(1.2, 3.1, -26), Vector3(-0.8, 3.1, -28), 1.0)
	cable(Vector3(-1.2, 3.1, -33), Vector3(1.0, 3.1, -34.5), 0.5)
	strip(-1.5, 0, -40, -1.42, 0.03, -12.5, mats.cyan_dim)
	strip(1.42, 0, -36.8, 1.5, 0.03, -12.5, mats.cyan_dim)
	var modes := ["steady", "flicker", "steady", "flicker", "broken", "steady"]
	var zs := [-15, -20, -25, -30, -35, -38.5]
	for i in zs.size():
		fixture({"x": 0, "y": 3.12, "z": zs[i], "intensity": 5, "distance": 8, "mode": modes[i], "group": "spine", "size": Vector3(0.25, 0.06, 1.4), "shadow": true})
	vent_grate(0, 3.15, -24)
	screen(Vector3(-1.27, 1.6, -18), PI / 2, 0.9, 0.55, "screen_cyan")
	scannable(Vector3(-1.27, 1.6, -18), "MAINTENANCE LOG // SPINE 4",
		"Day 1: Pressure anomalies in ducting. Bio-residue in filters, violet, luminous.\nDay 3: Something is nesting in the vents. The AI says it is \"growth.\" It says it is \"beautiful.\"\nDay 4: We sealed the ducts. We heard it walking above us all night.")
	var panel := node_mesh(boxmesh(Vector3(0.8, 0.6, 0.04)), mats.wall_dark, Vector3(1.15, 2.4, -31))
	panel.rotation = Vector3(0.2, -1.2, 0.5)
	points.spark = Vector3(1.3, 2.6, -31)

	# junction C
	room({"x0": 2, "x1": 14, "z0": -40, "z1": -37, "h": 3.2, "walls": {"w": false, "e": false}, "wall": mats.wall_dark})
	var x := 3.5
	while x < 14:
		box(x - 0.18, 2.95, -40, x + 0.18, 3.2, -37, mats.dark_metal, {"collide": false})
		x += 2.4
	pipe(Vector3(2, 2.75, -39.6), Vector3(14, 2.75, -39.6), 0.12)
	fixture({"x": 9, "y": 3.12, "z": -38.5, "intensity": 4, "distance": 8, "mode": "flicker", "group": "junction", "size": Vector3(1.4, 0.06, 0.25), "shadow": true})
	vent_grate(6, 3.15, -38.5)
	points.junction_vent = Vector3(6, 3.0, -38.5)
	strip(2, 0, -37.08, 14, 0.03, -37, mats.cyan_dim)


func build_atrium() -> void:
	var X0 := 14.5; var X1 := 54.0; var Z0 := -70.0; var Z1 := -10.0; var H := 22.0
	var rnd := RandomNumberGenerator.new(); rnd.seed = 42
	room({"x0": X0, "x1": X1, "z0": Z0, "z1": Z1, "h": H, "wall": mats.wall, "open": {
		"w": [{"c": -38.5, "w": 3, "h": 3}], "n": [{"c": 34, "w": 4, "h": 4}], "e": [{"c": -40, "w": 56, "h": 18, "y": 1.5, "glass": true}]}})
	var d2 := Door.new(); add_child(d2); d2.setup(self, Vector3(14.25, 0, -38.5), "z", 3, 3, false); doors.d2 = d2
	var d3 := Door.new(); add_child(d3); d3.setup(self, Vector3(34, 0, -70.25), "x", 4, 4, false); doors.d3 = d3
	ribs_z(X0, Z0, Z1, 6, H, 0.6, [[-40.5, -36.5]])
	ribs_x(Z0, X0, X1, 6, H, 0.6, [[31.5, 36.5]])
	ribs_x(Z1, X0, X1, 6, H, -0.6)
	var z := Z0 + 6
	while z < Z1:
		box(X0, H - 1.2, z - 0.4, X1, H, z + 0.4, mats.dark_metal, {"collide": false, "uv": 2.0})
		z += 6
	z = -68
	while z <= -12:
		box(53.6, 1.5, z - 0.25, 54.2, 19.5, z + 0.25, mats.dark_metal, {"uv": 1.0})
		z += 7
	for y in [7.5, 13.5]:
		box(53.7, y - 0.15, -68, 54.1, y + 0.15, -12, mats.dark_metal, {"collide": false, "uv": 1.0})
	strip(53.5, 1.45, -68, 53.65, 1.52, -12, mats.cyan_dim)
	for cx in [24, 44]:
		for cz in [-22, -58]:
			column(cx, cz, H)
	build_core(34, -40, H)
	var cy := 8.0
	box(X0, cy - 0.25, Z0, X1 - 0.5, cy, Z0 + 2.5, mats.dark_metal, {"uv": 2.0})
	var rx := X0 + 1
	while rx < X1:
		box(rx - 0.03, cy, Z0 + 2.45, rx + 0.03, cy + 1.1, Z0 + 2.5, mats.dark_metal, {"collide": false})
		rx += 1.2
	box(X0, cy + 1.05, Z0 + 2.42, X1 - 0.5, cy + 1.12, Z0 + 2.52, mats.dark_metal, {"collide": false})
	strip(X0, cy - 0.27, Z0 + 2.45, X1 - 0.5, cy - 0.22, Z0 + 2.52, mats.cyan_dim)
	# energy tank on the north catwalk: reachable with the Kusari Grapple (return trip)
	grapple_point(Vector3(40, 12.0, -68.6))
	item(Vector3(44, 8.9, -68.8), "tank", "s1_tank_catwalk")
	points.sentinel_a = Vector3(X0 + 1.4, 11, -52)
	points.sentinel_b = Vector3(30, 12.5, Z1 - 1.4)
	for p in [points.sentinel_a, points.sentinel_b]:
		var tm := TorusMesh.new(); tm.inner_radius = 0.88; tm.outer_radius = 1.12
		var cr := node_mesh(tm, mats.dark_metal, p - Vector3(0, 0.9, 0))
		cr.scale = Vector3(1, 0.5, 1)
	for t in [[47, -16], [48, -30], [47, -50], [48.5, -63]]:
		dead_tree(t[0], t[1], rnd)
	for i in 16:
		var x := X0 + 3 + rnd.randf() * (X1 - X0 - 9)
		var zz := Z0 + 4 + rnd.randf() * (Z1 - Z0 - 8)
		if Vector2(x - 34, zz + 40).length() < 7 or (abs(x - 34) < 2.5 and zz < -60):
			continue
		crate(x, zz, rnd.randf_range(0.5, 1.4))
	for bz in [-30, -50]:
		box(28, 0, bz - 0.3, 31, 0.45, bz + 0.3, mats.dark_metal, {"uv": 1.0})
		box(37, 0, bz - 0.3, 40, 0.45, bz + 0.3, mats.dark_metal, {"uv": 1.0})
	for b in [[20.0, -64.0, "neon_pink"], [48.0, -64.0, "neon_cyan"], [20.0, -16.0, "neon_amber"]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.05, 0.05)
		m.emission_enabled = true
		m.emission_texture = load(TEX + b[2] + ".png")
		m.emission_energy_multiplier = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var qm := QuadMesh.new(); qm.size = Vector2(9, 3)
		var ban := node_mesh(qm, m, Vector3(b[0], 15, b[1]), null, false)
		ban.rotation = Vector3(0, PI / 2 if b[0] < 30 else -PI / 2, PI / 2)
		var bx: float = b[0]
		animated.append(func(t, _dt): ban.rotation.x = sin(t * 0.3 + bx) * 0.03)
	for i in 18:
		var k := i / 17.0
		var x = 16.5 + (34 - 16.5) * min(1.0, k * 1.6)
		var pz := -38.5 + ((-68 + 38.5) * ((k - 0.6) / 0.4) if k > 0.6 else 0.0)
		if Vector2(x - 34, pz + 40).length() < 5.5:
			continue
		strip(x - 0.15, 0, pz - 0.15, x + 0.15, 0.02, pz + 0.15, mats.cyan_dim)
	points.atrium_center = Vector3(34, 0, -40)
	fixture({"x": 18, "y": 6, "z": -38.5, "color": Color(0.62, 0.85, 1.0), "intensity": 6, "distance": 12, "mode": "flicker", "size": Vector3(0.3, 0.6, 0.1)})
	fixture({"x": 34, "y": 6, "z": -67.6, "color": Color(1.0, 0.6, 0.31), "intensity": 6, "distance": 12, "size": Vector3(2.0, 0.08, 0.2)})
	for sz in [-20, -32, -44, -56]:
		fixture({"x": 15.0, "y": 4.5, "z": sz, "color": Color(1.0, 0.69, 0.44), "intensity": 3.5, "distance": 9, "size": Vector3(0.08, 0.6, 0.3)})
	for cx in [24, 44]:
		for cz in [-22, -58]:
			fixture({"x": cx + (1.9 if cx < 34 else -1.9), "y": 0.05, "z": cz, "color": Color(0.35, 0.9, 1.0), "intensity": 5, "distance": 10, "size": Vector3(0.4, 0.05, 0.4), "light_y": 0.35})
	var shell := SphereMesh.new(); shell.radius = 0.7; shell.height = 1.4; shell.is_hemisphere = true
	node_mesh(shell, mats.dark_metal, Vector3(26, 0.5, -46)).rotation = Vector3(1, 0.5, 0.3)
	scannable(Vector3(26, 0.6, -46), "SENTINEL DRONE // INERT",
		"Security drone, model SN-7. Core punctured from inside.\nViolet filaments threaded through its optic array, still faintly warm.\nOthers of its kind remain active. Their firmware has been revised.\nPlasma bolts can be returned with a well-timed guard [RMB] or strike.")
	var body := Node3D.new(); body.position = Vector3(41, 0, -33); body.rotation.y = 0.8; add_child(body)
	node_mesh(boxmesh(Vector3(0.5, 0.25, 1.6)), plain(Color(0.14, 0.15, 0.18), 0.8, 0.1), Vector3(0, 0.13, 0), body)
	var helm := SphereMesh.new(); helm.radius = 0.2; helm.height = 0.4
	node_mesh(helm, plain(Color(0.23, 0.25, 0.28), 0.3, 0.6), Vector3(0, 0.18, -0.95), body)
	bloom_growth(41.3, 0.2, -33.4, 0.3, rnd)
	scannable(Vector3(41, 0.4, -33), "REMAINS // SEC. OFFICER K. ADEYEMI",
		"Biosign: none. Time of death ~38 hours.\nSidearm discharged 14 times. No targets recovered.\nFinal audio log: \"It's not on the scanner, it's IN the scanner. Switch visors, you can see it with the-\"", {"critical": true})
	scannable(Vector3(53, 6, -40), "KUROGANE-9 // INNER CHASM",
		"The arcology's hollow heart: 11 km of vertical city around a central void.\nPopulation at census: 2.3 million.\nGrid power appears intact. No traffic control chatter on any band.\nThe lights are on. No one is home.")
	scannable(Vector3(34, 2, -40), "CONCOURSE CORE // DORMANT",
		"Atmospheric regulator for Ring C. Output: 3%.\nSomething has been feeding on its power conduits.\nTrace residue leads north, toward Hydroponics.")


func column(x: float, z: float, H: float) -> void:
	var c := CylinderMesh.new(); c.top_radius = 1.25; c.bottom_radius = 1.4; c.height = H; c.radial_segments = 24
	builder.mesh(c, Transform3D(Basis(), Vector3(x, H / 2, z)), mats.wall)
	for y in [0.4, H - 1]:
		var r := CylinderMesh.new(); r.top_radius = 1.7; r.bottom_radius = 1.7; r.height = 0.8; r.radial_segments = 24
		builder.mesh(r, Transform3D(Basis(), Vector3(x, y, z)), mats.dark_metal)
	for i in 4:
		var a := i * PI / 2 + PI / 4
		var fin := BoxMesh.new(); fin.size = Vector3(0.25, H, 0.5)
		builder.mesh(fin, Transform3D(Basis(Vector3.UP, -a), Vector3(x + cos(a) * 1.35, H / 2, z + sin(a) * 1.35)), mats.dark_metal)
	var g := CylinderMesh.new(); g.top_radius = 1.42; g.bottom_radius = 1.42; g.height = 0.06; g.radial_segments = 24
	builder.mesh(g, Transform3D(Basis(), Vector3(x, 2.8, z)), mats.cyan_dim, false)
	collider(x - 1.6, 0, z - 1.6, x + 1.6, H, z + 1.6)


func build_core(x: float, z: float, H: float) -> void:
	for tier in [[5.0, 0.3], [3.4, 0.6]]:
		var r: float = tier[0]; var y: float = tier[1]
		var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = 0.3; c.radial_segments = 48
		builder.mesh(c, Transform3D(Basis(), Vector3(x, y - 0.15, z)), mats.dark_metal)
		var s := r * 0.7
		collider(x - s, 0, z - s, x + s, y, z + s)
		var tm := TorusMesh.new(); tm.inner_radius = r - 0.03; tm.outer_radius = r + 0.03; tm.rings = 64
		builder.mesh(tm, Transform3D(Basis(), Vector3(x, y + 0.01, z)), mats.cyan_dim, false)
	var core_mat := pbr("wall_dark", 0.85, 1.0, Color(0.3, 0.29, 0.36))
	core_mat.uv1_scale = Vector3(2, 7, 1)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.3, 0.1, 0.65)
	core_mat.emission_energy_multiplier = 0.2
	var col := CylinderMesh.new(); col.top_radius = 1.1; col.bottom_radius = 1.1; col.height = H; col.radial_segments = 32
	node_mesh(col, core_mat, Vector3(x, H / 2, z))
	collider(x - 1.2, 0, z - 1.2, x + 1.2, H, z + 1.2)
	var y := 1.5
	while y < H:
		var band := CylinderMesh.new(); band.top_radius = 1.13; band.bottom_radius = 1.13; band.height = 0.06; band.radial_segments = 32
		builder.mesh(band, Transform3D(Basis(), Vector3(x, y, z)), mats.purple, false)
		y += 2.4
	var rings: Array[MeshInstance3D] = []
	for ry in [[3.2, 2.2], [6.5, 2.8], [10.5, 2.4]]:
		var tm := TorusMesh.new(); tm.inner_radius = ry[1] - 0.09; tm.outer_radius = ry[1] + 0.09; tm.rings = 64
		var ring := node_mesh(tm, mats.purple, Vector3(x, ry[0], z), null, false)
		ring.rotation.x = randf_range(-0.1, 0.1)
		rings.append(ring)
	animated.append(func(t, _dt):
		for i in rings.size():
			rings[i].rotation.y = t * (0.05 + i * 0.03) * (-1 if i % 2 else 1)
		core_mat.emission_energy_multiplier = 0.2 + sin(t * 0.6) * 0.08)
	fixture({"x": x, "y": 3.5, "z": z + 3.2, "color": Color(0.63, 0.38, 1.0), "intensity": 4, "distance": 12, "mode": "pulse", "mesh": false, "speed": 0.6})


func dead_tree(x: float, z: float, rnd: RandomNumberGenerator) -> void:
	var mat := plain(Color(0.055, 0.05, 0.047), 0.95, 0.0)
	box(x - 1.2, 0, z - 1.2, x + 1.2, 0.7, z + 1.2, mats.dark_metal, {"uv": 1.0})
	var branch := func(self_ref: Callable, p: Vector3, dir: Vector3, length: float, rad: float, depth: int) -> void:
		var end := p + dir * length
		var cm := CylinderMesh.new(); cm.top_radius = rad * 0.6; cm.bottom_radius = rad; cm.height = length; cm.radial_segments = 5; cm.rings = 1
		builder.mesh(cm, cyl_xform(p, end), mat)
		if depth <= 0:
			return
		for i in 2 + (1 if rnd.randf() < 0.4 else 0):
			var d := (dir + Vector3(rnd.randf_range(-0.7, 0.7), rnd.randf() * 0.4, rnd.randf_range(-0.7, 0.7))).normalized()
			self_ref.call(self_ref, end, d, length * rnd.randf_range(0.6, 0.8), rad * 0.6, depth - 1)
	branch.call(branch, Vector3(x, 0.7, z), Vector3.UP, 2.6, 0.22, 4)


func build_funnel() -> void:
	var rnd := RandomNumberGenerator.new(); rnd.seed = 77
	room({"x0": 30, "x1": 38, "z0": -80, "z1": -70.5, "h": 6, "walls": {"s": false}, "open": {"n": [{"c": 34, "w": 5, "h": 4.5}]}, "wall": mats.wall_dark})
	room({"x0": 31.5, "x1": 36.5, "z0": -90, "z1": -80.5, "h": 4.5, "walls": {"s": false}, "open": {"n": [{"c": 34, "w": 2.5, "h": 3}]}, "wall": mats.wall_dark})
	room({"x0": 32.75, "x1": 35.25, "z0": -99.5, "z1": -90.5, "h": 3, "walls": {"s": false, "n": false}, "wall": mats.wall_dark})
	ribs_z(30, -80, -70.5, 2, 6, 0.25); ribs_z(38, -80, -70.5, 2, 6, -0.25)
	ribs_z(31.5, -90, -80.5, 1.8, 4.5, 0.2); ribs_z(36.5, -90, -80.5, 1.8, 4.5, -0.2)
	var reds := [[-75, 5.9], [-85, 4.4], [-93, 2.92], [-97.5, 2.92]]
	for i in reds.size():
		fixture({"x": 34, "y": reds[i][1], "z": reds[i][0], "color": Color(1.0, 0.16, 0.16), "intensity": 5, "distance": 9, "mode": "pulse", "size": Vector3(0.5, 0.06, 0.5), "group": "funnel", "speed": 1.3 + i * 0.5, "fog": 2.5})
	for i in 46:
		var k := i / 46.0
		var z := -72 - k * 27
		var half_w := 4.0 if z > -80 else (2.5 if z > -90 else 1.25)
		var hgt := 6.0 if z > -80 else (4.5 if z > -90 else 3.0)
		if rnd.randf() > 0.3 + k * 0.7:
			continue
		var side := -1 if rnd.randf() < 0.5 else 1
		var on_ceil := rnd.randf() < 0.35
		var x := 34 + rnd.randf_range(-0.8, 0.8) * half_w if on_ceil else 34 + side * (half_w - 0.05)
		var y := hgt - 0.05 if on_ceil else rnd.randf_range(0.3, 0.3 + hgt * 0.8)
		bloom_growth(x, y, z, 0.15 + k * 0.35, rnd)
	tendril([Vector3(32.8, 3, -92), Vector3(33.5, 2.9, -95), Vector3(33.2, 2.95, -99)], 0.07)
	tendril([Vector3(35.2, 0.1, -91), Vector3(35.18, 1.2, -94), Vector3(35.2, 2.6, -98)], 0.06)
	tendril([Vector3(31.6, 4.4, -82), Vector3(33, 4.45, -86), Vector3(36.3, 4.4, -89)], 0.08)
	points.funnel_glimpse = Vector3(34, 0, -97.5)
	scannable(Vector3(36.2, 2.2, -86), "THE BLOOM",
		"Organic lattice. Self-luminous. Grows along power conduits at 30cm/hour.\nNeural-analog structures detected inside each nodule.\nIt is not merely growing. It is listening.", {"critical": true})


func build_arena() -> void:
	var X0 := 20.0; var X1 := 48.0; var Z0 := -132.0; var Z1 := -100.0; var H := 12.0
	room({"x0": X0, "x1": X1, "z0": Z0, "z1": Z1, "h": H, "open": {"s": [{"c": 34, "w": 2.5, "h": 3}], "n": [{"c": 34, "w": 3, "h": 3.5}]}})
	var d4 := Door.new(); add_child(d4); d4.setup(self, Vector3(34, 0, -99.75), "x", 2.5, 3, false); doors.d4 = d4
	var d5 := Door.new(); add_child(d5); d5.setup(self, Vector3(34, 0, -132.25), "x", 3, 3.5, true); doors.d5 = d5
	ribs_z(X0, Z0, Z1, 4, H, 0.4); ribs_z(X1, Z0, Z1, 4, H, -0.4)
	ribs_x(Z0, X0, X1, 4, H, 0.4, [[32.5, 35.5]]); ribs_x(Z1, X0, X1, 4, H, -0.4, [[32.7, 35.3]])
	var z := Z0 + 4
	while z < Z1:
		box(X0, H - 0.8, z - 0.25, X1, H, z + 0.25, mats.dark_metal, {"collide": false, "uv": 2.0})
		z += 4
	for p in [[27, -109], [41, -109], [27, -123], [41, -123]]:
		box(p[0] - 1, 0, p[1] - 1, p[0] + 1, H, p[1] + 1, mats.wall_dark, {"uv": 2.0})
		strip(p[0] - 1.02, 2.5, p[1] - 1.02, p[0] + 1.02, 2.56, p[1] + 1.02, mats.cyan_dim)
	var tank_mat := StandardMaterial3D.new()
	tank_mat.albedo_color = Color(0.4, 1.0, 0.67, 0.1)
	tank_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tank_mat.roughness = 0.05
	tank_mat.metallic = 0.5
	tank_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tank := CylinderMesh.new(); tank.top_radius = 2; tank.bottom_radius = 2; tank.height = 6; tank.cap_top = false; tank.cap_bottom = false; tank.radial_segments = 32
	node_mesh(tank, tank_mat, Vector3(34, 3.6, -116), null, false)
	var liquid_mat := StandardMaterial3D.new()
	liquid_mat.albedo_color = Color(0.0, 0.03, 0.015)
	liquid_mat.roughness = 0.1
	liquid_mat.emission_enabled = true
	liquid_mat.emission = Color(0.03, 0.35, 0.15)
	liquid_mat.emission_energy_multiplier = 0.8
	var liquid := CylinderMesh.new(); liquid.top_radius = 1.9; liquid.bottom_radius = 1.9; liquid.height = 5.4; liquid.radial_segments = 32
	node_mesh(liquid, liquid_mat, Vector3(34, 3.4, -116), null, false)
	for y in [0.3, 6.8]:
		var cap := CylinderMesh.new(); cap.top_radius = 2.3; cap.bottom_radius = 2.3; cap.height = 0.6; cap.radial_segments = 32
		builder.mesh(cap, Transform3D(Basis(), Vector3(34, y, -116)), mats.dark_metal)
	var spec := Node3D.new(); spec.position = Vector3(34, 3.4, -116); add_child(spec)
	var sb := CapsuleMesh.new(); sb.radius = 0.35; sb.height = 2.1
	node_mesh(sb, mats.bloom_flesh, Vector3.ZERO, spec)
	for i in 4:
		var arm := CapsuleMesh.new(); arm.radius = 0.07; arm.height = 1.34
		node_mesh(arm, mats.bloom_flesh, Vector3(cos(i * 1.6) * 0.4, -0.3 + i * 0.1, sin(i * 1.6) * 0.4), spec).rotation.z = 0.6 * (1 if i % 2 else -1)
	var eye := SphereMesh.new(); eye.radius = 0.08; eye.height = 0.16
	node_mesh(eye, mats.purple, Vector3(0, 0.6, 0.3), spec, false)
	var tank_light := OmniLight3D.new(); tank_light.position = Vector3(34, 3.5, -116); tank_light.light_color = Color(0.2, 1.0, 0.5); tank_light.light_energy = 1.5; tank_light.omni_range = 8
	add_child(tank_light)
	animated.append(func(t, _dt):
		spec.rotation.y = t * 0.1
		spec.position.y = 3.4 + sin(t * 0.4) * 0.15)
	collider(31.7, 0, -118.3, 36.3, 7, -113.7)
	scannable(Vector3(34, 3.4, -116), "SPECIMEN TANK 7",
		"Contents: Bloom progenitor organism, catalogued \"BENIGN\".\nTank integrity nominal. The specimen is facing you.\nIt has been facing you since you entered.", {"critical": true})
	for x in [23, 45]:
		for pz in [-104, -116, -128]:
			box(x - 1.4, 0, pz - 2.2, x + 1.4, 0.9, pz + 2.2, mats.dark_metal, {"uv": 1.0})
			strip(x - 1.2, 0.9, pz - 2, x + 1.2, 0.93, pz + 2, mats.green_dim)
	points.arena_vents = []
	for v in [[24, -106], [44, -106], [24, -126], [44, -126], [30, -112], [38, -120]]:
		vent_grate(v[0], H - 0.02, v[1])
		points.arena_vents.append(Vector3(v[0], H - 0.5, v[1]))
	points.arena_sentinels = [Vector3(X0 + 1.5, 8, -116), Vector3(X1 - 1.5, 8, -116)]
	points.stalker_spawn = Vector3(34, 0, -129)
	points.arena_center = Vector3(34, 0, -116)
	for p in [[27, -104], [41, -104], [27, -128], [41, -128], [34, -108], [34, -124]]:
		fixture({"x": p[0], "y": H - 0.05, "z": p[1], "color": Color(0.36, 1.0, 0.6), "intensity": 6, "distance": 14, "mode": "flicker" if (p[0] == 41 and p[1] == -128) else "steady", "size": Vector3(3, 0.08, 0.5), "group": "arena", "shadow": p[0] == 34})
	for p in [[20.4, -110], [47.6, -122], [34, -131.6], [34, -100.4]]:
		var f := fixture({"x": p[0], "y": 9, "z": p[1], "color": Color(1.0, 0.06, 0.12), "intensity": 9, "distance": 18, "mode": "emergency", "size": Vector3(0.3, 0.3, 0.3), "group": "alarm", "fog": 3.0})
		f.on = false


func build_final() -> void:
	room({"x0": 29, "x1": 39, "z0": -148, "z1": -132.5, "h": 7, "walls": {"s": false}, "open": {"n": [{"c": 34, "w": 8, "h": 4.5, "y": 1.2, "glass": true}], "w": [{"c": -137, "w": 2.5, "h": 3}]}})
	# phase-sealed maintenance nook (ki shard)
	room({"x0": 25, "x1": 28.5, "z0": -139.5, "z1": -134.5, "h": 3.5, "walls": {"e": false}})
	phase_barrier(28.55, 0, -138.25, 28.95, 3, -135.75)
	item(Vector3(26.5, 1.0, -137), "shard", "s1_shard_nook")
	ribs_z(29, -148, -132.5, 2.5, 7, 0.3); ribs_z(39, -148, -132.5, 2.5, 7, -0.3)
	var pad := CylinderMesh.new(); pad.top_radius = 2.6; pad.bottom_radius = 2.6; pad.height = 0.2; pad.radial_segments = 48
	builder.mesh(pad, Transform3D(Basis(), Vector3(34, 0.1, -141.5)), mats.dark_metal, false)
	collider(32.2, 0, -143.3, 35.8, 0.2, -139.7)
	lift_ring_mat = emissive(Color(1, 0.5, 0.08), 2.4)
	var tm := TorusMesh.new(); tm.inner_radius = 2.45; tm.outer_radius = 2.55; tm.rings = 64
	node_mesh(tm, lift_ring_mat, Vector3(34, 0.22, -141.5), null, false)
	console(36.8, -145.5, PI * 0.8, "screen_amber")
	fixture({"x": 34, "y": 6.9, "z": -141.5, "color": Color(1.0, 0.75, 0.44), "intensity": 7, "distance": 12, "size": Vector3(1, 0.08, 1), "group": "final", "shadow": true})
	fixture({"x": 34, "y": 2.9, "z": -132.8, "color": Color(1.0, 0.69, 0.38), "intensity": 3, "distance": 7, "group": "final"})
	var glow := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(120, 120)
	glow.mesh = qm
	var gm := glow_material(Color(1.2, 0.2, 2.2), 1.0)
	glow.material_override = gm
	glow.position = Vector3(34, -60, -190)
	add_child(glow)
	animated.append(func(t, _dt): gm.set_shader_parameter("color", Color(1.0 + sin(t * 0.5) * 0.3, 0.2, 2.0 + sin(t * 0.5) * 0.5)))
	for i in 10:
		node_mesh(boxmesh(Vector3(randf_range(2, 8), 120, randf_range(2, 8))), mats.dark_metal, Vector3(34 + randf_range(-40, 40), -50, -170 - randf() * 60))
	points.lift_center = Vector3(34, 0, -141.5)
	scannable(Vector3(36.8, 1.3, -145.5), "LIFT CONTROL // DESCENT TO SECTOR 2",
		"Destination: Inner Chasm, Level -4,000. \"Bloom Heart.\"\nThe station AI left one message on loop:\n\"KAGE OPERATIVE. YOU WERE NOT INVITED. COME DOWN ANYWAY.\"\n\nStep onto the lift to descend.", {"critical": true})


func build_city() -> void:
	var rnd := RandomNumberGenerator.new(); rnd.seed = 1234
	var city := Node3D.new(); city.name = "City"; add_child(city)
	var groups := {}
	for i in 10:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = load(TEX + "windows_%d.png" % i)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(1.0 / 18.0, 1.0 / 70.0, 1.0 / 18.0)
		m.vertex_color_use_as_albedo = true
		m.disable_fog = true
		groups[i] = {"mat": m, "xf": [], "col": []}
	var beacon_mat := glow_material(Color(3, 0.2, 0.2), 1.0)
	for i in 110:
		var x := 80 + pow(rnd.randf(), 0.8) * 700
		var z := -40 + rnd.randf_range(-0.5, 0.5) * 1100
		var w := rnd.randf_range(14, 59); var d := rnd.randf_range(14, 59)
		var top := -60 + rnd.randf() * rnd.randf() * 260
		var bottom := -700.0
		var h := top - bottom
		var dist := Vector2(x - 54, z + 40).length()
		var k := 1.25 * exp(-dist / 520.0)
		var gi := rnd.randi() % 10
		groups[gi].xf.append(Transform3D(Basis().scaled(Vector3(w, h, d)), Vector3(x, bottom + h / 2, z)))
		groups[gi].col.append(Color(k, k, k * 1.1))
		if rnd.randf() < 0.5:
			var b := MeshInstance3D.new()
			var q := QuadMesh.new(); q.size = Vector2.ONE * (6 + dist * 0.01)
			b.mesh = q
			b.material_override = beacon_mat
			b.position = Vector3(x, top + 3, z)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			city.add_child(b)
			var ph := rnd.randf() * 6
			animated.append(func(t, _dt): b.visible = fmod(t + ph, 2.2) < 0.25)
		if rnd.randf() < 0.3 and top > -40:
			var cols := ["neon_pink", "neon_cyan", "neon_amber", "neon_violet"]
			var nm := StandardMaterial3D.new()
			nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			nm.albedo_texture = load(TEX + cols[rnd.randi() % 4] + ".png")
			nm.albedo_color = Color(1.8, 1.8, 1.8)
			nm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			nm.disable_fog = true
			nm.cull_mode = BaseMaterial3D.CULL_DISABLED
			var sq := QuadMesh.new(); sq.size = Vector2(w * 0.8, w * 0.2)
			var sign := MeshInstance3D.new()
			sign.mesh = sq
			sign.material_override = nm
			sign.position = Vector3(x - w / 2 - 0.5, top - 10 - rnd.randf() * 30, z)
			sign.rotation.y = -PI / 2
			sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			city.add_child(sign)
			if rnd.randf() < 0.4:
				var ph2 := rnd.randf() * 9
				animated.append(func(t, _dt): sign.visible = sin(t * 13 + ph2) > -0.7 or fmod(t + ph2, 5.0) > 0.3)
	var cube := BoxMesh.new()
	for gi in groups:
		var grp: Dictionary = groups[gi]
		if grp.xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = cube
		mm.instance_count = grp.xf.size()
		for j in grp.xf.size():
			mm.set_instance_transform(j, grp.xf[j])
			mm.set_instance_color(j, grp.col[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = grp.mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city.add_child(mmi)
	# haze layers glowing up from below
	for layer in [[-80.0, Color(0.6, 0.15, 0.5), 0.35], [-180.0, Color(0.2, 0.35, 0.7), 0.45], [-320.0, Color(0.5, 0.2, 0.6), 0.6]]:
		for i in 8:
			var hz := MeshInstance3D.new()
			var q := QuadMesh.new(); q.size = Vector2(900, 900)
			hz.mesh = q
			hz.material_override = glow_material(layer[1] * layer[2], 1.0, false)
			hz.rotation.x = -PI / 2
			hz.position = Vector3(350 + rnd.randf_range(-300, 300), layer[0] + rnd.randf_range(-15, 15), -40 + rnd.randf_range(-450, 450))
			hz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			city.add_child(hz)
	# flying traffic
	var lane_mm := MultiMesh.new()
	lane_mm.transform_format = MultiMesh.TRANSFORM_3D
	lane_mm.use_colors = true
	var lq := QuadMesh.new(); lq.size = Vector2(2.5, 2.5)
	lane_mm.mesh = lq
	var lanes := []
	for ln in [[110, -10, 22, Color(3, 2.2, 1)], [150, 25, -30, Color(1, 2, 3)], [230, -40, 18, Color(3, 0.6, 1.6)], [320, 60, -25, Color(2.5, 2.5, 2.5)], [180, -90, 28, Color(1, 2.5, 3)]]:
		for i in 14:
			lanes.append({"x": ln[0] + rnd.randf_range(-4, 4), "y": ln[1] + rnd.randf_range(-2, 2), "z": rnd.randf_range(-600, 600), "speed": ln[2] * rnd.randf_range(0.8, 1.2), "col": ln[3]})
	lane_mm.instance_count = lanes.size()
	for j in lanes.size():
		lane_mm.set_instance_color(j, lanes[j].col)
	var lane_mat := ShaderMaterial.new()
	lane_mat.shader = glow_shader
	lane_mat.set_shader_parameter("tex", glow_tex)
	lane_mat.set_shader_parameter("color", Color.WHITE)
	lane_mat.set_shader_parameter("gain", 1.0)
	var lane_node := MultiMeshInstance3D.new()
	lane_node.multimesh = lane_mm
	lane_node.material_override = lane_mat
	lane_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lane_node.custom_aabb = AABB(Vector3(0, -200, -700), Vector3(500, 400, 1400))
	city.add_child(lane_node)
	animated.append(func(_t, dt):
		for j in lanes.size():
			var l: Dictionary = lanes[j]
			l.z += l.speed * dt
			if l.z > 600: l.z -= 1200
			if l.z < -600: l.z += 1200
			lane_mm.set_instance_transform(j, Transform3D(Basis(), Vector3(l.x, l.y, l.z))))
	# planet + halo
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_texture = load(TEX + "planet.png")
	pm.albedo_color = Color(0.55, 0.6, 0.75)
	pm.disable_fog = true
	var sphere := SphereMesh.new(); sphere.radius = 260; sphere.height = 520; sphere.radial_segments = 64; sphere.rings = 32
	var planet := node_mesh(sphere, pm, Vector3(1000, 620, -700), null, false)
	planet.rotation.z = 0.4
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new(); hq.size = Vector2(820, 820)
	halo.mesh = hq
	halo.material_override = glow_material(Color(0.25, 0.4, 0.9), 1.0)
	halo.position = planet.position
	add_child(halo)
	# leviathan
	leviathan = Node3D.new()
	var lm := plain(Color(0.012, 0.015, 0.02), 0.9, 0.0)
	lm.disable_fog = true
	var hull := CylinderMesh.new(); hull.top_radius = 22; hull.bottom_radius = 34; hull.height = 380; hull.radial_segments = 10
	node_mesh(hull, lm, Vector3.ZERO, leviathan, false).rotation.x = PI / 2
	var prow := CylinderMesh.new(); prow.top_radius = 0; prow.bottom_radius = 22; prow.height = 120; prow.radial_segments = 10
	node_mesh(prow, lm, Vector3(0, 0, 250), leviathan, false).rotation.x = PI / 2
	for i in 6:
		node_mesh(boxmesh(Vector3(4, rnd.randf_range(50, 100), 40)), lm, Vector3(0, 40, -150 + i * 55), leviathan, false)
	var lev_glow := glow_material(Color(3, 0.3, 0.2), 1.0)
	for i in 18:
		var s := MeshInstance3D.new()
		var q := QuadMesh.new(); q.size = Vector2(6, 6)
		s.mesh = q
		s.material_override = lev_glow
		s.position = Vector3(-30, rnd.randf_range(-20, 20), -180 + i * 22)
		leviathan.add_child(s)
	leviathan.position = Vector3(520, 70, -900)
	leviathan.visible = false
	add_child(leviathan)
	animated.append(func(t, dt):
		if not leviathan.visible:
			return
		leviathan.position.z += dt * 16.0
		lev_glow.set_shader_parameter("gain", 0.5 + 0.5 * sin(t * 2.0))
		if leviathan.position.z > 900:
			leviathan.visible = false)


func start_leviathan() -> void:
	leviathan.visible = true
	leviathan.position.z = -700


func build_set_pieces() -> void:
	hologram(Vector3(0, 4.0, -11.6), 0, 2.6, 1.2, [{"text": "環 C", "y": 110, "size": 80}, {"text": "ARRIVALS  >  MAINTENANCE SPINE", "y": 190}], Color(0.4, 1.0, 1.0))
	hologram(Vector3(1.25, 1.9, -27.5), -PI / 2, 1.3, 0.65, [{"text": "! 生物災害", "y": 110, "size": 64}, {"text": "DUCT 4 // SEALED", "y": 190}], Color(1.0, 0.29, 0.35))
	hologram(Vector3(34, 14, -64), 0, 9, 4.5, [{"text": "黒鉄 KUROGANE", "y": 120, "size": 70}, {"text": "A NEW HEAVEN ABOVE THE EARTH", "y": 200}], Color(1.0, 0.42, 0.84), {"bob": 0.4, "gain": 1.6})
	hologram(Vector3(16.2, 7, -30), PI / 2, 5, 2.5, [{"text": "展望", "y": 115, "size": 76}, {"text": "OBSERVATION DECK  >", "y": 195}], Color(1.0, 0.7, 0.28), {"gain": 1.4})
	hologram(Vector3(34, 4.2, -101.6), 0, 3, 1.1, [{"text": "収容", "y": 110, "size": 72}, {"text": "CONTAINMENT LV.2", "y": 195}], Color(1.0, 0.29, 0.35))
	hologram(Vector3(34, 4.8, -146), 0, 4, 1.6, [{"text": "降下  v", "y": 115, "size": 72}, {"text": "SECTOR 2 // BLOOM HEART", "y": 195}], Color(1.0, 0.7, 0.28))

	# ceiling fan beneath a shadow-casting light: sweeping shadows down the spine
	var fan := Node3D.new()
	fan.position = Vector3(0, 2.62, -30)
	add_child(fan)
	var hub := CylinderMesh.new(); hub.top_radius = 0.09; hub.bottom_radius = 0.09; hub.height = 0.08
	node_mesh(hub, mats.dark_metal, Vector3.ZERO, fan)
	for i in 5:
		var arm := Node3D.new()
		arm.rotation.y = i * TAU / 5
		fan.add_child(arm)
		var blade := node_mesh(boxmesh(Vector3(0.62, 0.015, 0.16)), mats.dark_metal, Vector3(0.36, 0, 0), arm)
		blade.rotation.x = 0.25
	var rod := CylinderMesh.new(); rod.top_radius = 0.015; rod.bottom_radius = 0.015; rod.height = 0.5
	node_mesh(rod, mats.dark_metal, Vector3(0, 0.28, 0), fan)
	animated.append(func(_t, dt): fan.rotation.y += dt * 2.6)

	points.steam_vents = [Vector3(4.2, 0.05, -10.6), Vector3(-1.0, 0.05, -34.5), Vector3(32.6, 0.05, -77), Vector3(46.5, 0.05, -112)]
	for v in points.steam_vents:
		box(v.x - 0.4, 0.0, v.z - 0.4, v.x + 0.4, 0.04, v.z + 0.4, mats.dark_metal, {"collide": false, "uv": 1.0})
		for i in range(-3, 4):
			box(v.x + i * 0.1 - 0.015, 0.04, v.z - 0.35, v.x + i * 0.1 + 0.015, 0.06, v.z + 0.35, mats.rubber, {"collide": false, "uv": 1.0})

	var strip_mats := [mats.cyan_dim, mats.red_dim, mats.amber]
	var rnd := RandomNumberGenerator.new(); rnd.seed = 314
	for i in 26:
		var z := -13 - rnd.randf() * 26
		var side := -1.48 if rnd.randf() < 0.5 else 1.48
		var y := 0.6 + rnd.randf() * 1.6
		strip(side - 0.02, y, z, side + 0.02, y + 0.03, z + rnd.randf_range(0.1, 0.4), strip_mats[rnd.randi() % 3])




# ===================================================================== script (director)
func script(d) -> void:
	var L = self
	var A = G.audio
	var H = G.hud

	# ---------------- spine scare: lights die, something runs overhead, a glimpse at the far end
	d.trigger([-1.6, -22.5, 1.6, -20], func():
		var fx: Array = L.fixtures.filter(func(f): return f.group == "spine")
		fx.sort_custom(func(a, b): return a.pos.z < b.pos.z)
		var saved := fx.map(func(f): return f.mode)
		A.duck(0.15, 0.3)
		A.stinger("scare")
		for i in fx.size():
			var f = fx[i]
			d.after(0.15 + i * 0.18, func():
				f.on = false
				A.play3d("buzz", f.pos, -10.0))
		d.after(1.6, func():
			A.play3d("vent_bang", Vector3(0, 3.2, -24), 6.0)
			G.player.add_shake(0.35))
		d.after(1.9, func(): A.skitter_path(Vector3(0, 3.4, -25), Vector3(0, 3.4, -13), 1.3, 6.0))
		d.after(3.8, func():
			A.play("lights_on", -2.0)
			for i in fx.size():
				fx[i].on = true
				fx[i].mode = saved[i]
			A.duck(1.0, 2.0))
		d.after(4.6, func():
			G.enemies.spawn("crawler", Vector3(1.0, 0, -38.6), {"scurry": Vector3(13, 0, -38.6)})
			A.play3d("skitter", Vector3(4, 0.3, -38.6), 2.0)))

	# ---------------- junction ambush
	d.encounters.junction = Director.Encounter.new(d, "junction", {
		"start": func(_e):
			L.doors.d2.lock()
			A.play3d("grate_fall", L.points.junction_vent, 6.0)
			A.duck(0.3, 0.2),
		"first_delay": 0.7,
		"waves": [func(e):
			e.spawn("crawler", L.points.junction_vent - Vector3(0, 0.4, 0), {"drop": true})
			A.stinger("encounter"); A.set_combat(true); A.duck(1.0, 1.0)
			H.hint("[b]LMB[/b] strike  ·  [b]RMB[/b] guard  ·  [b]SHIFT[/b] dash  ·  [b]Q[/b] lock-on", 7.0)],
		"clear": func(_e):
			A.set_combat(false)
			d.after(1.2, func():
				L.doors.d2.unlock()
				A.stinger("clear")
				H.message("LOCK RELEASED", 2.0)),
		"reset": func(_e):
			L.doors.d2.unlock(false)
			A.set_combat(false),
	})
	d.trigger([8, -40, 14, -37], func(): d.encounters.junction.begin(), "junction")

	# ---------------- concourse: two dormant sentinels wake
	d.encounters.atrium = Director.Encounter.new(d, "atrium", {
		"setup": func(e):
			e.data.sentinels = [e.spawn("sentinel", L.points.sentinel_a, {"dormant": true}), e.spawn("sentinel", L.points.sentinel_b, {"dormant": true})],
		"start": func(_e):
			L.doors.d3.lock()
			A.duck(0.2, 0.4),
		"first_delay": 0.3,
		"waves": [func(e):
			e.data.sentinels[0].activate()
			e.later(0.9, func(): e.data.sentinels[1].activate())
			e.later(1.0, func():
				A.stinger("encounter"); A.set_combat(true); A.duck(1.0, 1.0))
			e.later(4.0, func(): H.hint("Strike their plasma bolts to send them back  ·  or [b]RMB[/b] guard just as one hits", 7.0))
			e.pending += 1
			e.later(2.8, func(): e.pending -= 1)],
		"clear": func(_e):
			A.set_combat(false)
			d.after(1.5, func():
				L.doors.d3.unlock()
				A.stinger("clear")
				H.message("AREA SECURE", 2.5)),
		"reset": func(_e):
			L.doors.d3.unlock(false)
			A.set_combat(false),
	})
	d.trigger([27, -47, 41, -33], func(): d.encounters.atrium.begin(), "atrium_core")
	d.trigger([28, -70, 40, -60], func(): d.encounters.atrium.begin(), "atrium_north")
	d.trigger([44, -70, 54, -10], func(): leviathan_event(d), "leviathan")

	# ---------------- funnel apparition
	d.trigger([31.5, -84, 36.5, -81], func():
		G.enemies.spawn("stalker", L.points.funnel_glimpse, {"apparition": true})
		A.play3d("whisper", Vector3(34, 1.6, -96), 4.0)
		A.set_tension(0.6)
		d.after(0.4, func(): A.heartbeat(-2.0))
		d.after(1.3, func(): A.heartbeat(-3.0))
		d.after(2.2, func(): A.heartbeat(-4.0)))
	d.trigger([32.75, -96, 35.25, -91], func(): d.checkpoint = {"pos": Vector3(34, 0, -95), "yaw": 0.0})

	# ---------------- hydroponics vault
	var vents: Array = L.points.arena_vents
	d.encounters.arena = Director.Encounter.new(d, "arena", {
		"start": func(e):
			L.doors.d4.lock(true)
			A.duck(0.12, 0.6)
			A.set_tension(0.7)
			e.later(2.6, func():
				L.set_group("arena", "off")
				A.play("lights_out", 2.0))
			e.later(4.4, func(): A.play3d("crawler_hiss", vents[0], 4.0))
			e.later(5.0, func():
				A.play3d("crawler_hiss", vents[3], 4.0)
				A.play3d("taps", vents[4], 2.0))
			e.later(5.6, func(): A.play3d("skitter", vents[1], 4.0))
			e.later(6.4, func():
				L.set_group("alarm", "on")
				A.play("alarm", -2.0)
				A.stinger("encounter"); A.set_combat(true); A.duck(1.0, 1.0)
				H.message("CONTAINMENT BREACH", 3.0, true)),
		"first_delay": 6.8,
		"gaps": [2.5, 3.0],
		"waves": [
			func(e):
				var order := [0, 3, 4, 1]
				for i in order.size():
					var vi: int = order[i]
					e.spawn_later(i * 0.7, "crawler", vents[vi], {"drop": true}, func(_c): A.play3d("grate_fall", vents[vi], 6.0)),
			func(e):
				var sp: Array = L.points.arena_sentinels
				e.spawn_later(0.0, "sentinel", sp[0], {}, func(s): A.play3d("sentinel_boot", s.global_position, 4.0))
				e.spawn_later(0.8, "sentinel", sp[1], {}, func(s): A.play3d("sentinel_boot", s.global_position, 4.0))
				e.spawn_later(2.5, "crawler", vents[2], {"drop": true}, func(_c): A.play3d("grate_fall", vents[2], 6.0))
				e.spawn_later(3.2, "crawler", vents[5], {"drop": true}, func(_c): A.play3d("grate_fall", vents[5], 6.0)),
			func(e):
				A.set_combat(false)
				L.set_group("alarm", "off")
				A.duck(0.1, 0.5)
				e.later(1.2, func(): A.play3d("stalker_step", Vector3(24, 0.1, -125), 4.0))
				e.later(2.0, func(): A.play3d("stalker_step", Vector3(44, 0.1, -125), 4.0))
				e.later(2.6, func(): A.play3d("whisper", Vector3(34, 2, -130), 4.0))
				e.spawn_later(3.6, "stalker", L.points.stalker_spawn, {}, func(s):
					H.boss(s, "STALKER // BLOOM APEX")
					L.set_group("alarm", "emergency")
					A.set_combat(true); A.duck(1.0, 1.0)
					if not G.flags.get("stalker_hint", false):
						G.flags.stalker_hint = true
						d.after(4.0, func(): H.hint("It hides from the combat visor. Press [b]E[/b] to see it. Scan it to learn how to fight it.", 8.0))),
		],
		"enrage": func(e):
			e.spawn_later(0.5, "crawler", vents[0], {"drop": true}, func(_c): A.play3d("grate_fall", vents[0], 6.0))
			e.spawn_later(1.1, "crawler", vents[3], {"drop": true}, func(_c): A.play3d("grate_fall", vents[3], 6.0)),
		"clear": func(_e):
			A.set_combat(false)
			d.after(2.5, func():
				L.set_group("alarm", "off")
				L.set_group("arena", "on")
				A.play("lights_on", -2.0)
				A.stinger("clear")
				A.set_tension(0.0)
				H.message("THREAT NEUTRALIZED", 3.0)
				L.doors.d4.unlock(false)
				L.doors.d5.unlock()
				d.checkpoint = {"pos": Vector3(34, 0, -128), "yaw": 0.0}),
		"reset": func(_e):
			L.doors.d4.unlock(false)
			L.set_group("arena", "on")
			L.set_group("alarm", "off")
			A.set_combat(false); A.duck(1.0, 0.5); A.set_tension(0.0)
			H.boss(null),
	})
	d.trigger([20, -132, 48, -104], func(): d.encounters.arena.begin(), "arena")




func leviathan_event(d) -> void:
	start_leviathan()
	d.after(2.0, func(): G.audio.play("leviathan_horn", 0.0))
	d.after(6.0, func(): G.player.add_shake(0.15))


func on_enter(d, entry: String, first_time: bool) -> void:
	if entry != "start" or not first_time:
		return
	var H = G.hud
	d.after(2.2, func(): H.area("ARRIVAL BAY 03", "KUROGANE-9 // DOCKING RING C"))
	d.after(6.5, func(): H.hint("[b]WASD[/b] move  ·  [b]MOUSE[/b] look  ·  [b]SPACE[/b] jump", 6.0))
	d.after(14.0, func():
		if doors.d1.target == 0.0:
			H.hint("The door seal is dead. [b]LMB[/b] to strike the lock open.", 7.0))
	d.after(24.0, func():
		if not G.flags.get("scan_hinted", false):
			H.hint("[b]E[/b] scan visor: study your surroundings", 6.0))


func sector_update(d, dt: float) -> void:
	var p: Vector3 = G.player.global_position
	if d.zone == "atrium":
		atrium_time += dt
		if atrium_time > 45.0:
			for t in d.triggers:
				if t.id == "leviathan" and not t.fired:
					t.fired = true
					leviathan_event(d)
	if d.zone == "final" and not doors.d5.locked:
		var lc: Vector3 = points.lift_center
		if Vector2(p.x - lc.x, p.z - lc.z).length() < 2.2 and G.player.on_ground:
			on_lift += dt
			if on_lift > 1.2:
				on_lift = -999.0
				G.progress.flags.s1_done = true
				G.main.travel("s2", "lift", "DESCENDING TO THE UNDERCITY")
		else:
			on_lift = max(on_lift, 0.0) if on_lift > -100.0 else on_lift
