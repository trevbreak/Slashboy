class_name Sector3
extends Level
## Sector 3 — FOUNDRY: molten industrial depths. Lift hall → smelting hall (lava river, turrets,
## Bulwark) → press line (crushers) → coolant control (save) → the Warden's crucible.
## Reward: Phase Step.

var m := {}


func configure_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.008, 0.004)
	env.ambient_light_color = Color(0.35, 0.22, 0.16)
	env.volumetric_fog_albedo = Color(0.9, 0.7, 0.55)
	env.volumetric_fog_anisotropy = 0.3


func build_content() -> void:
	sector_id = "s3"
	sector_name = "FOUNDRY"
	moon_max = 0.0
	m.rust = pbr("rust", 1.0, 1.0)
	m.plate = pbr("foundry_plate", 0.9, 1.0)
	mats.rust = m.rust
	m.hot = emissive(Color(1.0, 0.45, 0.1), 2.5)
	m.warn = emissive(Color(1.0, 0.65, 0.1), 1.4)
	m.grate = plain(Color(0.12, 0.1, 0.09), 0.5, 0.9)
	build_lift_hall()
	build_smelting()
	build_press()
	build_coolant()
	build_crucible()
	define_zones()
	entries = {
		"lift": {"pos": Vector3(0, 0, -8), "yaw": 0.0},
		"arena": {"pos": Vector3(0, 0, -140), "yaw": 0.0},
	}


func catwalk(x0: float, z0: float, x1: float, z1: float, y: float, rail_sides := "both") -> void:
	box(x0, y - 0.15, z0, x1, y, z1, m.grate, {"uv": 1.0})
	var along_x := (x1 - x0) > (z1 - z0)
	if along_x:
		for z in ([z0, z1] if rail_sides == "both" else ([z0] if rail_sides == "a" else [z1])):
			box(x0, y + 1.0, z - 0.04, x1, y + 1.08, z + 0.04, mats.dark_metal, {"collide": false})
			var x := x0
			while x < x1:
				box(x - 0.03, y, z - 0.03, x + 0.03, y + 1.0, z + 0.03, mats.dark_metal, {"collide": false})
				x += 1.5
			collider(x0, y, z - 0.05, x1, y + 1.1, z + 0.05)
	else:
		for x in ([x0, x1] if rail_sides == "both" else ([x0] if rail_sides == "a" else [x1])):
			box(x - 0.04, y + 1.0, z0, x + 0.04, y + 1.08, z1, mats.dark_metal, {"collide": false})
			var z := z0
			while z < z1:
				box(x - 0.03, y, z - 0.03, x + 0.03, y + 1.0, z + 0.03, mats.dark_metal, {"collide": false})
				z += 1.5
			collider(x - 0.05, y, z0, x + 0.05, y + 1.1, z1)


func crucible(x: float, z: float, y: float, pour_to: Vector3) -> void:
	var g := Node3D.new(); g.position = Vector3(x, y, z); add_child(g)
	var bowl := CylinderMesh.new(); bowl.top_radius = 2.2; bowl.bottom_radius = 1.4; bowl.height = 2.4; bowl.radial_segments = 24
	node_mesh(bowl, m.rust, Vector3.ZERO, g)
	var melt := CylinderMesh.new(); melt.top_radius = 2.0; melt.bottom_radius = 2.0; melt.height = 0.05; melt.radial_segments = 24
	node_mesh(melt, m.hot, Vector3(0, 1.15, 0), g, false)
	g.rotation.z = 0.45
	pipe(Vector3(x, y + 3, z), Vector3(x, 26, z), 0.25, mats.dark_metal)
	var stream_mat := emissive(Color(1.0, 0.55, 0.15), 4.0)
	var from := Vector3(x + 1.6, y + 0.8, z)
	var cm := CylinderMesh.new(); cm.top_radius = 0.25; cm.bottom_radius = 0.18; cm.height = from.distance_to(pour_to); cm.radial_segments = 10
	var stream := MeshInstance3D.new()
	stream.mesh = cm
	stream.material_override = stream_mat
	stream.global_transform = cyl_xform(from, pour_to)
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)
	var l := OmniLight3D.new()
	l.position = pour_to + Vector3(0, 2, 0)
	l.light_color = Color(1.0, 0.5, 0.15)
	l.light_energy = 4.0
	l.omni_range = 14.0
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 2.0
	add_child(l)
	animated.append(func(t, _dt):
		stream_mat.emission_energy_multiplier = 3.5 + sin(t * 9.0) * 0.6
		l.light_energy = 4.0 + sin(t * 7.0) * 0.6 + randf() * 0.3
		if randf() < 0.3:
			G.fx.emit(pour_to + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), Vector3(randf_range(-2, 2), randf_range(2, 6), randf_range(-2, 2)), Color(3, 1.3, 0.3), 0.06, 0.4))


