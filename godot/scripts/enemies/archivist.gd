class_name Archivist
extends Boss
## Archives boss: the station AI's last librarian, a towering violet hologram. Mostly out of reach.
## Teleports around the reading hall. Radial orb rings (deflect them back into it), sweeping laser
## walls (phase-dash through), and a decoy split: three false copies, only the scan visor shows which
## one is real. Strike the real one to shatter the illusion and drag it to the floor.

var robe_mat: ShaderMaterial
var mask_mat: StandardMaterial3D
var core_mat: StandardMaterial3D
var figure: Node3D
var hands: Array = []
var pages: Array = []
var decoys: Array = []        # {node, mat, pos}
var walls: Array = []         # {node, n, d, speed, hit, end}
var attack_cd := 3.0
var bob := 0.0
var hover_y := 4.5
var target_y := 4.5
var center_pt := Vector3.ZERO
var arena_r := 16.0
var bursts := 0
var burst_t := 0.0
var spawned_phantoms := false
var real_slot := 0
var solid_k := 0.0
const TINT_A := Vector3(0.7, 0.35, 1.3)
const TINT_B := Vector3(1.8, 1.0, 2.6)


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "archivist"
	boss_name = "ARCHIVIST // KEEPER OF RECORDS"
	max_hp = 800; hp = 800
	radius = 1.6; center_y = 3.0
	organic = false; drop_count = 10
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = 0
	center_pt = opts.get("center", pos)
	arena_r = opts.get("radius", 16.0)
	scan_info = {"title": "ARCHIVIST // KEEPER OF RECORDS", "text": "The station AI's cataloguing persona, rewritten by the Bloom into a guardian.\nIt hovers beyond the reach of a blade. Send its own orbs back at it.\nIts light walls burn: Phase Step through them. When it splits, the scan visor sees the truth."}
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new(); sh.radius = 1.2; sh.height = 5.0
	cs.shape = sh; cs.position.y = 2.8
	add_child(cs)
	rig = Node3D.new(); add_child(rig)
	robe_mat = _holo_mat()
	figure = _make_figure(rig, robe_mat, true)
	set_state("intro")
	global_position.y = hover_y


func _holo_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/hologram_solid.gdshader")
	m.set_shader_parameter("tint_a", TINT_A)
	m.set_shader_parameter("tint_b", TINT_B)
	return m


func _make_figure(parent: Node3D, mat: ShaderMaterial, real: bool) -> Node3D:
	var f := Node3D.new(); parent.add_child(f)
	var robe := CylinderMesh.new(); robe.top_radius = 0.45; robe.bottom_radius = 1.5; robe.height = 4.2; robe.radial_segments = 24
	Creatures.add(f, robe, mat, Vector3(0, 2.4, 0))
	var mantle := CylinderMesh.new(); mantle.top_radius = 0.6; mantle.bottom_radius = 1.4; mantle.height = 0.9; mantle.radial_segments = 24
	Creatures.add(f, mantle, mat, Vector3(0, 4.3, 0))
	var hood := SphereMesh.new(); hood.radius = 0.62; hood.height = 1.5
	Creatures.add(f, hood, mat, Vector3(0, 5.0, 0.05), Vector3(1, 1.15, 1.05))
	var m: Material = mat
	if real:
		mask_mat = Creatures.emissive(Color(0.85, 0.7, 1.0), 2.5)
		core_mat = Creatures.emissive(Color(0.8, 0.45, 1.0), 3.0)
		m = mask_mat
	var mask := SphereMesh.new(); mask.radius = 0.36; mask.height = 0.5
	Creatures.add(f, mask, m, Vector3(0, 4.95, -0.42), Vector3(1, 1.3, 0.35))
	for s in [-1, 1]:
		var eye := BoxMesh.new(); eye.size = Vector3(0.16, 0.035, 0.02)
		Creatures.add(f, eye, mat, Vector3(s * 0.13, 5.02, -0.55))
	Creatures.add(f, Creatures.sphere(0.32, 16, 10), core_mat if real else mat, Vector3(0, 3.6, -0.75))
	# runic rings around the body
	for i in 3:
		var tr := TorusMesh.new(); tr.inner_radius = 1.9 + i * 0.35; tr.outer_radius = 1.95 + i * 0.35; tr.rings = 48; tr.ring_segments = 4
		var ring := Creatures.add(f, tr, mat, Vector3(0, 1.5 + i * 1.2, 0))
		ring.rotation = Vector3(0.3 * (i - 1), 0, 0.2)
		if real:
			pages.append({"node": ring, "spin": (0.4 + i * 0.25) * (1 if i % 2 == 0 else -1)})
	# floating hands
	for s in [-1, 1]:
		var h := Node3D.new(); h.position = Vector3(s * 2.0, 3.2, -0.6); f.add_child(h)
		var palm := BoxMesh.new(); palm.size = Vector3(0.45, 0.6, 0.12)
		Creatures.add(h, palm, mat)
		for k in 4:
			var fm := BoxMesh.new(); fm.size = Vector3(0.07, 0.45, 0.07)
			Creatures.add(h, fm, mat, Vector3(-0.15 + k * 0.1, 0.5, 0), Vector3.ONE, Vector3(0, 0, (k - 1.5) * 0.12))
		if real:
			hands.append({"node": h, "s": s})
	# drifting data pages
	if real:
		for i in 10:
			var q := QuadMesh.new(); q.size = Vector2(0.4, 0.55)
			var pg := Creatures.add(f, q, mat)
			pages.append({"node": pg, "orbit": i * TAU / 10.0, "r": 3.0 + randf() * 0.8, "y": 1.5 + randf() * 3.5})
	return f


