class_name Sector5
extends Level
## Sector 5 — BLOOM HEART: the colony's body, grown through the station's root.
## Landing → the Gut (spore pods, mites) → the Throat (vertical shaft) → the Vein → the Heart.
## Heart → Avatar → escape: climb the Throat with the grapple, run the Gut, ride the lift out.

const ESCAPE_TIME := 180.0
var m := {}
var escape := false
var escape_t := 0.0
var was_dead := false
var quake_t := 0.0
var drip_t := 0.0
var finished := false
var falling: Array = []
var pad := Vector3(0, 0, -4)


func configure_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.003, 0.006)
	env.ambient_light_color = Color(0.4, 0.2, 0.26)
	env.volumetric_fog_albedo = Color(0.95, 0.6, 0.7)
	env.volumetric_fog_anisotropy = 0.35


func build_content() -> void:
	sector_id = "s5"
	sector_name = "BLOOM HEART"
	moon_max = 0.0
	kill_y = -40.0
	m.flesh = pbr("fleshwall", 0.0, 1.0)
	m.bone = pbr("bone", 0.0, 1.0)
	m.chasm = pbr("chasm_wall", 0.4, 1.0)
	m.vein = emissive(Color(1.0, 0.25, 0.5), 1.6)
	m.floor_vein = emissive(Color(1.0, 0.25, 0.45), 0.15)
	m.spore = emissive(Color(0.8, 1.0, 0.3), 1.4)
	build_landing()
	build_gut()
	build_throat()
	build_heart()
	define_zones()
	entries = {
		"lift": {"pos": Vector3(0, 0, -7), "yaw": 0.0},
		"heart": {"pos": Vector3(0, -24, -112), "yaw": 0.0},
		"throat": {"pos": Vector3(0, -24, -88), "yaw": PI},
	}


func rib_arches(x0: float, x1: float, z0: float, z1: float, y0: float, h: float, every := 3.0) -> void:
	var z := z1 - 1.0
	while z > z0:
		box(x0, y0, z - 0.3, x0 + 0.5, y0 + h, z + 0.3, m.bone, {"uv": 1.0})
		box(x1 - 0.5, y0, z - 0.3, x1, y0 + h, z + 0.3, m.bone, {"uv": 1.0})
		box(x0, y0 + h - 0.6, z - 0.3, x1, y0 + h, z + 0.3, m.bone, {"uv": 1.0, "collide": false})
		z -= every


func vein_glow(a: Vector3, b: Vector3, r := 0.08, mat: Material = null) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = a.distance_to(b); cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = mat if mat else m.vein
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_transform = cyl_xform(a, b)


func pulse_light(p: Vector3, col: Color, energy: float, rng: float, speed := 1.3) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = col
	l.omni_range = rng
	l.light_volumetric_fog_energy = 1.5
	add_child(l)
	var ph := randf() * TAU
	animated.append(func(t, _dt):
		var k := pow(0.5 + 0.5 * sin(t * TAU / speed + ph), 3.0)
		l.light_energy = energy * (0.45 + 0.55 * k))


# ===================================================================== H1 — Landing
func build_landing() -> void:
	room({"x0": -7, "x1": 7, "z0": -14, "z1": 0, "h": 8, "wall": mats.wall_dark, "open": {"n": [{"c": 0, "w": 4, "h": 4.5}]}})
	elevator(pad, "s2", "from_heart", "ASCENDING TO THE UNDERCITY", func(): return not escape)
	save_station(Vector3(-5, 0, -11), "s5_landing")
	var rnd := RandomNumberGenerator.new(); rnd.seed = 501
	for i in 6:
		bloom_growth(rnd.randf_range(-6.5, 6.5), rnd.randf_range(0, 7), -13.6, rnd.randf_range(0.6, 1.4), rnd)
	fixture({"x": 0, "y": 7.8, "z": -7, "color": Color(1.0, 0.75, 0.7), "intensity": 6, "distance": 14, "size": Vector3(2, 0.1, 2), "shadow": true, "group": "landing"})
	fixture({"x": 4, "y": 7.8, "z": -11, "color": Color(1.0, 0.2, 0.2), "intensity": 6, "distance": 12, "size": Vector3(0.6, 0.1, 0.6), "group": "alarm"})
	hologram(Vector3(0, 6, -0.6), 0, 5, 1.8, [{"text": "根", "y": 110, "size": 80}, {"text": "STATION ROOT // CONTAMINATED", "y": 195}], Color(1.0, 0.4, 0.5))
	scannable(Vector3(0, 6, -0.6), "STATION ROOT",
		"The arcology's foundation shaft, sunk into the planet's crust.\nThe Bloom took root here first. Everything above grew from what is down here.")


