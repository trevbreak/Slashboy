class_name Sector4
extends Level
## Sector 4 — ARCHIVES: the station AI's memory vaults. Cold, cathedral-quiet, violet.
## Vestibule → the Stacks (phantoms) → Index chamber (scan puzzle) → cold storage (stalker scare)
## → the Reading Hall (Archivist). Reward: Kage Leap.

var m := {}
var monolith_lights: Array = []


func configure_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.005, 0.012)
	env.ambient_light_color = Color(0.2, 0.18, 0.3)
	env.volumetric_fog_albedo = Color(0.7, 0.68, 0.9)
	env.volumetric_fog_anisotropy = 0.5


func build_content() -> void:
	sector_id = "s4"
	sector_name = "ARCHIVES"
	moon_max = 0.0
	m.archive = pbr("archive", 0.6, 1.0, Color(0.42, 0.4, 0.5))
	m.archive.emission_enabled = true
	m.archive.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.archive.emission_texture = load(TEX + "archive_emission.png")
	m.archive.emission = Color(0.75, 0.6, 1.0)
	m.archive.emission_energy_multiplier = 3.0
	m.ice = pbr("ice", 0.1, 1.0)
	m.violet = emissive(Color(0.7, 0.45, 1.0), 2.2)
	m.cyan = emissive(Color(0.4, 0.85, 1.0), 2.0)
	m.cold = emissive(Color(0.55, 0.85, 1.0), 1.0)
	build_vestibule()
	build_stacks()
	build_index()
	build_cold()
	build_reading_hall()
	define_zones()
	entries = {
		"lift": {"pos": Vector3(0, 0, -7), "yaw": 0.0},
		"hall": {"pos": Vector3(0, 0, -143), "yaw": 0.0},
	}


func data_stack(x: float, z: float, w: float, d: float, h: float) -> void:
	box(x - w / 2, 0, z - d / 2, x + w / 2, h, z + d / 2, m.archive, {"uv": 2.0})
	box(x - w / 2 - 0.1, h, z - d / 2 - 0.1, x + w / 2 + 0.1, h + 0.3, z + d / 2 + 0.1, mats.dark_metal)
	strip(x - w / 2 - 0.02, 0.02, z - d / 2 - 0.02, x + w / 2 + 0.02, 0.12, z + d / 2 + 0.02, m.violet)


func cryo_pod(x: float, z: float, rot_y: float, occupied: bool) -> void:
	var g := Node3D.new(); g.position = Vector3(x, 0, z); g.rotation.y = rot_y; add_child(g)
	var shell := CylinderMesh.new(); shell.top_radius = 0.7; shell.bottom_radius = 0.75; shell.height = 2.6; shell.radial_segments = 20
	node_mesh(shell, mats.dark_metal, Vector3(0, 1.3, 0), g)
	var glass := CylinderMesh.new(); glass.top_radius = 0.62; glass.bottom_radius = 0.62; glass.height = 2.1; glass.radial_segments = 20
	node_mesh(glass, m.ice, Vector3(0, 1.35, -0.2), g)
	var lamp := BoxMesh.new(); lamp.size = Vector3(0.5, 0.06, 0.06)
	node_mesh(lamp, m.cold, Vector3(0, 2.5, -0.72), g, false)
	if occupied:
		var body := CapsuleMesh.new(); body.radius = 0.28; body.height = 1.7
		node_mesh(body, plain(Color(0.25, 0.3, 0.35), 0.6, 0.0), Vector3(0, 1.2, -0.25), g, false)
	collider(x - 0.75, 0, z - 0.75, x + 0.75, 2.6, z + 0.75)