func take_damage(dmg: float, dir: Vector3, dmg_kind: String) -> void:
	if not alive or state in ["intro", "blink_out", "blink_in"]:
		return
	if state == "clones" or state == "clones_cast":
		_shatter_decoys(true)
		super.take_damage(dmg, dir, dmg_kind)
		if alive:
			_fall()
		return
	super.take_damage(dmg, dir, dmg_kind)
	if alive and dmg_kind == "reflect" and state != "drained":
		G.audio.play3d("glitch", center(), 4.0)
		if randf() < 0.35:
			_fall()


## Kusari grapple: the chain drags it down to the floor.
func grappled(_from: Vector3) -> void:
	if not alive or state in ["intro", "blink_out", "blink_in", "drained", "dead"]:
		return
	if state in ["clones", "clones_cast"]:
		_shatter_decoys(true)
	G.audio.play3d("glitch", center(), 6.0, 0.6)
	_fall()


func on_hurt(_dmg: float, _dir: Vector3, _k: String) -> void:
	solid_k = 1.0
	if hp < max_hp * 0.5 and phase == 1:
		phase = 2
		G.hud.message("THE ARCHIVE REMEMBERS", 2.0, true)
		roar("phantom", 8.0)


func on_die(_dir: Vector3) -> void:
	_shatter_decoys(false)
	_clear_walls()
	G.hit_stop(0.35)
	G.audio.play3d("glitch", center(), 10.0, 0.5)
	G.audio.play3d("phantom", center(), 8.0, 0.4)
	for i in 8:
		G.main.get_tree().create_timer(i * 0.25).timeout.connect(func():
			if is_instance_valid(self):
				var p := center() + Vector3(randf_range(-1.5, 1.5), randf_range(-2, 2), randf_range(-1.5, 1.5))
				G.audio.play3d("glitch", p, 2.0, randf_range(0.6, 1.4))
				G.fx.burst(p, {"count": 50, "color": Color(1.4, 0.8, 2.8), "speed": 7.0, "life": 1.0, "size": 0.09})
				G.fx.light_flash(p, Color(0.8, 0.5, 1.0), 10.0, 0.25))


func _fall() -> void:
	set_state("drained")
	target_y = 0.4
	G.audio.play3d("glitch", center(), 6.0, 0.7)
	G.hud.message("ARCHIVIST DESTABILISED", 1.2)