# ===================================================================== H2 — The Gut
func build_gut() -> void:
	room({"x0": -4, "x1": 4, "z0": -58, "z1": -14.5, "h": 7, "wall": m.flesh, "floor": m.flesh, "ceil": m.flesh, "walls": {"s": false},
		"open": {"w": [{"c": -33, "w": 2.5, "h": 3}], "n": [{"c": 0, "w": 4, "h": 4.5}]}})
	rib_arches(-4, 4, -58, -14.5, 0, 7, 3.0)
	var rnd := RandomNumberGenerator.new(); rnd.seed = 502
	for i in 14:
		var z := rnd.randf_range(-56, -16)
		var side := -1.0 if i % 2 == 0 else 1.0
		vein_glow(Vector3(side * 3.9, rnd.randf_range(0.2, 2.0), z), Vector3(side * 3.9, rnd.randf_range(4.5, 6.8), z + rnd.randf_range(-3, 3)), rnd.randf_range(0.05, 0.12))
	for z in [-20.0, -32.0, -44.0, -54.0]:
		pulse_light(Vector3(0, 6.0, z), Color(1.0, 0.3, 0.45), 2.6, 11.0)
	for p in [Vector3(-2.5, 0.0, -26), Vector3(2.6, 0.0, -38), Vector3(-2.6, 0.0, -47)]:
		bloom_growth(p.x, 0.0, p.z, 0.9, rnd)
	# phase nook (ki shard)
	room({"x0": -9, "x1": -4.5, "z0": -36, "z1": -30, "h": 4, "walls": {"e": false}, "wall": m.flesh, "floor": m.flesh, "ceil": m.flesh})
	phase_barrier(-4.45, 0, -34.25, -4.05, 3, -31.75)
	item(Vector3(-7, 1.0, -33), "shard", "s5_shard_gut")
	points.gut_pods = [Vector3(-2.8, 0, -22), Vector3(2.8, 0, -29), Vector3(-2.8, 0, -41), Vector3(2.8, 0, -50)]
	scannable(Vector3(3.9, 1.6, -18), "DIGESTIVE TRACT",
		"Station conduit, lined with Bloom tissue. It is warm. It contracts, slowly, every few seconds.\nThe pods along the walls react to body heat.")


