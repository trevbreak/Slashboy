class_name Warden
extends Boss
## Foundry boss: a towering security mech inside a hard-light dome. Two shield generators on its
## back can be torn off with the Kusari Grapple or destroyed with deflected missiles. Then the
## dome falls and the core is exposed (phase 2: faster, lava vents erupt).

var torso: Node3D
var hips: Node3D
var legs: Array = []
var laser_arm: Node3D
var pod: Node3D
var dome: MeshInstance3D
var dome_mat: ShaderMaterial
var core_mat: StandardMaterial3D
var visor_mat: StandardMaterial3D
var gens: Array = []          # {node, mat, alive, gp}
var shield_up := true
var attack_cd := 3.0
var beam: MeshInstance3D
var beam_mat: StandardMaterial3D
var beam_from := 0.0
var beam_to := 0.0
var beam_hit := false
var volley := 0
var volley_t := 0.0
var vent_t := 5.0
var vents: Array = []
var walk_t := 0.0
var step_t := 0.0
var arena_center := Vector3.ZERO
const S := 2.6


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "warden"
	boss_name = "WARDEN // FOUNDRY SECURITY"
	max_hp = 900; hp = 900
	radius = 3.0; center_y = 4.6
	organic = false; drop_count = 10
	arena_center = opts.get("center", pos)
	scan_info = {"title": "WARDEN // FOUNDRY SECURITY", "text": "Foundry security frame, 9 metres, Bloom-wired. A hard-light dome makes it untouchable.\nTwo generators on its back sustain the dome. Tear them away with the grapple,\nor send its own missiles back into them. Jump the low laser sweep."}
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 2.2; cap.height = 8.0
	cs.shape = cap; cs.position.y = 4.0
	add_child(cs)
	_build()
	set_state("intro")