func _slot(i: int, n: int, off := 0.0) -> Vector3:
	var a := off + i * TAU / n
	return center_pt + Vector3(cos(a), 0, sin(a)) * (arena_r * 0.62)


func _teleport_to(p: Vector3) -> void:
	G.fx.burst(center(), {"count": 40, "color": Color(1.2, 0.7, 2.6), "speed": 5.0, "life": 0.5, "size": 0.08})
	global_position = Vector3(p.x, global_position.y, p.z)
	G.fx.burst(center(), {"count": 40, "color": Color(1.2, 0.7, 2.6), "speed": 5.0, "life": 0.5, "size": 0.08})
	G.audio.play3d("phantom", center(), 4.0, 0.7)


func _orb_ring(count: int, speed: float, y_off := 0.0, homing := 0.0) -> void:
	var from := center() + Vector3(0, y_off, 0)
	var P = G.player
	var aim: Vector3 = (P.eye_pos() - from)
	var tilt: float = atan2(aim.y, Vector2(aim.x, aim.z).length())
	var off := randf() * TAU
	for i in count:
		var a := off + i * TAU / count
		var d := Vector3(cos(a), 0, sin(a))
		d.y = tan(tilt) * 0.85
		mgr.spawn_bolt(from + d.normalized() * 1.5, d.normalized() * speed, self, {"homing": homing, "color": Color(1.6, 0.8, 3.2), "size": 0.9, "dmg": 12.0, "life": 7.0})
	G.audio.play3d("beam_fire", from, 2.0, 1.6)
	G.fx.ring(Vector3(from.x, from.y, from.z), Color(1.4, 0.8, 2.8), 4.0, 0.4)


## A vertical wall of light that crosses the arena. Only a phase dash (invulnerable) gets through.
func _spawn_wall(n: Vector3, speed: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(arena_r * 2.4, 5.0, 0.12)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.4, 0.5, 2.4, 0.55)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new(); l.light_color = Color(0.8, 0.4, 1.0); l.light_energy = 3.0; l.omni_range = 9.0
	mi.add_child(l)
	G.level.add_child(mi)
	var d0 := -arena_r - 1.0
	mi.global_transform = Transform3D(Basis.looking_at(n, Vector3.UP), center_pt + n * d0 + Vector3(0, 2.5, 0))
	walls.append({"node": mi, "mat": m, "n": n, "d": d0, "speed": speed, "hit": false, "end": arena_r + 1.0})
	G.audio.play3d("beam_charge", center_pt + n * d0, 6.0, 0.7)


func _update_walls(dt: float) -> void:
	var P = G.player
	for i in range(walls.size() - 1, -1, -1):
		var w: Dictionary = walls[i]
		var prev: float = w.d
		w.d += w.speed * dt
		w.node.global_position = center_pt + w.n * w.d + Vector3(0, 2.5, 0)
		w.mat.albedo_color.a = 0.45 + randf() * 0.2
		var pd: float = (P.global_position - center_pt).dot(w.n)
		if not w.hit and ((prev <= pd and w.d > pd) or abs(w.d - pd) < 0.25) and P.global_position.y < 5.0:
			w.hit = true
			var r: String = P.receive_hit(24, P.eye_pos() - w.n, "beam")
			if r == "evaded":
				G.hud.message("PHASED", 0.6)
				G.fx.cyan_burst(P.eye_pos() + P.forward(), 25)
			else:
				P.velocity += w.n * 9.0 + Vector3(0, 3, 0)
		if randf() < 0.5:
			var side = w.n.cross(Vector3.UP)
			G.fx.emit(w.node.global_position + side * randf_range(-arena_r, arena_r) + Vector3(0, randf_range(-2.5, 2.5), 0), Vector3(0, 1, 0), Color(1.4, 0.6, 2.6), 0.08, 0.4)
		if w.d > w.end:
			w.node.queue_free()
			walls.remove_at(i)


func _clear_walls() -> void:
	for w in walls:
		w.node.queue_free()
	walls.clear()