func spark_shower(p: Vector3) -> void:
	var state := {"t": randf() * 3.0}
	animated.append(func(_t, dt):
		state.t -= dt
		if state.t <= 0.0:
			state.t = randf_range(1.5, 4.0)
			if G.player and G.player.global_position.distance_to(p) < 30.0:
				G.fx.burst(p, {"count": 30, "color": Color(3, 1.6, 0.5), "speed": 4.0, "life": 1.0, "size": 0.05, "dir": Vector3.DOWN})
				G.audio.play3d("sparks", p, -4.0))


# ===================================================================== F1 — Lift Hall
func build_lift_hall() -> void:
	room({"x0": -8, "x1": 8, "z0": -14, "z1": 0, "h": 10, "wall": m.plate, "walls": {"n": false}})
	ribs_z(-8, -14, 0, 3, 10, 0.35)
	ribs_z(8, -14, 0, 3, 10, -0.35)
	elevator(Vector3(0, 0, -4), "s2", "from_foundry", "ASCENDING TO THE UNDERCITY")
	save_station(Vector3(-5, 0, -11), "s3_lift")
	fixture({"x": 0, "y": 9.8, "z": -7, "color": Color(1.0, 0.7, 0.45), "intensity": 6, "distance": 14, "size": Vector3(2, 0.1, 2), "shadow": true})
	hologram(Vector3(0, 6, -0.6), 0, 5, 1.8, [{"text": "鋳造所", "y": 110, "size": 76}, {"text": "FOUNDRY DECK 9 // HEAT WARNING", "y": 195}], Color(1.0, 0.55, 0.2))
	scannable(Vector3(0, 6, -0.6), "FOUNDRY DECK 9",
		"Smelts and casts every structural member the arcology still grows.\nThe furnaces were meant to shut down with the evacuation order.\nThey did not. Something is still feeding them.")