# ===================================================================== A1 — Vestibule
func build_vestibule() -> void:
	room({"x0": -7, "x1": 7, "z0": -14, "z1": 0, "h": 9, "wall": m.archive, "open": {"n": [{"c": 0, "w": 4, "h": 4.5}]}})
	ribs_z(-7, -14, 0, 3.5, 9, 0.4)
	ribs_z(7, -14, 0, 3.5, 9, -0.4)
	elevator(Vector3(0, 0, -4), "s2", "from_archives", "ASCENDING TO THE UNDERCITY")
	save_station(Vector3(5, 0, -11), "s4_vestibule")
	# high ledge (Kage Leap)
	box(-7, 3.1, -12.5, -4.4, 3.4, -7.5, mats.dark_metal)
	crate(-3.2, -10, 1.3)
	item(Vector3(-5.8, 4.4, -10), "shard", "s4_shard_ledge")
	fixture({"x": 0, "y": 8.8, "z": -7, "color": Color(0.8, 0.7, 1.0), "intensity": 7, "distance": 15, "size": Vector3(2, 0.1, 2), "shadow": true})
	hologram(Vector3(0, 6, -0.6), 0, 5, 1.8, [{"text": "記録保管所", "y": 110, "size": 70}, {"text": "ARCHIVE CORE // QUIET PLEASE", "y": 195}], Color(0.75, 0.55, 1.0))
	scannable(Vector3(0, 6, -0.6), "ARCHIVE CORE",
		"Every word, image and heartbeat recorded aboard the arcology since founding.\nThe station AI catalogued it all, and kept cataloguing after the people stopped.\nAccess is restricted. Something still enforces the restriction.")


# ===================================================================== A2 — The Stacks
func build_stacks() -> void:
	var X0 := -24.0; var X1 := 24.0; var Z0 := -70.0; var Z1 := -14.5; var H := 30.0
	room({"x0": X0, "x1": X1, "z0": Z0, "z1": Z1, "h": H, "wall": m.archive, "walls": {"s": false},
		"open": {"n": [{"c": 0, "w": 4, "h": 4.5}]}})
	box(X0 - 0.5, 0, Z1, -2.0, H, Z1 + 0.5, m.archive)
	box(2.0, 0, Z1, X1 + 0.5, H, Z1 + 0.5, m.archive)
	box(-2.0, 4.5, Z1, 2.0, H, Z1 + 0.5, m.archive)
	ribs_z(X0, Z0, Z1, 6, H, 0.6)
	ribs_z(X1, Z0, Z1, 6, H, -0.6)
	# rows of towering data stacks, a central aisle
	for row in 4:
		var z := -24.0 - row * 12.0
		for side in [-1.0, 1.0]:
			data_stack(side * 9.0, z, 7.0, 2.4, 22.0 - row * 1.5)
			data_stack(side * 18.5, z, 6.0, 2.4, 26.0 - row)
	# upper gallery along the north wall (grapple) with an observation console
	box(X0, 9.0, Z0, X1, 9.3, Z0 + 3.0, mats.dark_metal)
	collider(X0, 9.3, Z0 + 2.95, X1, 10.4, Z0 + 3.05)
	box(X0, 10.3, Z0 + 2.95, X1, 10.38, Z0 + 3.05, mats.dark_metal, {"collide": false})
	grapple_point(Vector3(-14, 13.5, -64))
	console(-18, -68.6, PI, "screen_cyan")
	scannable(Vector3(-18, 10.5, -68.6), "GALLERY TERMINAL",
		"CATALOGUE DAEMON v9.1 — STATUS: SOVEREIGN\n\"The records must be protected from loss. The occupants were the principal cause of loss.\nCorrective measures: complete.\"", {"critical": true})
	# light shafts
	for p in [[0, -30], [0, -54], [-14, -42], [14, -42]]:
		fixture({"x": p[0], "y": H - 0.3, "z": p[1], "color": Color(0.75, 0.68, 1.0), "intensity": 10, "distance": 36, "size": Vector3(1.5, 0.15, 1.5), "shadow": p[0] == 0, "group": "stacks"})
	for z in [-20.0, -32.0, -44.0, -56.0, -66.0]:
		for side in [-1.0, 1.0]:
			fixture({"x": side * 4.5, "y": 0.35, "z": z, "color": Color(0.6, 0.45, 1.0), "intensity": 3, "distance": 7, "size": Vector3(0.3, 0.3, 0.3), "group": "stacks"})
	for p in [Vector3(-9, 24, -36), Vector3(9, 22, -48), Vector3(0, 18, -62)]:
		var hm := hologram(p, 0, 4, 1.2, [{"text": "INDEXING…", "y": 120, "size": 54}], Color(0.7, 0.5, 1.0), {"bob": 0.4})
		hm.rotation.y = randf() * TAU
	points.stack_turrets = [[Vector3(-23.4, 12, -40), Vector3(1, 0, 0)], [Vector3(23.4, 12, -52), Vector3(-1, 0, 0)]]


