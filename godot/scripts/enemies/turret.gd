class_name Turret
extends Enemy
## Wall / ceiling turret: tracks, charges, fires a three-bolt burst. Deflect the bolts back to kill it.

var head: Node3D
var eye_mat: StandardMaterial3D
var fire_cd := 2.0
var burst := 0
var burst_t := 0.0
var mount_normal := Vector3.UP


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "turret"
	max_hp = 30; hp = 30
	radius = 0.5; center_y = 0.0
	organic = false; drop_count = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	mount_normal = opts.get("normal", Vector3.DOWN)
	scan_info = {"title": "SENTRY TURRET", "text": "Fixed point-defence emplacement. Three-round bursts.\nThe rounds are slow enough to strike back at it."}
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new(); sh.radius = 0.45
	cs.shape = sh
	add_child(cs)
	var dark := Creatures.mech(Color(0.25, 0.26, 0.3))
	var armor := Creatures.mech(Color(0.55, 0.5, 0.42))
	flash_mats = [dark, armor]
	rig = Node3D.new()
	add_child(rig)
	var base := CylinderMesh.new(); base.top_radius = 0.35; base.bottom_radius = 0.5; base.height = 0.3
	var b := Creatures.add(rig, base, dark)
	b.position = -mount_normal * -0.0
	rig.basis = Basis(Quaternion(Vector3.UP, -mount_normal))
	head = Node3D.new(); head.position = Vector3(0, 0.35, 0); rig.add_child(head)
	Creatures.add(head, Creatures.sphere(0.32, 20, 10), armor)
	var barrel := CylinderMesh.new(); barrel.top_radius = 0.06; barrel.bottom_radius = 0.08; barrel.height = 0.6
	Creatures.add(head, barrel, dark, Vector3(0, 0, -0.4), Vector3.ONE, Vector3(PI / 2, 0, 0))
	eye_mat = Creatures.emissive(Color(1.0, 0.2, 0.15), 2.5)
	Creatures.add(head, Creatures.sphere(0.07, 8, 6), eye_mat, Vector3(0, 0.12, -0.28))
	fire_cd = randf_range(1.0, 3.0)


func on_die(_dir: Vector3) -> void:
	G.audio.play3d("explosion", global_position, 2.0)
	G.fx.burst(global_position, {"count": 40, "color": Color(3, 1.5, 0.5), "speed": 8.0, "life": 0.6, "size": 0.12})
	G.fx.debris(head, Vector3(randf_range(-2, 2), 3, randf_range(-2, 2)), Vector3(5, 3, 4))
	remove_me = true


func update(dt: float, _ws: float) -> void:
	var P = G.player
	update_flash(dt)
	if not alive:
		return
	var eye: Vector3 = P.eye_pos()
	var hp_ := head.global_position
	var to := eye - hp_
	var dist := to.length()
	var sees = dist < 30.0 and G.level.line_of_sight(hp_ + to.normalized() * 0.6, eye)
	if sees:
		var target := Transform3D().looking_at(to, Vector3.UP if abs(to.normalized().y) < 0.95 else Vector3.FORWARD)
		head.global_basis = head.global_basis.slerp(target.basis, min(1.0, dt * 4.0))
	fire_cd -= dt
	if burst > 0:
		burst_t -= dt
		if burst_t <= 0.0:
			burst -= 1
			burst_t = 0.18
			var from := hp_ - head.global_basis.z * 0.7
			mgr.spawn_bolt(from, (eye - Vector3(0, 0.3, 0) - from).normalized() * 12.0, self)
			G.audio.play3d("turret_shot", from, 0.0)
	elif sees and fire_cd <= 0.0:
		eye_mat.emission_energy_multiplier = 6.0
		burst = 3
		burst_t = 0.5
		fire_cd = randf_range(2.8, 4.0)
		G.audio.play3d("sentinel_charge", hp_, -4.0, 1.4)
	else:
		eye_mat.emission_energy_multiplier = lerp(eye_mat.emission_energy_multiplier, 2.5, dt * 3.0)