# ===================================================================== F2 — Smelting Hall
func build_smelting() -> void:
	var rnd := RandomNumberGenerator.new(); rnd.seed = 302
	var X0 := -30.0; var X1 := 30.0; var Z0 := -76.0; var Z1 := -14.0; var H := 26.0
	room({"x0": X0, "x1": X1, "z0": Z0, "z1": Z1, "h": H, "wall": m.rust, "floor": null,
		"open": {"s": [{"c": 0, "w": 4, "h": 4.5}], "n": [{"c": 0, "w": 4, "h": 5}]}})
	box(X0 - 0.5, -0.5, -40.0, X1 + 0.5, 0.0, Z1 + 0.5, m.plate, {"cast": false, "uv": 4.0})
	box(X0 - 0.5, -0.5, Z0 - 0.5, X1 + 0.5, 0.0, -46.0, m.plate, {"cast": false, "uv": 4.0})
	lava(X0, -46.0, X1, -40.0, -0.4, 30.0)
	ribs_z(X0, Z0, Z1, 5, H, 0.5)
	ribs_z(X1, Z0, Z1, 5, H, -0.5)
	var z := Z0 + 5
	while z < Z1:
		box(X0, H - 1.6, z - 0.5, X1, H, z + 0.5, mats.dark_metal, {"collide": false, "uv": 2.0})
		z += 6
	# bridges: east and west intact; middle collapsed (grapple)
	for bx in [-20.0, 20.0]:
		catwalk(bx - 1.25, -46.5, bx + 1.25, -39.5, 0.3)
	box(-1.25, 0.15, -40.6, 1.25, 0.3, -39.5, m.grate, {"uv": 1.0})
	box(-1.25, 0.15, -46.5, 1.25, 0.3, -45.4, m.grate, {"uv": 1.0})
	grapple_point(Vector3(0, 8.5, -43))
	crucible(-10, -43, 9.0, Vector3(-8.2, -0.4, -43))
	crucible(12, -43, 9.0, Vector3(13.8, -0.4, -43))
	# upper catwalk with a ki shard (grapple)
	catwalk(-28, -75.5, 28, -72.5, 8.0, "b")
	grapple_point(Vector3(22, 12.5, -73.5))
	item(Vector3(26, 9.0, -74), "shard", "s3_shard_catwalk")
	# crucible ledge tank (Kage Leap from the catwalk crate)
	box(-27.5, 3.2, -24, -24.0, 3.5, -18, m.grate, {"uv": 1.0})
	crate(-25, -30.2, 1.0)
	box(-26, 0, -28.5, -24, 1.9, -25, m.rust, {"uv": 1.0})
	item(Vector3(-26, 4.4, -21), "tank", "s3_tank_ledge")
	# machinery: furnace mouths along the west wall
	for fz in [-24.0, -60.0]:
		box(X0, 0, fz - 3, X0 + 2.0, 6, fz + 3, m.rust, {"uv": 2.0})
		box(X0 + 1.9, 1.0, fz - 2, X0 + 2.05, 4.5, fz + 2, m.hot, {"collide": false, "cast": false})
		var fl := OmniLight3D.new()
		fl.position = Vector3(X0 + 3.5, 2.5, fz)
		fl.light_color = Color(1.0, 0.45, 0.12)
		fl.light_energy = 3.5
		fl.omni_range = 12.0
		fl.light_volumetric_fog_energy = 1.5
		add_child(fl)
	for p in [Vector3(-15, 24, -30), Vector3(10, 24, -58), Vector3(22, 24, -24)]:
		spark_shower(p)
	for wz in [-22.0, -34.0, -54.0, -66.0]:
		for side in [-1.0, 1.0]:
			fixture({"x": side * (X1 - 0.4), "y": 6.5, "z": wz, "color": Color(1.0, 0.68, 0.38), "intensity": 11, "distance": 22, "size": Vector3(0.3, 0.5, 1.4)})
	for p in [[-15, -28], [15, -28], [-15, -60], [15, -60]]:
		fixture({"x": p[0], "y": 25.5, "z": p[1], "color": Color(1.0, 0.75, 0.5), "intensity": 14, "distance": 34, "size": Vector3(2, 0.15, 2), "shadow": p[0] < 0})
	for i in 6:
		var c := Vector3(rnd.randf_range(-24, 24), 0, rnd.randf_range(-36, -18))
		crate(c.x, c.z, rnd.randf_range(0.8, 1.6))
	for i in 6:
		var c := Vector3(rnd.randf_range(-24, 24), 0, rnd.randf_range(-70, -50))
		crate(c.x, c.z, rnd.randf_range(0.8, 1.6))
	points.turrets = [[Vector3(-29.4, 7, -55), Vector3(1, 0, 0)], [Vector3(29.4, 7, -32), Vector3(-1, 0, 0)], [Vector3(0, 25.4, -60), Vector3(0, -1, 0)]]
	scannable(Vector3(-8.2, 0, -43), "MOLTEN CHANNEL",
		"Liquid structural alloy at 1,480°C, flowing toward the casting presses.\nIt will not kill you instantly. It will try.")