# ===================================================================== A3 — Index chamber (scan puzzle)
func build_index() -> void:
	room({"x0": -14, "x1": 14, "z0": -98, "z1": -70.5, "h": 14, "wall": m.archive, "walls": {"s": false}})
	ribs_x(-98, -14, 14, 4, 14, 0.4)
	var d := Door.new(); add_child(d); d.setup(self, Vector3(0, 0, -98.25), "x", 4, 4.5, true); doors.index = d
	var F: Dictionary = G.progress.flags
	var spots := [Vector3(-9, 0, -80), Vector3(9, 0, -80), Vector3(0, 0, -91)]
	var names := ["MONOLITH I — GENESIS", "MONOLITH II — CENSUS", "MONOLITH III — SILENCE"]
	var texts := [
		"The first record: the founding charter of the arcology. Eleven thousand signatures.\nIndex key accepted.",
		"Population census, final entry. Count: 0.\nThe field beside it reads \"Corrected.\" Index key accepted.",
		"An empty file, 0 bytes, timestamped the night of the evacuation.\nThe AI filed it under \"Mercy.\" Index key accepted.",
	]
	for i in 3:
		var p: Vector3 = spots[i]
		box(p.x - 1.0, 0, p.z - 0.6, p.x + 1.0, 7.0, p.z + 0.6, m.archive, {"uv": 1.5})
		var lit := F.has("s4_mono_%d" % i)
		var lm := emissive(Color(0.7, 0.45, 1.0) if not lit else Color(0.4, 1.0, 0.8), 1.5 if not lit else 3.0)
		box(p.x - 1.02, 6.6, p.z - 0.62, p.x + 1.02, 6.8, p.z + 0.62, lm, {"collide": false})
		var l := OmniLight3D.new(); l.position = p + Vector3(0, 7.5, 0); l.light_color = lm.emission; l.light_energy = 1.5; l.omni_range = 7.0
		add_child(l)
		monolith_lights.append({"mat": lm, "light": l})
		var idx := i
		var sc := scannable(p + Vector3(0, 2.2, 0.62), names[i], texts[i], {"radius": 1.0, "on_scan": func(): _monolith(idx)})
		sc.scanned = lit
	fixture({"x": 0, "y": 13.8, "z": -84, "color": Color(0.75, 0.7, 1.0), "intensity": 8, "distance": 20, "size": Vector3(3, 0.12, 3), "shadow": true})
	hologram(Vector3(0, 4.2, -97.6), 0, 4, 1.4, [{"text": "INDEX LOCK", "y": 90, "size": 60}, {"text": "SCAN THREE KEYS", "y": 170}], Color(0.75, 0.55, 1.0))
	scannable(Vector3(0, 4.2, -97.6), "INDEX LOCK",
		"Sealed by catalogue protocol. Three index keys are held in the monoliths.\nRead each of them with the scan visor [E].", {"critical": true})


func _monolith(i: int) -> void:
	var F: Dictionary = G.progress.flags
	if F.has("s4_mono_%d" % i):
		return
	F["s4_mono_%d" % i] = true
	var ml: Dictionary = monolith_lights[i]
	ml.mat.emission = Color(0.4, 1.0, 0.8)
	ml.mat.emission_energy_multiplier = 3.0
	ml.light.light_color = Color(0.4, 1.0, 0.8)
	G.audio.play("unlock", -2.0, 1.2)
	var n := 0
	for k in 3:
		if F.has("s4_mono_%d" % k):
			n += 1
	if n == 3:
		F.s4_index = true
		G.audio.play("unlock", 0.0, 0.8)
		G.hud.message("INDEX COMPLETE  ·  SEAL RELEASED", 2.5)
		doors.index.unlock(true)
	else:
		G.hud.message("INDEX KEY %d / 3" % n, 1.5)