# ===================================================================== H3 — The Throat (shaft)
func build_throat() -> void:
	var X0 := -14.0; var X1 := 14.0; var Z0 := -92.0; var Z1 := -58.5; var Y0 := -24.0; var H := 32.0
	room({"x0": X0, "x1": X1, "z0": Z0, "z1": Z1, "y0": Y0, "h": H, "wall": m.chasm, "floor": m.flesh,
		"open": {"s": [{"c": 0, "w": 4, "h": 4.5, "y": 24.0}], "n": [{"c": 0, "w": 4, "h": 4.5}]}})
	# entry ledge (top 0)
	box(X0, -0.5, -62.0, X1, 0.0, Z1, mats.dark_metal, {"uv": 2.0})
	collider(X0, 0.0, -62.05, X1, 1.1, -61.95)
	box(X0, 1.0, -62.04, X1, 1.08, -61.96, mats.dark_metal, {"collide": false})
	# descending/ascending ledges
	var ledges := [[4.0, -74.0, 14.0, -68.0, -6.0], [-14.0, -80.0, -4.0, -74.0, -12.0], [4.0, -90.0, 14.0, -82.0, -18.0]]
	for l in ledges:
		box(l[0], l[4] - 0.5, l[1], l[2], l[4], l[3], mats.dark_metal, {"uv": 2.0})
		strip(l[0], l[4] - 0.02, l[1] - 0.02, l[2], l[4] + 0.04, l[1] + 0.08, m.vein)
	# grapple anchors for the climb out
	grapple_point(Vector3(6.0, -13.0, -86))
	grapple_point(Vector3(-9, -8.0, -77))
	grapple_point(Vector3(9, -2.0, -71))
	grapple_point(Vector3(0, 3.5, -61.0))
	# leap alcove above L2 (energy tank)
	box(-14, -10.3, -84.5, -9, -10.0, -80.0, mats.dark_metal)
	item(Vector3(-12, -9.0, -82.5), "tank", "s5_tank_throat")
	# organic overgrowth: hanging tendrils and pulsing veins
	var rnd := RandomNumberGenerator.new(); rnd.seed = 503
	for i in 10:
		var x := rnd.randf_range(X0 + 1, X1 - 1)
		var z := rnd.randf_range(Z0 + 1, Z1 - 4)
		tendril([Vector3(x, 8, z), Vector3(x + rnd.randf_range(-1, 1), rnd.randf_range(-6, 2), z + rnd.randf_range(-1, 1))], rnd.randf_range(0.06, 0.14))
	for i in 12:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := rnd.randf_range(Z0 + 1, Z1 - 1)
		vein_glow(Vector3(side * 13.9, rnd.randf_range(-24, -10), z), Vector3(side * 13.9, rnd.randf_range(-6, 6), z + rnd.randf_range(-4, 4)), 0.1)
	pulse_light(Vector3(0, -20, -75), Color(1.0, 0.3, 0.45), 4.0, 22.0, 1.4)
	pulse_light(Vector3(0, -6, -75), Color(1.0, 0.35, 0.5), 3.0, 18.0, 1.4)
	fixture({"x": 0, "y": 7.6, "z": -64, "color": Color(1.0, 0.7, 0.6), "intensity": 5, "distance": 16, "size": Vector3(1.5, 0.12, 1.5), "group": "throat"})
	scannable(Vector3(0, 1.0, -61.9), "THE THROAT",
		"The station's root shaft, 24 metres straight down into living tissue.\nThe way down is easy. Note the anchor points. The way back up will not be.", {"critical": true})