func _split() -> void:
	_shatter_decoys(false)
	real_slot = randi() % 4
	var off := randf() * TAU
	for i in 4:
		var p := _slot(i, 4, off)
		if i == real_slot:
			_teleport_to(p)
			continue
		var holder := Node3D.new()
		G.level.add_child(holder)
		holder.global_position = Vector3(p.x, 0.4, p.z)
		var m := _holo_mat()
		_make_figure(holder, m, false)
		decoys.append({"node": holder, "mat": m, "pos": p})
		G.fx.burst(holder.global_position + Vector3(0, 3, 0), {"count": 30, "color": Color(1.2, 0.7, 2.6), "speed": 4.0, "life": 0.5, "size": 0.08})
	target_y = 0.4
	global_position.y = 0.4
	G.audio.play3d("glitch", center(), 8.0, 0.8)
	G.hud.message("WHICH ONE IS REAL?", 1.5)


func _shatter_decoys(revealed: bool) -> void:
	for dc in decoys:
		if is_instance_valid(dc.node):
			G.fx.burst(dc.node.global_position + Vector3(0, 3, 0), {"count": 40, "color": Color(1.6, 0.3, 0.3) if revealed else Color(1.2, 0.7, 2.6), "speed": 6.0, "life": 0.6, "size": 0.08})
			dc.node.queue_free()
	decoys.clear()


func dispose() -> void:
	_shatter_decoys(false)
	_clear_walls()
	super.dispose()