# ===================================================================== F3 — Press Line
func build_press() -> void:
	room({"x0": -4, "x1": 4, "z0": -114, "z1": -76.5, "h": 8, "wall": m.plate, "walls": {"s": false},
		"open": {"n": [{"c": 0, "w": 3, "h": 3.5}]}})
	ribs_z(-4, -114, -76.5, 2.5, 8, 0.3)
	ribs_z(4, -114, -76.5, 2.5, 8, -0.3)
	var i := 0
	for cz in [-83.0, -91.0, -99.0, -107.0]:
		crusher(-3.0, cz - 1.8, 3.0, cz + 1.8, 7.0, 3.2, i * 0.8)
		strip(-4, 0.0, cz - 2.0, 4, 0.02, cz - 1.85, m.warn)
		strip(-4, 0.0, cz + 1.85, 4, 0.02, cz + 2.0, m.warn)
		fixture({"x": 0, "y": 7.9, "z": cz + 4.0, "color": Color(1.0, 0.7, 0.45), "intensity": 7, "distance": 12, "size": Vector3(1.2, 0.08, 0.5), "shadow": true})
		var wl := OmniLight3D.new()
		wl.position = Vector3(0, 6.2, cz)
		wl.light_color = Color(1.0, 0.45, 0.15)
		wl.light_energy = 1.6
		wl.omni_range = 7.0
		add_child(wl)
		i += 1
	scannable(Vector3(3.6, 1.5, -79), "CASTING PRESS",
		"Four-hundred-tonne stamping heads, still cycling on automated schedule.\nTime your crossing. The rhythm never changes.")


# ===================================================================== F4 — Coolant Control
func build_coolant() -> void:
	room({"x0": -12, "x1": 12, "z0": -134, "z1": -114.5, "h": 7, "wall": m.plate, "walls": {"s": false},
		"open": {"n": [{"c": 0, "w": 4, "h": 4.5}], "e": [{"c": -124, "w": 2.5, "h": 3}]}})
	save_station(Vector3(-8, 0, -126), "s3_coolant")
	console(6, -131, PI, "screen_amber")
	console(-2, -131, PI, "screen_cyan")
	for x in [-9.0, 9.0]:
		var t := CylinderMesh.new(); t.top_radius = 1.2; t.bottom_radius = 1.2; t.height = 6; t.radial_segments = 20
		builder.mesh(t, Transform3D(Basis(), Vector3(x, 3, -118)), mats.dark_metal)
		collider(x - 1.2, 0, -119.2, x + 1.2, 6, -116.8)
		strip(x - 1.22, 2.0, -119.22, x + 1.22, 2.2, -116.78, emissive(Color(0.3, 0.8, 1.0), 1.2))
	fixture({"x": 0, "y": 6.9, "z": -124, "color": Color(0.6, 0.85, 1.0), "intensity": 6, "distance": 14, "size": Vector3(3, 0.1, 0.5)})
	# phase-sealed vault (energy tank) east
	room({"x0": 12.5, "x1": 18, "z0": -128, "z1": -120, "h": 4, "walls": {"w": false}, "wall": m.plate})
	phase_barrier(12.05, 0, -125.25, 12.45, 3, -122.75)
	item(Vector3(15.5, 1.0, -124), "tank", "s3_tank_vault")
	var d := Door.new(); add_child(d); d.setup(self, Vector3(0, 0, -134.25), "x", 4, 4.5, false); doors.arena = d
	scannable(Vector3(6, 1.4, -131), "COOLANT CONTROL LOG",
		"0412: Warden unit refuses shutdown. Cites \"protective custody of the furnaces.\"\n0419: Warden has welded the crucible doors from inside.\n0420: It is not protecting the furnaces. It is protecting what is growing in them.", {"critical": true})