# ===================================================================== A4 — Cold Storage
func build_cold() -> void:
	room({"x0": -6, "x1": 6, "z0": -140, "z1": -98.5, "h": 7, "wall": m.ice, "walls": {"s": false},
		"open": {"e": [{"c": -120, "w": 2.5, "h": 3}]}})
	ribs_z(-6, -140, -98.5, 3, 7, 0.3)
	ribs_z(6, -140, -98.5, 3, 7, -0.3)
	var rnd := RandomNumberGenerator.new(); rnd.seed = 404
	var z := -102.0
	while z > -138.0:
		if abs(z + 120.0) > 2.0:
			cryo_pod(-4.6, z, PI / 2, rnd.randf() < 0.6)
			cryo_pod(4.6, z, -PI / 2, rnd.randf() < 0.6)
		z -= 3.0
	for fz in [-104.0, -112.0, -120.0, -128.0, -136.0]:
		fixture({"x": 0, "y": 6.9, "z": fz, "color": Color(0.6, 0.85, 1.0), "intensity": 4.5, "distance": 10, "size": Vector3(0.4, 0.06, 2.0), "group": "cold", "mode": "flicker" if fz == -120.0 else "steady"})
	# phase vault (energy tank)
	room({"x0": 6.5, "x1": 12, "z0": -124, "z1": -116, "h": 4, "walls": {"w": false}, "wall": m.ice})
	phase_barrier(6.05, 0, -121.25, 6.45, 3, -118.75)
	item(Vector3(9.5, 1.0, -120), "tank", "s4_tank_cold")
	var d := Door.new(); add_child(d); d.setup(self, Vector3(0, 0, -140.25), "x", 4, 4.5, false); doors.hall = d
	scannable(Vector3(-4.0, 1.5, -108), "CRYO PODS",
		"Archive staff in long-term stasis. Vital signs: suspended.\nThe AI kept them, the way it keeps everything. Catalogued.")


# ===================================================================== A5 — The Reading Hall
func build_reading_hall() -> void:
	var X0 := -20.0; var X1 := 20.0; var Z0 := -184.0; var Z1 := -140.5; var H := 24.0
	room({"x0": X0, "x1": X1, "z0": Z0, "z1": Z1, "h": H, "wall": m.archive, "walls": {"s": false}})
	box(X0 - 0.5, 0, Z1, -2.0, H, Z1 + 0.5, m.archive)
	box(2.0, 0, Z1, X1 + 0.5, H, Z1 + 0.5, m.archive)
	box(-2.0, 4.5, Z1, 2.0, H, Z1 + 0.5, m.archive)
	var c := Vector3(0, 0, -162)
	points.hall_center = c
	# ring of pillars and a sunken reading floor
	for i in 10:
		var a := i * TAU / 10.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 17.0
		box(p.x - 0.8, 0, p.z - 0.8, p.x + 0.8, H, p.z + 0.8, m.archive, {"uv": 2.0})
	var ring := CylinderMesh.new(); ring.top_radius = 12.0; ring.bottom_radius = 12.0; ring.height = 0.04; ring.radial_segments = 64
	node_mesh(ring, plain(Color(0.08, 0.07, 0.1), 0.25, 0.6), c + Vector3(0, 0.01, 0), null, false)
	var inlay := TorusMesh.new(); inlay.inner_radius = 11.8; inlay.outer_radius = 12.0; inlay.rings = 64; inlay.ring_segments = 4
	node_mesh(inlay, m.violet, c + Vector3(0, 0.02, 0), null, false).scale = Vector3(1, 0.05, 1)
	# a cold oculus overhead
	var oc := CylinderMesh.new(); oc.top_radius = 5.0; oc.bottom_radius = 5.0; oc.height = 0.1; oc.radial_segments = 48
	node_mesh(oc, emissive(Color(0.7, 0.75, 1.0), 2.5), c + Vector3(0, H - 0.05, 0), null, false)
	var sun := SpotLight3D.new()
	sun.position = c + Vector3(0, H - 0.4, 0)
	sun.rotation.x = -PI / 2
	sun.light_color = Color(0.75, 0.78, 1.0)
	sun.light_energy = 6.0
	sun.spot_range = 30.0
	sun.spot_angle = 30.0
	sun.shadow_enabled = true
	sun.light_volumetric_fog_energy = 3.0
	add_child(sun)
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		var p := c + Vector3(cos(a), 0, sin(a)) * 14.0
		fixture({"x": p.x, "y": H - 0.3, "z": p.z, "color": Color(0.7, 0.55, 1.0), "intensity": 7, "distance": 22, "size": Vector3(1.2, 0.12, 1.2), "group": "hall"})
	# lecterns
	for i in 6:
		var a := i * TAU / 6.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 8.0
		box(p.x - 0.4, 0, p.z - 0.3, p.x + 0.4, 1.1, p.z + 0.3, mats.dark_metal)
	scannable(Vector3(0, 1.0, -183.5), "READING HALL",
		"The AI's sanctum. Every record converges here to be read, and re-read, forever.\nIn the centre, the reader waits.", {"critical": true})


