class_name Sentinel
extends Enemy
## Corrupted security drone: hovers, charges and fires plasma bolts that can be deflected.

var petals: Array = []
var trim_mat: StandardMaterial3D
var iris_mat: ShaderMaterial
var eye_glow: MeshInstance3D
var ring_light_mat: StandardMaterial3D
var rings: Array = []
var blink_mat: StandardMaterial3D
var thruster_glow: MeshInstance3D
var orbit_dir := 1.0
var fire_cd := 2.0
var hum_t := 0.0
var bob := 0.0
var stagger_dur := 2.2
var thrust_t := 0.0
var exploded := false
var hum: AudioStreamPlayer3D


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "sentinel"
	max_hp = 50; hp = 50
	radius = 0.7; center_y = 0.0
	organic = false; drop_count = 3
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	scan_info = {"title": "SENTINEL SN-7 // CORRUPTED", "text": "Station security drone. Firmware overwritten by the Bloom.\nFires slow plasma bolts. Strike a bolt, or guard just as it lands, to send it back.\nA returned bolt knocks the drone out of the air. Finish it while it is grounded."}
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new(); sh.radius = 0.6
	cs.shape = sh
	add_child(cs)
	rig = Creatures.build_sentinel(self)
	add_child(rig)
	dormant = opts.get("dormant", false)
	orbit_dir = -1.0 if randf() < 0.5 else 1.0
	fire_cd = randf_range(1.5, 3.0)
	hum_t = randf() * 2.0
	bob = randf() * 10.0
	set_state("dormant" if dormant else "hover")
	if dormant:
		set_eye(Color(0.01, 0.01, 0.015), 0.1)
		eye_glow.visible = false
		thruster_glow.visible = false
	else:
		set_eye(Color(0.15, 0.95, 1.3), 1.0)


func set_eye(c: Color, power := 0.6) -> void:
	iris_mat.set_shader_parameter("color", c * 2.6)
	iris_mat.set_shader_parameter("power", power * 0.6)
	trim_mat.emission = c
	eye_glow.material_override.set_shader_parameter("color", c * 0.7)


func activate() -> void:
	if not dormant:
		return
	set_state("boot")
	G.audio.play3d("sentinel_boot", global_position, 4.0)


func stagger(t := 2.2, _dir := Vector3.ZERO) -> void:
	if not alive:
		return
	set_state("stagger")
	stagger_dur = t
	G.audio.play3d("sentinel_die", global_position)


func on_hurt(_dmg: float, dir: Vector3, k: String) -> void:
	G.fx.sparks(center(), dir, 10)
	if k in ["reflect", "wave"]:
		stagger(2.4)
	elif state != "stagger":
		velocity += dir * 4.0


func on_die(_dir: Vector3) -> void:
	G.audio.play3d("sentinel_die", global_position, 2.0)
	set_eye(Color(0.02, 0.005, 0.005), 0.1)
	eye_glow.visible = false
	thruster_glow.visible = false
	velocity.y = 1.0


func fire() -> void:
	var P = G.player
	var from := center() + Vector3(-sin(facing), 0, -cos(facing)) * 0.6
	var tgt: Vector3 = P.eye_pos() - Vector3(0, 0.3, 0) + P.velocity * 0.35
	mgr.spawn_bolt(from, (tgt - from).normalized() * 12.5, self)
	G.audio.play3d("sentinel_shot", from, 2.0)