# ===================================================================== H4 + H5 — Vein and Heart chamber
func build_heart() -> void:
	room({"x0": -3, "x1": 3, "z0": -108, "z1": -92.5, "y0": -24, "h": 6, "wall": m.flesh, "floor": m.flesh, "ceil": m.flesh, "walls": {"s": false, "n": false}})
	rib_arches(-3, 3, -108, -92.5, -24, 6, 2.5)
	pulse_light(Vector3(0, -19, -100), Color(1.0, 0.25, 0.4), 2.2, 9.0, 1.0)
	var X0 := -24.0; var X1 := 24.0; var Z0 := -156.0; var Z1 := -108.5; var Y0 := -24.0; var H := 30.0
	room({"x0": X0, "x1": X1, "z0": Z0, "z1": Z1, "y0": Y0, "h": H, "wall": m.flesh, "floor": m.flesh, "ceil": m.flesh,
		"open": {"s": [{"c": 0, "w": 4, "h": 4.5}]}})
	var d := Door.new(); add_child(d); d.setup(self, Vector3(0, Y0, -108.25), "x", 4, 4.5, false); doors.heart = d
	var c := Vector3(0, Y0, -132)
	points.heart_center = c
	var slots: Array = []
	for i in 5:
		var a := i * TAU / 5.0 + PI / 2
		slots.append(c + Vector3(cos(a), 0, sin(a)) * 9.5)
	points.limb_slots = slots
	for s in slots:
		var cm := CylinderMesh.new(); cm.top_radius = 1.4; cm.bottom_radius = 1.8; cm.height = 0.3; cm.radial_segments = 20
		node_mesh(cm, m.bone, s + Vector3(0, 0.1, 0))
	# bone colonnade
	for i in 12:
		var a := i * TAU / 12.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 20.0
		box(p.x - 0.9, Y0, p.z - 0.9, p.x + 0.9, Y0 + H, p.z + 0.9, m.bone, {"uv": 2.0})
	var rnd := RandomNumberGenerator.new(); rnd.seed = 505
	for i in 24:
		var a := rnd.randf() * TAU
		var r := rnd.randf_range(13.0, 22.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		vein_glow(Vector3(p.x, Y0 + 0.05, p.z), c + Vector3(cos(a) * 4.0, 0.05, sin(a) * 4.0), rnd.randf_range(0.05, 0.12), m.floor_vein)
	for i in 8:
		var a := i * TAU / 8.0
		pulse_light(c + Vector3(cos(a) * 16.0, 3.0, sin(a) * 16.0), Color(1.0, 0.3, 0.45), 2.5, 14.0, 1.3)
	pulse_light(c + Vector3(0, 20, 0), Color(1.0, 0.45, 0.55), 5.0, 30.0, 1.3)
	scannable(Vector3(0, Y0 + 1.5, -109.2), "THE HEART CHAMBER",
		"Every vein on the station leads here. The beat is loud enough to feel in your teeth.\nWhatever you cut here, the colony cannot regrow.", {"critical": true})


func define_zones() -> void:
	var gut := [0.02, Color(0.12, 0.03, 0.05), 1.5, 0.95]
	zones = [
		{"id": "landing", "box": [-8, -14.25, 8, 1], "amb": "heart", "mood": [0.01, Color(0.08, 0.04, 0.05), 1.45, 0.85], "title": "BLOOM HEART", "sub": "STATION ROOT",
			"probe": [Vector3(0, 3, -7), Vector3(14.5, 8.2, 14.5)]},
		{"id": "gut", "box": [-10, -58.25, 4.5, -14.25], "amb": "heart", "mood": gut, "title": "THE GUT", "sub": "CONTAMINATED CONDUIT",
			"fog": [Vector3(0, 3, -36), Vector3(8, 7, 44), 0.03, Color(0.95, 0.6, 0.65)], "checkpoint": {"pos": Vector3(0, 0, -17), "yaw": 0.0}},
		{"id": "throat", "box": [-15, -92.25, 15, -58.25, -30, 9], "amb": "heart", "mood": gut, "title": "THE THROAT", "sub": "ROOT SHAFT",
			"fog": [Vector3(0, -10, -75), Vector3(28, 30, 34), 0.018, Color(0.95, 0.6, 0.65)], "probe": [Vector3(0, -8, -75), Vector3(28.5, 32.5, 34)],
			"checkpoint": {"pos": Vector3(0, 0, -60), "yaw": 0.0}},
		{"id": "vein", "box": [-4, -108.25, 4, -92.25, -30, -15], "amb": "heart", "mood": gut, "checkpoint": {"pos": Vector3(0, -24, -95), "yaw": 0.0}},
		{"id": "heart", "box": [-25, -157, 25, -108.25, -30, 8], "amb": "heart", "mood": [0.014, Color(0.1, 0.025, 0.045), 1.3, 0.75], "title": "THE HEART", "sub": "BLOOM CORE",
			"fog": [Vector3(0, -16, -132), Vector3(48, 16, 47), 0.014, Color(0.95, 0.55, 0.65)], "probe": [Vector3(0, -14, -132), Vector3(48.5, 30.5, 48)]},
	]


# ===================================================================== script
func script(d) -> void:
	var A = G.audio
	var H = G.hud
	var F: Dictionary = G.progress.flags
	set_group("alarm", "off")

	# the Gut: pods ripen as you pass; a hound pack hunts the tunnel
	if not F.has("s5_gut"):
		d.encounters.gut = Director.Encounter.new(d, "gut", {
			"setup": func(e):
				for p in points.gut_pods:
					e.spawn("spore_pod", p),
			"start": func(_e):
				A.play3d("crawler_hiss", Vector3(0, 1, -50), 6.0),
			"first_delay": 1.0,
			"waves": [func(e):
				A.stinger("encounter"); A.set_combat(true)
				for i in 4:
					e.spawn_later(i * 0.5, "hound", Vector3(randf_range(-2, 2), 0, -56))
				for i in 6:
					e.spawn_later(1.5 + i * 0.25, "mite", Vector3(randf_range(-2, 2), 0, -55))],
			"clear": func(_e):
				A.set_combat(false)
				F.s5_gut = true
				A.stinger("clear"),
			"reset": func(_e): A.set_combat(false),
		})
		d.trigger([-4, -40, 4, -34], func(): d.encounters.gut.begin(), "gut")

	# the Throat: a stalker waits at the bottom
	if not F.has("s5_throat"):
		d.trigger([-14, -92, 14, -59, -25, -20], func():
			F.s5_throat = true
			A.stinger("scare")
			A.play3d("stalker_shriek", Vector3(0, -22, -88), 6.0)
			d.after(1.5, func():
				G.enemies.spawn("stalker", Vector3(0, -24, -88))
				A.set_combat(true)), "throat")

	# the Heart, then the Avatar
	if not G.progress.bosses.has("heart"):
		d.encounters.heart = Director.Encounter.new(d, "heart", {
			"start": func(e):
				doors.heart.lock(true)
				A.duck(0.1, 0.6)
				A.set_tension(0.9)
				e.later(1.0, func(): A.play("boss_intro", 0.0))
				e.later(2.0, func(): H.area("THE BLOOM HEART", "COLONY CORE")),
			"first_delay": 2.2,
			"gaps": [3.0],
			"waves": [
				func(e):
					var b = e.spawn("heart", points.heart_center, {"slots": points.limb_slots})
					H.boss(b, b.boss_name)
					A.set_boss_music(true); A.duck(1.0, 1.0)
					d.after(6.0, func(): H.hint("Its limbs stick fast when they slam  ·  cut them then  ·  sever them all to open the Heart", 8.0)),
				func(e):
					A.play3d("matriarch_roar", points.heart_center + Vector3(0, 3, 0), 10.0, 0.6)
					G.fx.burst(points.heart_center + Vector3(0, 1, 0), {"count": 120, "color": Color(1.0, 0.3, 0.5), "speed": 9.0, "life": 1.4, "size": 0.2})
					var av = e.spawn("stalker", points.heart_center, {"avatar": true})
					av.set_cloak(false, true)
					H.boss(av, "AVATAR  //  BLOOM INCARNATE")
					H.area("AVATAR", "BLOOM INCARNATE"),
			],
			"clear": func(_e):
				G.progress.bosses.heart = true
				A.set_boss_music(false)
				H.boss(null)
				d.after(2.5, func(): start_escape(d)),
			"reset": func(_e):
				doors.heart.unlock(false)
				A.set_boss_music(false); A.duck(1.0, 0.5); A.set_tension(0.0)
				H.boss(null),
		})
		d.trigger([-18, -150, 18, -114, -25, -18], func(): d.encounters.heart.begin(), "heart")


func on_enter(d, entry: String, first_time: bool) -> void:
	G.fx.set_rain(false)
	if G.progress.bosses.has("heart") and not finished:
		start_escape(d)
	elif first_time:
		d.after(2.0, func(): G.hud.hint("The air is warm and wet  ·  something enormous is beating below", 5.0))


func start_escape(d) -> void:
	if escape:
		return
	escape = true
	escape_t = ESCAPE_TIME
	doors.heart.unlock(false)
	G.audio.set_escape_music(true)
	G.audio.play("escape_alarm", 0.0)
	G.audio.play("collapse", 2.0)
	G.player.add_shake(1.0)
	G.hud.message("ROOT COLLAPSE IMMINENT  ·  REACH THE LIFT", 4.0, true)
	set_group("alarm", "emergency")
	d.checkpoint = {"pos": Vector3(0, -24, -112), "yaw": PI}
	d.after(4.5, func(): G.hud.hint("Climb the Throat  ·  [b]F[/b] grapple anchor to anchor  ·  [b]SPACE[/b] twice for Kage Leap", 7.0))


func _drop_debris(near: Vector3) -> void:
	var p := near + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	var hit = G.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p + Vector3(0, 30, 0), 1))
	var top: float = hit.position.y - 0.4 if hit else p.y + 12.0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); var s := randf_range(0.4, 1.0); bm.size = Vector3(s, s * 0.8, s * 1.2)
	mi.mesh = bm
	mi.material_override = m.bone if randf() < 0.5 else mats.dark_metal
	add_child(mi)
	mi.global_position = Vector3(p.x, top, p.z)
	mi.rotation = Vector3(randf(), randf(), randf()) * TAU
	falling.append({"node": mi, "vel": 0.0, "floor": near.y, "size": s})
	G.audio.play3d("sparks", mi.global_position, 0.0, 0.7)