func _build() -> void:
	var armor := Creatures.mech(Color(0.55, 0.42, 0.3))
	var dark := Creatures.mech(Color(0.16, 0.15, 0.16))
	flash_mats = [armor, dark]
	rig = Node3D.new(); add_child(rig)
	hips = Node3D.new(); hips.position.y = 3.3; rig.add_child(hips)
	torso = Node3D.new(); torso.position.y = 0.5; hips.add_child(torso)
	var b := func(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
		var bm := BoxMesh.new(); bm.size = size
		return Creatures.add(parent, bm, mat, pos, Vector3.ONE, rot)
	b.call(torso, Vector3(3.2, 2.2, 2.2), armor, Vector3(0, 1.3, 0))
	b.call(torso, Vector3(2.2, 1.0, 1.8), dark, Vector3(0, 0.0, 0))
	b.call(torso, Vector3(3.6, 0.5, 1.4), armor, Vector3(0, 2.55, 0.1))
	# core in the chest (exposed when the dome falls)
	core_mat = Creatures.emissive(Color(1.0, 0.45, 0.1), 2.0)
	Creatures.add(torso, Creatures.sphere(0.55, 24, 12), core_mat, Vector3(0, 1.3, -1.05))
	# head
	b.call(torso, Vector3(1.2, 0.8, 1.2), armor, Vector3(0, 2.95, -0.2))
	visor_mat = Creatures.emissive(Color(1.0, 0.2, 0.1), 3.0)
	b.call(torso, Vector3(1.0, 0.14, 0.05), visor_mat, Vector3(0, 3.0, -0.82))
	# left: missile pod, right: laser cannon
	pod = Node3D.new(); pod.position = Vector3(-2.3, 1.6, 0); torso.add_child(pod)
	b.call(pod, Vector3(1.2, 1.4, 1.6), armor, Vector3.ZERO)
	for i in 6:
		var tube := CylinderMesh.new(); tube.top_radius = 0.14; tube.bottom_radius = 0.14; tube.height = 0.3
		Creatures.add(pod, tube, dark, Vector3(-0.3 + (i % 2) * 0.6, 0.45 - (i / 2) * 0.45, -0.85), Vector3.ONE, Vector3(PI / 2, 0, 0))
	laser_arm = Node3D.new(); laser_arm.position = Vector3(2.3, 1.2, 0); torso.add_child(laser_arm)
	b.call(laser_arm, Vector3(0.9, 0.9, 1.6), armor, Vector3.ZERO)
	var barrel := CylinderMesh.new(); barrel.top_radius = 0.28; barrel.bottom_radius = 0.38; barrel.height = 2.2
	Creatures.add(laser_arm, barrel, dark, Vector3(0, -0.1, -1.6), Vector3.ONE, Vector3(PI / 2, 0, 0))
	# generators on the back
	for s in [-1, 1]:
		var g := Node3D.new(); g.position = Vector3(s * 1.0, 2.6, 1.4); torso.add_child(g)
		var pylon := CylinderMesh.new(); pylon.top_radius = 0.12; pylon.bottom_radius = 0.2; pylon.height = 1.2
		Creatures.add(g, pylon, dark, Vector3(0, 0.3, 0))
		var gm := Creatures.emissive(Color(0.3, 0.85, 1.0), 3.0)
		Creatures.add(g, Creatures.sphere(0.42, 20, 12), gm, Vector3(0, 1.1, 0))
		var ring := TorusMesh.new(); ring.inner_radius = 0.48; ring.outer_radius = 0.58; ring.rings = 24
		Creatures.add(g, ring, dark, Vector3(0, 1.1, 0))
		var gen := {"node": g, "mat": gm, "alive": true}
		gen.gp = {"pos": Vector3.ZERO, "get_pos": func(): return g.global_position + Vector3(0, 1.1, 0), "on_pull": func(): _destroy_gen(gen, true), "active": true, "node": g}
		G.level.grapple_points.append(gen.gp)
		gens.append(gen)
	# legs (digitigrade)
	for s in [-1, 1]:
		var hip := Node3D.new(); hip.position = Vector3(s * 1.1, 0, 0); hips.add_child(hip)
		b.call(hip, Vector3(0.9, 1.9, 1.1), armor, Vector3(0, -0.9, -0.2))
		var knee := Node3D.new(); knee.position = Vector3(0, -1.8, -0.3); hip.add_child(knee)
		b.call(knee, Vector3(0.7, 1.6, 0.8), dark, Vector3(0, -0.7, 0.3))
		b.call(knee, Vector3(1.2, 0.35, 1.9), armor, Vector3(0, -1.45, 0.0))
		legs.append({"hip": hip, "knee": knee, "s": s})
	# shield dome
	dome_mat = ShaderMaterial.new()
	dome_mat.shader = preload("res://shaders/phase_barrier.gdshader")
	dome_mat.set_shader_parameter("color", Color(0.3, 0.7, 1.0))
	dome = Creatures.add(rig, Creatures.sphere(4.6, 40, 20), dome_mat, Vector3(0, 3.6, 0), Vector3(1, 1.15, 1))
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# laser beam (hidden until sweeping)
	beam_mat = StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(4.0, 0.4, 0.2)
	var bm := BoxMesh.new(); bm.size = Vector3(0.25, 0.25, 40)
	beam = MeshInstance3D.new()
	beam.mesh = bm
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visible = false
	add_child(beam)


func _destroy_gen(gen: Dictionary, pulled: bool) -> void:
	if not gen.alive:
		return
	gen.alive = false
	gen.gp.active = false
	G.audio.play3d("explosion", gen.node.global_position, 6.0)
	G.fx.burst(gen.node.global_position, {"count": 50, "color": Color(0.5, 1.8, 3.0), "speed": 9.0, "life": 0.7, "size": 0.12})
	G.fx.light_flash(gen.node.global_position, Color(0.4, 0.8, 1.0), 12.0, 0.3)
	var away: Vector3 = (G.player.global_position - gen.node.global_position).normalized() if pulled else Vector3.UP
	G.fx.debris(gen.node, away * 9.0 + Vector3(0, 5, 0), Vector3(7, 4, 6))
	G.hud.message("GENERATOR DESTROYED", 1.5)
	if gens.all(func(g): return not g.alive):
		_drop_shield()


func _drop_shield() -> void:
	shield_up = false
	phase = 2
	dome.visible = false
	G.audio.play3d("sentinel_die", center(), 8.0, 0.5)
	G.audio.play3d("glitch", center(), 6.0)
	roar("stomp", 8.0)
	G.hud.message("SHIELD DOWN  ·  CORE EXPOSED", 2.5)
	core_mat.emission_energy_multiplier = 5.0
	set_state("stagger")


func take_damage(dmg: float, dir: Vector3, dmg_kind: String) -> void:
	if not alive or state == "intro":
		return
	if shield_up:
		if dmg_kind == "reflect":
			for g in gens:
				if g.alive:
					_destroy_gen(g, false)
					return
		G.audio.play3d("shield_hit", center() - dir * 3.0, 2.0, 0.6)
		G.fx.sparks(G.player.eye_pos() + G.player.forward() * 1.5, -dir, 10)
		return
	super.take_damage(dmg, dir, dmg_kind)


func on_die(_dir: Vector3) -> void:
	beam.visible = false
	for g in gens:
		g.gp.active = false
	visor_mat.emission_energy_multiplier = 0.0
	core_mat.emission_energy_multiplier = 8.0
	G.hit_stop(0.35)
	for i in 6:
		var t := i * 0.35
		G.main.get_tree().create_timer(t).timeout.connect(func():
			if is_instance_valid(self):
				var p := center() + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
				G.audio.play3d("explosion", p, 6.0)
				G.fx.burst(p, {"count": 40, "color": Color(3, 1.5, 0.5), "speed": 10.0, "life": 0.8, "size": 0.16})
				G.fx.light_flash(p, Color(1, 0.6, 0.3), 14.0, 0.25))


func _fire_missile() -> void:
	var P = G.player
	var from := pod.global_position + G.flat_forward(facing) * 1.0 + Vector3(0, 0.5, 0)
	var v = (P.eye_pos() - from).normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6)) * 9.0 + Vector3(0, 4.0, 0)
	mgr.spawn_bolt(from, v, self, {"homing": 1.6, "color": Color(4.0, 1.4, 0.3), "size": 1.1, "dmg": 16.0, "life": 6.0})
	G.audio.play3d("missile", from, 4.0)