func update(dt: float, ws: float) -> void:
	var P = G.player
	state_t += dt
	update_flash(dt)
	bob += dt
	var eye: Vector3 = P.eye_pos()
	var to := eye - global_position
	var dist := to.length()
	var flat := Vector2(to.x, to.z).length()
	var spin := 9.0 if state == "charge" else (0.0 if dormant or not alive else 1.2)
	rings[0].ring.rotation.z += dt * spin
	rings[1].ring.rotation.z -= dt * spin * 0.7
	rings[0].holder.rotation.x += dt * spin * 0.3
	rings[1].holder.rotation.y += dt * spin * 0.2
	blink_mat.emission_energy_multiplier = 4.0 if (fmod(bob * 1.3, 1.0) < 0.15 and not dormant) else 0.1
	match state:
		"dormant":
			rig.rotation.x = 0.6
			_sync(dt)
			return
		"boot":
			var k: float = min(1.0, state_t / 1.6)
			var flick := (1.0 if randf() < k else 0.05) if k < 0.6 else 1.0
			set_eye(Color(0.15, 0.95, 1.3) * flick, flick)
			eye_glow.visible = flick > 0.5
			thruster_glow.visible = true
			rig.rotation.x = 0.6 * (1.0 - k)
			var out: Vector3 = G.level.points.atrium_center - global_position
			out.y = 0
			velocity = out.normalized() * 1.6 + Vector3(0, 0.8, 0)
			facing = lerp_angle(facing, G.yaw_to(to.x, to.z), dt * 3.0)
			if state_t > 1.6:
				dormant = false
				set_state("hover")
		"hover", "charge":
			facing = lerp_angle(facing, G.yaw_to(to.x, to.z), dt * 5.0)
			var prefer := 8.5
			var radial := 1.0 if flat > prefer + 1.5 else (-1.0 if flat < prefer - 2.0 else 0.0)
			var fx = to.x / max(flat, 0.001); var fz = to.z / max(flat, 0.001)
			var sp := 0.8 if state == "charge" else 3.2
			var want := Vector3(fx * radial * sp - fz * orbit_dir * sp * 0.8, (P.global_position.y + 3.6 + sin(bob * 1.3) * 0.5 - global_position.y) * 1.5, fz * radial * sp + fx * orbit_dir * sp * 0.8)
			velocity += (want - velocity) * min(1.0, dt * 2.0)
			if randf() < dt * 0.2:
				orbit_dir *= -1.0
			if state == "hover":
				fire_cd -= dt
				set_eye(Color(0.15, 0.95, 1.3), 1.0)
				iris_mat.set_shader_parameter("pupil", 0.25)
				if fire_cd <= 0.0 and dist < 26.0 and G.level.line_of_sight(center(), eye):
					set_state("charge")
					G.audio.play3d("sentinel_charge", global_position, 2.0)
			else:
				var k: float = min(1.0, state_t / 0.9)
				set_eye(Color(0.15 + k * 2.0, 0.95 * (1.0 - k) + 0.25, 1.3 * (1.0 - k) + 0.1), 1.0 + k)
				iris_mat.set_shader_parameter("pupil", 0.25 - k * 0.17)
				if randf() < 0.6:
					var p := center() + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
					G.fx.emit(p, (center() - p) * 3.0, Color(3, 1, 0.5), 0.08, 0.25)
				if state_t > 0.9:
					fire()
					fire_cd = randf_range(2.2, 3.8)
					set_state("hover")
		"stagger":
			var k := state_t / stagger_dur
			var ground: float = 0.85
			velocity.x *= 1.0 - min(1.0, dt * 3.0)
			velocity.z *= 1.0 - min(1.0, dt * 3.0)
			if k < 0.8:
				velocity.y -= 14.0 * dt
				if global_position.y < ground:
					global_position.y = ground
					velocity.y = abs(velocity.y) * 0.25
			else:
				velocity.y += (P.global_position.y + 3.5 - global_position.y) * dt * 3.0
			rig.rotation.z += dt * 6.0 * (1.0 - k)
			set_eye(Color(1.5 if randf() < 0.5 else 0.05, 0.2, 0.2), 1.0)
			if randf() < dt * 8.0:
				G.fx.sparks(center(), Vector3.ZERO, 4)
			if state_t > stagger_dur:
				rig.rotation.z = 0.0
				set_state("hover")
				fire_cd = 1.5
		"dead":
			velocity.y -= 16.0 * dt
			rig.rotation.x += dt * 5.0
			rig.rotation.z += dt * 3.0
			if randf() < dt * 20.0:
				G.fx.sparks(center(), Vector3.ZERO, 3)
	if state != "dormant":
		slide(ws)
	# floating bodies never report is_on_floor(): explode on any impact while falling (or after a timeout)
	if state == "dead" and not exploded and (get_slide_collision_count() > 0 or state_t > 2.5):
		explode()
	_sync(dt)


## Blow apart: the real armour petals, gyro rings and core fly off as tumbling debris.
func explode() -> void:
	exploded = true
	var c := center()
	G.audio.play3d("explosion", c, 4.0)
	G.fx.burst(c, {"count": 60, "color": Color(3, 1.6, 0.6), "speed": 10.0, "life": 0.8, "size": 0.14})
	G.fx.sparks(c, Vector3.UP, 30)
	G.fx.ring(Vector3(c.x, 0.1, c.z), Color(3, 1.5, 0.5), 5.0, 0.5)
	G.fx.light_flash(c, Color(1, 0.63, 0.31), 10.0, 0.3)
	G.fx.glow_flash(c, Color(3, 1.8, 0.8), 4.0, 0.35)
	var pieces: Array = petals.duplicate()
	for r in rings:
		pieces.append(r.holder)
	for child in rig.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh and child.mesh.radius > 0.3:
			pieces.append(child)   # the core
	for piece in pieces:
		var node: Node3D = piece
		var out: Vector3 = node.global_position - c
		if out.length() < 0.05:
			out = Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1))
		var vel := out.normalized() * randf_range(4.0, 8.0) + Vector3(0, randf_range(2.5, 5.0), 0)
		G.fx.debris(node, vel, Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)))
	rig.visible = false
	remove_me = true


func _sync(dt: float) -> void:
	rotation.y = facing
	var open := 0.14 + sin(state_t * 30.0) * 0.01 if state == "charge" else (0.08 if state == "stagger" else 0.0)
	for p in petals:
		var cur: float = p.position.length()
		p.position = p.get_meta("dir") * (cur + (open - cur) * 0.2)
	if thruster_glow.visible and alive:
		thruster_glow.scale = Vector3.ONE * randf_range(0.55, 0.8)
		thrust_t -= dt
		if thrust_t <= 0.0:
			thrust_t = 0.05
			G.fx.emit(to_global(Vector3(0, -0.65, 0)), Vector3(randf_range(-0.3, 0.3), -2.5, randf_range(-0.3, 0.3)), Color(0.2, 0.7, 1.6), 0.18, 0.3)