# ===================================================================== F5 — The Warden's Crucible
func build_crucible() -> void:
	var X0 := -26.0; var X1 := 26.0; var Z0 := -190.0; var Z1 := -134.5; var H := 22.0
	room({"x0": X0, "x1": X1, "z0": Z0, "z1": Z1, "h": H, "wall": m.rust, "walls": {"s": false}})
	box(X0 - 0.5, 0, Z1, -2.0, H, Z1 + 0.5, m.rust)
	box(2.0, 0, Z1, X1 + 0.5, H, Z1 + 0.5, m.rust)
	box(-2.0, 4.5, Z1, 2.0, H, Z1 + 0.5, m.rust)
	ribs_z(X0, Z0, Z1, 6, H, 0.6)
	ribs_z(X1, Z0, Z1, 6, H, -0.6)
	ribs_x(Z0, X0, X1, 6, H, 0.6)
	for p in [[X0 + 4, Z0 + 4], [X1 - 4, Z0 + 4], [X0 + 4, Z1 - 4], [X1 - 4, Z1 - 4]]:
		lava(p[0] - 3.5, p[1] - 3.5, p[0] + 3.5, p[1] + 3.5, 0.02, 30.0)
		box(p[0] - 3.7, 0, p[1] - 3.7, p[0] + 3.7, 0.08, p[1] - 3.5, m.warn, {"collide": false})
	for p in [[-12, -150], [12, -150], [-12, -174], [12, -174]]:
		box(p[0] - 1.4, 0, p[1] - 1.4, p[0] + 1.4, H, p[1] + 1.4, m.plate, {"uv": 2.0})
	for p in [[-14, -162], [14, -162], [0, -148], [0, -178]]:
		fixture({"x": p[0], "y": H - 0.2, "z": p[1], "color": Color(1.0, 0.7, 0.45), "intensity": 12, "distance": 30, "size": Vector3(2.5, 0.15, 2.5), "group": "crucible", "shadow": p[0] == 0})
	points.arena_center = Vector3(0, 0, -162)
	scannable(Vector3(0, 2, -186), "SEALED CRUCIBLE",
		"Furnace 0 has been welded shut. The weld seams glow violet.\nSomething inside is incubating in the heat.", {"critical": true})


func define_zones() -> void:
	var hot := [0.016, Color(0.14, 0.06, 0.03), 1.5, 0.95]
	zones = [
		{"id": "lifthall", "box": [-9, -14.25, 9, 1], "amb": "foundry", "mood": [0.012, Color(0.1, 0.05, 0.03), 1.45, 0.9], "title": "FOUNDRY", "sub": "DECK 9",
			"fog": [Vector3(0, 4, -7), Vector3(16, 9, 14), 0.02, Color(0.9, 0.7, 0.55)], "probe": [Vector3(0, 3, -7), Vector3(16.5, 10.2, 14.5)]},
		{"id": "smelting", "box": [-31, -76.25, 31, -14.25], "amb": "foundry", "mood": hot, "title": "SMELTING HALL", "sub": "LINE 3",
			"fog": [Vector3(0, 6, -45), Vector3(60, 12, 62), 0.014, Color(0.95, 0.65, 0.45), Color(0.05, 0.015, 0.0)], "probe": [Vector3(0, 6, -45), Vector3(60.5, 26.5, 62.5)],
			"checkpoint": {"pos": Vector3(0, 0, -17), "yaw": 0.0}},
		{"id": "press", "box": [-4.5, -114.25, 4.5, -76.25], "amb": "foundry", "mood": [0.012, Color(0.09, 0.05, 0.03), 1.5, 0.95], "title": "PRESS LINE", "sub": "CASTING",
			"fog": [Vector3(0, 3, -95), Vector3(8, 7, 37), 0.025, Color(0.9, 0.75, 0.6)], "checkpoint": {"pos": Vector3(0, 0, -79), "yaw": 0.0}},
		{"id": "coolant", "box": [-13, -134.25, 19, -114.25], "amb": "corridor", "mood": [0.008, Color(0.05, 0.07, 0.09), 1.45, 0.85], "title": "COOLANT CONTROL", "sub": "SAFE ROOM",
			"probe": [Vector3(0, 3, -124), Vector3(24.5, 7.2, 20)], "checkpoint": {"pos": Vector3(0, 0, -117), "yaw": 0.0}},
		{"id": "crucible", "box": [-27, -191, 27, -134.25], "amb": "foundry", "mood": hot, "title": "FURNACE ZERO", "sub": "THE WARDEN'S CRUCIBLE",
			"fog": [Vector3(0, 4, -162), Vector3(52, 8, 55), 0.012, Color(0.95, 0.65, 0.45), Color(0.05, 0.015, 0.0)], "probe": [Vector3(0, 5, -162), Vector3(52.5, 22.5, 56)]},
	]