func _vents_tick(dt: float) -> void:
	vent_t -= dt
	if vent_t <= 0.0:
		vent_t = 5.5
		for i in 3:
			var p: Vector3 = G.player.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			if i == 0:
				p = G.player.global_position
			p.y = 0.02
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 2.0; cm.bottom_radius = 2.0; cm.height = 0.04; cm.radial_segments = 24
			mi.mesh = cm
			var m := Creatures.emissive(Color(1.0, 0.35, 0.05), 0.6)
			mi.material_override = m
			G.level.add_child(mi)
			mi.global_position = p
			vents.append({"node": mi, "mat": m, "p": p, "t": 0.0})
	for i in range(vents.size() - 1, -1, -1):
		var v: Dictionary = vents[i]
		v.t += dt
		if v.t < 1.2:
			v.mat.emission_energy_multiplier = 0.6 + v.t * 4.0 * (0.5 + 0.5 * sin(v.t * 30.0))
		elif v.t - dt < 1.2:
			G.audio.play3d("lava", v.p, 6.0)
			G.audio.play3d("explosion", v.p, 0.0, 1.4)
			G.level.hazards.append({"box": [v.p.x - 2.0, -0.5, v.p.z - 2.0, v.p.x + 2.0, 3.0, v.p.z + 2.0], "dps": 30.0, "kind": "lava", "until": G.level.time + 2.5})
		if v.t >= 1.2 and v.t < 3.7 and randf() < 0.7:
			G.fx.emit(v.p + Vector3(randf_range(-1.5, 1.5), 0.1, randf_range(-1.5, 1.5)), Vector3(randf_range(-1, 1), randf_range(5, 10), randf_range(-1, 1)), Color(3, 1.2, 0.3), 0.2, 0.6)
		if v.t > 3.7:
			v.node.queue_free()
			vents.remove_at(i)