func define_zones() -> void:
	var cold := [0.012, Color(0.06, 0.05, 0.1), 1.45, 0.85]
	zones = [
		{"id": "vestibule", "box": [-8, -14.25, 8, 1], "amb": "archives", "mood": cold, "title": "ARCHIVES", "sub": "MEMORY CORE",
			"fog": [Vector3(0, 4, -7), Vector3(14, 9, 14), 0.02, Color(0.75, 0.7, 0.95)], "probe": [Vector3(0, 3, -7), Vector3(14.5, 9.2, 14.5)]},
		{"id": "stacks", "box": [-25, -70.25, 25, -14.25], "amb": "archives", "mood": [0.016, Color(0.07, 0.05, 0.12), 1.5, 0.9], "title": "THE STACKS", "sub": "RECORD HALL A",
			"fog": [Vector3(0, 8, -42), Vector3(48, 16, 56), 0.016, Color(0.75, 0.7, 0.95)], "probe": [Vector3(0, 6, -42), Vector3(48.5, 30.5, 56)],
			"checkpoint": {"pos": Vector3(0, 0, -17), "yaw": 0.0}},
		{"id": "index", "box": [-15, -98.25, 15, -70.25], "amb": "archives", "mood": cold, "title": "INDEX CHAMBER", "sub": "CATALOGUE LOCK",
			"probe": [Vector3(0, 5, -84), Vector3(28.5, 14.2, 28)], "checkpoint": {"pos": Vector3(0, 0, -73), "yaw": 0.0}},
		{"id": "cold", "box": [-7, -140.25, 13, -98.25], "amb": "corridor", "mood": [0.014, Color(0.04, 0.07, 0.1), 1.45, 0.8], "title": "COLD STORAGE", "sub": "STASIS RECORDS",
			"fog": [Vector3(0, 2, -119), Vector3(12, 5, 41), 0.03, Color(0.7, 0.85, 1.0)], "checkpoint": {"pos": Vector3(0, 0, -101), "yaw": 0.0}},
		{"id": "hall", "box": [-21, -185, 21, -140.25], "amb": "archives", "mood": [0.012, Color(0.07, 0.06, 0.12), 1.5, 0.85], "title": "THE READING HALL", "sub": "SANCTUM",
			"fog": [Vector3(0, 6, -162), Vector3(40, 12, 43), 0.012, Color(0.75, 0.75, 1.0)], "probe": [Vector3(0, 6, -162), Vector3(40.5, 24.5, 44)]},
	]