# ===================================================================== script
func script(d) -> void:
	var A = G.audio
	var H = G.hud
	var F: Dictionary = G.progress.flags

	# turrets + a Bulwark guard the smelting hall's north half
	if not F.has("s3_smelting"):
		d.encounters.smelting = Director.Encounter.new(d, "smelting", {
			"setup": func(e):
				for t in points.turrets:
					e.spawn("turret", t[0], {"normal": t[1]}),
			"start": func(_e):
				A.play3d("servo", Vector3(0, 2, -60), 6.0),
			"first_delay": 0.5,
			"waves": [func(e):
				var b = e.spawn("bulwark", Vector3(0, 0, -64))
				A.stinger("encounter"); A.set_combat(true)
				d.after(2.0, func(): H.hint("Its shield stops frontal strikes  ·  dash behind it, finish a combo, or [b]F[/b] to tear the shield away", 7.0))],
			"clear": func(_e):
				A.set_combat(false)
				F.s3_smelting = true
				A.stinger("clear"),
			"reset": func(_e): A.set_combat(false),
		})
		d.trigger([-30, -52, 30, -46.5], func(): d.encounters.smelting.begin(), "smelting")

	# coolant: two bulwarks ambush on the way back with the phase step
	if G.progress.bosses.has("warden"):
		_return_ambush(d)

	# the Warden
	if not G.progress.bosses.has("warden"):
		d.encounters.warden = Director.Encounter.new(d, "warden", {
			"start": func(e):
				doors.arena.lock(true)
				A.duck(0.15, 0.4)
				A.set_tension(0.8)
				e.later(1.0, func(): A.play("boss_intro", 0.0))
				e.later(1.8, func(): H.area("WARDEN", "FOUNDRY SECURITY")),
			"first_delay": 2.0,
			"waves": [func(e):
				var b = e.spawn("warden", Vector3(0, 0, -172), {"center": points.arena_center})
				b.facing = 0.0
				H.boss(b, b.boss_name)
				A.set_boss_music(true); A.duck(1.0, 1.0)
				d.after(7.0, func(): H.hint("The dome is fed by two generators on its back  ·  [b]F[/b] to tear them off, or deflect its missiles into them", 8.0))],
			"clear": func(_e):
				A.set_boss_music(false)
				G.progress.bosses.warden = true
				d.after(4.0, func():
					A.stinger("clear")
					H.message("WARDEN DESTROYED", 3.0)
					doors.arena.unlock(false)
					item(Vector3(0, 1.3, -162), "phase", "ability_phase")
					_return_ambush(d)
					d.checkpoint = {"pos": Vector3(0, 0, -140), "yaw": 0.0}),
			"reset": func(_e):
				doors.arena.unlock(false)
				for gp in grapple_points.duplicate():
					if gp.has("on_pull"):
						grapple_points.erase(gp)
				A.set_boss_music(false); A.duck(1.0, 0.5); A.set_tension(0.0)
				H.boss(null),
		})
		d.trigger([-24, -186, 24, -140], func(): d.encounters.warden.begin(), "warden")
	elif not G.progress.abilities.has("phase"):
		item(Vector3(0, 1.3, -162), "phase", "ability_phase")


func _return_ambush(d) -> void:
	if G.progress.flags.has("s3_return"):
		return
	d.trigger([-12, -134, 12, -116], func():
		G.progress.flags.s3_return = true
		G.audio.stinger("encounter")
		G.audio.play3d("hydraulic", Vector3(0, 2, -116), 6.0)
		for p in [Vector3(-6, 0, -116.5), Vector3(6, 0, -116.5)]:
			G.enemies.spawn("bulwark", p)
		G.hud.hint("[b]SHIFT[/b] Phase Step dashes straight through shields and barriers", 6.0), "return")


func on_enter(d, entry: String, first_time: bool) -> void:
	G.fx.set_rain(false)
	if first_time:
		d.after(2.0, func(): G.hud.hint("Heat warning  ·  molten metal burns, but you can climb out", 5.0))