func update(dt: float, ws: float) -> void:
	var P = G.player
	state_t += dt
	update_flash(dt)
	update_waves(dt)
	var to: Vector3 = P.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir = to / max(dist, 0.001)
	var walk := 0.0
	attack_cd -= dt
	dome_mat.set_shader_parameter("color", Color(0.3, 0.7, 1.0) * (1.0 + flash_t * 5.0))
	for g in gens:
		if g.alive:
			g.mat.emission_energy_multiplier = 2.5 + sin(state_t * 6.0) * 1.0
	if phase == 2 and alive:
		_vents_tick(dt)
	match state:
		"intro":
			visor_mat.emission_energy_multiplier = (3.0 if randf() < state_t / 3.0 else 0.2)
			if state_t > 0.5 and state_t - dt <= 0.5:
				G.audio.play3d("sentinel_boot", center(), 10.0, 0.5)
			if state_t > 3.0:
				visor_mat.emission_energy_multiplier = 3.0
				set_state("stalk")
				attack_cd = 1.5
		"stalk":
			facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * (1.2 if phase == 1 else 2.0))
			if dist > 13.0:
				velocity.x = dir.x * 2.4
				velocity.z = dir.z * 2.4
				walk = 1.0
			else:
				velocity.x = 0; velocity.z = 0
			if attack_cd <= 0.0:
				var r := randf()
				if dist < 8.0 and r < 0.5:
					set_state("stomp_wind")
					G.audio.play3d("servo", center(), 6.0, 0.6)
				elif r < 0.55:
					set_state("missiles"); volley = 4 + phase * 2; volley_t = 0.6
				else:
					set_state("beam_charge")
					G.audio.play3d("beam_charge", laser_arm.global_position, 8.0)
		"missiles":
			facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 2.0)
			velocity.x = 0; velocity.z = 0
			volley_t -= dt
			if volley_t <= 0.0 and volley > 0:
				volley -= 1
				volley_t = 0.35 if phase == 1 else 0.25
				_fire_missile()
			if volley <= 0 and volley_t < -0.6:
				set_state("stalk"); attack_cd = randf_range(2.5, 4.0) / phase
		"beam_charge":
			facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 3.0)
			velocity.x = 0; velocity.z = 0
			laser_arm.rotation.x = lerp(laser_arm.rotation.x, -0.25, dt * 4.0)
			if state_t > 1.3:
				var a := G.yaw_to(dir.x, dir.z)
				var side := -1.0 if randf() < 0.5 else 1.0
				beam_from = a - side * 1.6
				beam_to = a + side * 1.6
				beam_hit = false
				beam.visible = true
				set_state("beam")
				G.audio.play3d("beam_fire", center(), 8.0)
		"beam":
			var k: float = min(1.0, state_t / (2.4 if phase == 1 else 1.8))
			var ang := lerp_angle(beam_from, beam_to, k)
			facing = ang
			var origin := global_position + Vector3(0, 0.75, 0)
			var bdir := G.flat_forward(ang)
			beam.global_transform = Transform3D(Basis.looking_at(bdir, Vector3.UP), origin + bdir * 20.0)
			beam_mat.albedo_color = Color(4.0, 0.4, 0.2) * (0.8 + randf() * 0.4)
			# hit if the player stands in the sweep line without jumping
			var pp: Vector3 = P.global_position - origin
			var along := pp.dot(bdir)
			var lateral := (pp - bdir * along)
			lateral.y = 0
			if not beam_hit and along > 0.0 and along < 40.0 and lateral.length() < 0.7 and P.global_position.y < 0.6:
				beam_hit = true
				P.receive_hit(26, origin + bdir * max(along - 2.0, 0.0), "beam")
			if randf() < 0.6:
				G.fx.emit(origin + bdir * randf_range(3, 30) + Vector3(0, -0.7, 0), Vector3(0, randf_range(1, 3), 0), Color(3, 0.8, 0.3), 0.12, 0.3)
			if k >= 1.0:
				beam.visible = false
				laser_arm.rotation.x = 0.0
				set_state("stalk"); attack_cd = randf_range(2.0, 3.5) / phase
		"stomp_wind":
			velocity.x = 0; velocity.z = 0
			legs[0].hip.rotation.x = lerp(legs[0].hip.rotation.x, -0.9, dt * 4.0)
			if state_t > 0.8:
				legs[0].hip.rotation.x = 0.0
				shockwave(global_position + G.flat_forward(facing) * 2.0, 11.0, 0.9, 22.0, Color(2.0, 1.0, 0.4))
				G.audio.play3d("stomp", global_position, 10.0)
				set_state("stalk"); attack_cd = randf_range(2.0, 3.0) / phase
		"stagger":
			velocity.x = 0; velocity.z = 0
			torso.rotation.z = sin(state_t * 12.0) * 0.06
			if state_t > 3.0:
				torso.rotation.z = 0.0
				set_state("stalk"); attack_cd = 1.0
		"dead":
			velocity = Vector3.ZERO
			rig.rotation.x = lerp(rig.rotation.x, 0.5, dt * 1.2)
			rig.position.y = lerp(rig.position.y, -1.4, dt * 1.0)
			if state_t > 7.0:
				remove_me = true
	velocity.y -= 20.0 * dt
	slide(ws)
	if is_on_floor():
		velocity.y = max(velocity.y, -1.0)
	if alive:
		push_from_player(3.3)
	walk_t += dt * walk * 2.0
	for l in legs:
		if state == "stomp_wind" and l == legs[0]:
			continue
		var ph: float = 0.0 if l.s > 0 else PI
		l.hip.rotation.x = sin(walk_t + ph) * 0.3 * walk
		l.knee.rotation.x = max(0.0, -sin(walk_t + ph)) * 0.4 * walk
	if walk > 0.0:
		step_t -= dt
		if step_t <= 0.0:
			step_t = 0.8
			G.audio.play3d("stomp", global_position, 2.0)
			P.add_shake(0.1)
	rotation.y = facing