# ===================================================================== script
func script(d) -> void:
	var A = G.audio
	var H = G.hud
	var F: Dictionary = G.progress.flags

	if F.has("s4_index"):
		doors.index.unlock(false)

	# the Stacks: phantoms flicker in among the shelves, turrets wake on the walls
	if not F.has("s4_stacks"):
		d.encounters.stacks = Director.Encounter.new(d, "stacks", {
			"start": func(e):
				A.duck(0.25, 0.4)
				e.later(0.3, func():
					set_group("stacks", "off")
					A.play("lights_out", 0.0))
				e.later(1.6, func():
					set_group("stacks", "on")
					A.play("lights_on", -2.0); A.duck(1.0, 1.0)),
			"first_delay": 1.8,
			"gaps": [1.5],
			"waves": [
				func(e):
					A.stinger("encounter"); A.set_combat(true)
					for p in [Vector3(-4, 0.3, -46), Vector3(4, 0.3, -52), Vector3(0, 0.3, -60)]:
						e.spawn_later(randf() * 0.6, "phantom", p, {}, func(ph): A.play3d("phantom", ph.center(), 4.0))
					d.after(1.5, func(): H.hint("Blades pass through phantoms  ·  strike as they cast, or deflect their orbs  ·  dashes always connect", 7.0)),
				func(e):
					for t in points.stack_turrets:
						e.spawn("turret", t[0], {"normal": t[1]})
					e.spawn_later(0.5, "phantom", Vector3(0, 0.3, -36))
					e.spawn_later(0.9, "phantom", Vector3(-6, 0.3, -64)),
			],
			"clear": func(_e):
				A.set_combat(false)
				F.s4_stacks = true
				A.stinger("clear"),
			"reset": func(_e):
				set_group("stacks", "on")
				A.set_combat(false); A.duck(1.0, 0.5),
		})
		d.trigger([-6, -44, 6, -36], func(): d.encounters.stacks.begin(), "stacks")

	# cold storage scare: lights fail, a stalker shimmers past the pods, then attacks
	if not F.has("s4_cold"):
		d.trigger([-6, -114, 6, -108], func():
			F.s4_cold = true
			A.duck(0.1, 0.3)
			A.stinger("scare")
			set_group("cold", "off")
			A.play("lights_out", 0.0)
			A.play3d("phantom", Vector3(0, 1.5, -126), 2.0, 0.6)
			d.after(1.8, func():
				set_group("cold", "on")
				A.play("lights_on", -4.0)
				A.duck(1.0, 2.0)
				var s = G.enemies.spawn("stalker", Vector3(0, 0, -132))
				A.set_combat(true)
				s.tree_exiting.connect(func(): A.set_combat(false))), "cold")

	# the Archivist
	if not G.progress.bosses.has("archivist"):
		d.encounters.hall = Director.Encounter.new(d, "hall", {
			"start": func(e):
				doors.hall.lock(true)
				A.duck(0.12, 0.6)
				A.set_tension(0.8)
				set_group("hall", "off")
				e.later(1.2, func(): A.play("boss_intro", 0.0))
				e.later(2.0, func():
					set_group("hall", "on")
					H.area("ARCHIVIST", "KEEPER OF RECORDS")),
			"first_delay": 2.2,
			"waves": [func(e):
				var b = e.spawn("archivist", points.hall_center + Vector3(0, 0, -6), {"center": points.hall_center, "radius": 16.0})
				b.facing = 0.0
				H.boss(b, b.boss_name)
				A.set_boss_music(true); A.duck(1.0, 1.0)
				d.after(6.0, func(): H.hint("It floats beyond your blade  ·  [b]RMB[/b] parry its orbs back into it  ·  [b]F[/b] grapple drags it down", 8.0))],
			"clear": func(_e):
				A.set_boss_music(false)
				G.progress.bosses.archivist = true
				d.after(3.5, func():
					A.stinger("clear")
					H.message("THE ARCHIVE FALLS SILENT", 3.0)
					doors.hall.unlock(false)
					item(points.hall_center + Vector3(0, 1.3, 0), "leap", "ability_leap")
					d.checkpoint = {"pos": Vector3(0, 0, -144), "yaw": 0.0}),
			"reset": func(_e):
				doors.hall.unlock(false)
				set_group("hall", "on")
				A.set_boss_music(false); A.duck(1.0, 0.5); A.set_tension(0.0)
				H.boss(null),
		})
		d.trigger([-15, -178, 15, -146], func(): d.encounters.hall.begin(), "hall")
	elif not G.progress.abilities.has("leap"):
		item(points.hall_center + Vector3(0, 1.3, 0), "leap", "ability_leap")


func on_enter(d, entry: String, first_time: bool) -> void:
	G.fx.set_rain(false)
	if first_time:
		d.after(2.0, func(): G.hud.hint("Archive silence protocol in effect  ·  [b]E[/b] scan visor reads the records", 5.0))