func update(dt: float, ws: float) -> void:
	var P = G.player
	state_t += dt
	bob += dt
	update_flash(dt)
	_update_walls(dt)
	var to: Vector3 = P.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir = to / max(dist, 0.001)
	attack_cd -= dt
	solid_k = max(0.0, solid_k - dt * 3.0) if state != "drained" else 0.6 + sin(state_t * 20.0) * 0.3
	robe_mat.set_shader_parameter("solid", solid_k)
	# decoys: under the scan visor they read as red static
	for dc in decoys:
		dc.mat.set_shader_parameter("decoy", 1.0 if P.scan_mode else 0.0)
		dc.node.rotation.y = G.yaw_to(P.global_position.x - dc.pos.x, P.global_position.z - dc.pos.z)
		dc.node.position.y = 0.4 + sin(bob * 1.3 + dc.pos.x) * 0.15
	if alive:
		facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 3.0)
		global_position.y = lerp(global_position.y, target_y + sin(bob * 1.1) * 0.25, min(1.0, dt * 2.5))
		for pg in pages:
			if pg.has("spin"):
				pg.node.rotation.y += pg.spin * dt
			else:
				pg.orbit += dt * 0.5
				pg.node.position = Vector3(cos(pg.orbit) * pg.r, pg.y + sin(bob + pg.orbit) * 0.3, sin(pg.orbit) * pg.r)
				pg.node.rotation.y = -pg.orbit
		for h in hands:
			h.node.position.y = 3.2 + sin(bob * 1.4 + h.s) * 0.2
	match state:
		"intro":
			robe_mat.set_shader_parameter("fade", min(1.0, state_t / 3.0))
			if state_t > 3.5:
				set_state("hover")
				attack_cd = 1.5
		"hover":
			target_y = hover_y
			var side := Vector3(-dir.z, 0, dir.x)
			velocity = side * 1.5 + (dir * 1.5 if dist > 14.0 else -dir * 1.0 if dist < 7.0 else Vector3.ZERO)
			var from_c := global_position - center_pt; from_c.y = 0
			if from_c.length() > arena_r * 0.8:
				velocity -= from_c.normalized() * 2.0
			if attack_cd <= 0.0:
				var r := randf()
				if r < 0.35:
					set_state("orbs"); bursts = 2 + phase; burst_t = 0.8
					G.audio.play3d("beam_charge", center(), 6.0, 1.3)
				elif r < 0.6:
					set_state("walls")
					G.hud.hint("Light walls burn  ·  [b]SHIFT[/b] Phase Step through them", 4.0)
				elif r < 0.82 or hp > max_hp * 0.85:
					set_state("blink_out")
				else:
					set_state("clones")
					_split()
					attack_cd = 0.0
		"orbs":
			velocity = Vector3.ZERO
			core_mat.emission_energy_multiplier = 3.0 + (1.0 - burst_t) * 6.0
			burst_t -= dt
			if burst_t <= 0.0 and bursts > 0:
				bursts -= 1
				burst_t = 1.1 if phase == 1 else 0.8
				_orb_ring(10 + phase * 2, 6.0 + phase, randf_range(-0.5, 0.5), 0.0)
				if phase == 2 and bursts % 2 == 0:
					var from := center()
					mgr.spawn_bolt(from, (P.eye_pos() - from).normalized() * 8.0, self, {"homing": 2.0, "color": Color(1.8, 0.9, 3.4), "size": 1.2, "dmg": 14.0, "life": 6.0})
			if bursts <= 0 and burst_t < -0.5:
				core_mat.emission_energy_multiplier = 3.0
				set_state("hover"); attack_cd = randf_range(2.0, 3.5) / phase
		"walls":
			velocity = Vector3.ZERO
			target_y = hover_y + 1.5
			for h in hands:
				h.node.position.x = h.s * (2.0 + min(1.0, state_t) * 0.8)
			if state_t > 1.0 and state_t - dt <= 1.0:
				var a := randf() * TAU
				_spawn_wall(Vector3(cos(a), 0, sin(a)), 7.0 + phase)
				if phase == 2:
					var b := a + PI * 0.5
					G.main.get_tree().create_timer(1.6).timeout.connect(func():
						if is_instance_valid(self) and alive:
							_spawn_wall(Vector3(cos(b), 0, sin(b)), 8.0))
			if state_t > 3.5:
				for h in hands:
					h.node.position.x = h.s * 2.0
				set_state("hover"); attack_cd = randf_range(2.5, 4.0) / phase
		"blink_out":
			velocity = Vector3.ZERO
			robe_mat.set_shader_parameter("fade", max(0.0, 1.0 - state_t / 0.4))
			if state_t > 0.5:
				var a := randf() * TAU
				_teleport_to(center_pt + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, arena_r * 0.7))
				set_state("blink_in")
		"blink_in":
			robe_mat.set_shader_parameter("fade", min(1.0, state_t / 0.4))
			if state_t > 0.6:
				robe_mat.set_shader_parameter("fade", 1.0)
				set_state("orbs"); bursts = 1; burst_t = 0.3
		"clones":
			velocity = Vector3.ZERO
			if state_t > 1.5:
				set_state("clones_cast")
		"clones_cast":
			velocity = Vector3.ZERO
			core_mat.emission_energy_multiplier = 3.0 + state_t * 4.0
			if state_t > 3.5:
				# every copy fires; the decoys' orbs are real too
				_orb_ring(8, 6.5, 0.0, 0.0)
				var real_pos := global_position
				for dc in decoys:
					global_position = Vector3(dc.pos.x, 0.4, dc.pos.z)
					_orb_ring(8, 6.5, 0.0, 0.0)
				global_position = real_pos
				_shatter_decoys(false)
				core_mat.emission_energy_multiplier = 3.0
				set_state("blink_out")
				attack_cd = 2.0
		"drained":
			velocity = Vector3.ZERO
			target_y = 0.4
			if state_t > 4.0:
				set_state("hover")
				attack_cd = 1.5
				if phase == 2 and not spawned_phantoms:
					spawned_phantoms = true
					for i in 2:
						var p := _slot(i, 2, randf() * TAU)
						mgr.spawn("phantom", p + Vector3(0, 0.3, 0), {"encounter": encounter})
		"dead":
			velocity = Vector3.ZERO
			robe_mat.set_shader_parameter("fade", max(0.0, 1.0 - state_t / 2.5))
			robe_mat.set_shader_parameter("solid", 1.0)
			rig.scale = Vector3(1.0 + state_t * 0.1, max(0.05, 1.0 - state_t * 0.35), 1.0 + state_t * 0.1)
			if state_t > 3.0:
				remove_me = true
	slide(ws)
	rotation.y = facing