func sector_update(d, dt: float) -> void:
	for i in range(falling.size() - 1, -1, -1):
		var f: Dictionary = falling[i]
		f.vel += 22.0 * dt
		f.node.global_position.y -= f.vel * dt
		f.node.rotation.x += dt * 3.0
		var P = G.player
		if f.node.global_position.distance_to(P.eye_pos()) < 0.6 + f.size * 0.5:
			P.receive_hit(14, f.node.global_position, "melee")
			f.node.global_position.y = -999.0
		if f.node.global_position.y <= f.floor + f.size * 0.4:
			if f.node.global_position.y > -900.0:
				G.fx.burst(f.node.global_position, {"count": 16, "color": Color(0.4, 0.35, 0.35), "speed": 4.0, "life": 0.6, "size": 0.2})
				G.audio.play3d("land", f.node.global_position, 2.0, 0.6)
			f.node.queue_free()
			falling.remove_at(i)
	if not escape or finished:
		return
	var P = G.player
	if P.dead:
		was_dead = true
		return
	if was_dead:
		was_dead = false
		escape_t = ESCAPE_TIME
		G.audio.set_escape_music(true)
	if G.state == "playing":
		escape_t -= dt
	G.hud.set_timer(max(escape_t, 0.0))
	if escape_t <= 0.0:
		G.hud.message("THE ROOT COLLAPSED", 3.0, true)
		P.hazard_damage(99999.0, "lava")
		return
	quake_t -= dt
	if quake_t <= 0.0:
		quake_t = randf_range(2.0, 4.5)
		P.add_shake(randf_range(0.25, 0.6))
		G.audio.play("collapse", -6.0, randf_range(0.8, 1.2))
		_drop_debris(P.global_position)
	drip_t -= dt
	if drip_t <= 0.0:
		drip_t = 0.15
		G.fx.emit(P.global_position + Vector3(randf_range(-6, 6), 6.0, randf_range(-6, 6)), Vector3(0, -3, 0), Color(0.6, 0.3, 0.3), 0.08, 1.0)
	# the lift: out
	var flat := Vector2(P.global_position.x - pad.x, P.global_position.z - pad.z).length()
	if flat < 2.0 and P.on_ground and P.global_position.y > -1.0:
		finished = true
		G.hud.set_timer(-1.0)
		G.audio.set_escape_music(false)
		G.audio.play("hydraulic", 0.0)
		G.progress.flags.game_complete = true
		G.save_at("s5", Vector3(0, 0, -7), 0.0)
		d.game_complete("The lift climbs out of the root as the shaft folds shut beneath it.\n" +
			"Above, in the Undercity, the neon flickers. The thralls in the streets go still,\n" +
			"then fold to the ground like cut puppets. The rhythm has stopped.\n\n" +
			"KUROGANE-9 is silent. For the first time in a long time, it is only a station.\n\n" +
			"Slashboy sheathes the blade.")
