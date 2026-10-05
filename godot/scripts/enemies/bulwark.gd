class_name Bulwark
extends Enemy
## Shielded heavy mech: a frontal energy shield blocks strikes. Flank it, break the shield with a
## heavy strike / arc wave, or tear it away with the grapple. Shield-bashes and fires spread bolts.

var shield: MeshInstance3D
var shield_mat: ShaderMaterial
var shield_up := true
var shield_t := 0.0
var legs: Array = []
var torso: Node3D
var visor_mat: StandardMaterial3D
var gun: Node3D
var walk_t := 0.0
var fire_cd := 2.5
var bash_cd := 3.0
var bash_hit := false
var stagger_dur := 1.0
var servo_t := 0.0


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "bulwark"
	max_hp = 90; hp = 90
	radius = 0.9; center_y = 1.4
	organic = false; drop_count = 4
	scan_info = {"title": "BULWARK // RIOT FRAME", "text": "Foundry security chassis, piloted by a Bloom-grown nervous system.\nIts hard-light shield stops any strike from the front.\nFlank it with a dash, shatter the shield with a combo finisher or Arc Wave,\nor tear the shield emitter away with the Kusari Grapple."}
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.7; cap.height = 2.6
	cs.shape = cap; cs.position.y = 1.3
	add_child(cs)
	_build()
	set_state("advance")


func _build() -> void:
	var armor := Creatures.mech(Color(0.62, 0.52, 0.38))
	var dark := Creatures.mech(Color(0.18, 0.18, 0.2))
	flash_mats = [armor, dark]
	rig = Node3D.new()
	add_child(rig)
	var hips := Node3D.new(); hips.position.y = 1.15; rig.add_child(hips)
	torso = Node3D.new(); torso.position.y = 0.2; hips.add_child(torso)
	var chest := BoxMesh.new(); chest.size = Vector3(1.3, 0.9, 0.85)
	Creatures.add(torso, chest, armor, Vector3(0, 0.45, 0))
	var belly := BoxMesh.new(); belly.size = Vector3(0.9, 0.5, 0.7)
	Creatures.add(torso, belly, dark, Vector3(0, -0.05, 0))
	var head := BoxMesh.new(); head.size = Vector3(0.5, 0.35, 0.5)
	Creatures.add(torso, head, armor, Vector3(0, 1.05, -0.05))
	visor_mat = Creatures.emissive(Color(1.0, 0.45, 0.1), 3.0)
	var visor := BoxMesh.new(); visor.size = Vector3(0.42, 0.07, 0.05)
	Creatures.add(torso, visor, visor_mat, Vector3(0, 1.06, -0.31))
	for s in [-1, 1]:
		var pad := BoxMesh.new(); pad.size = Vector3(0.5, 0.35, 0.7)
		Creatures.add(torso, pad, armor, Vector3(s * 0.85, 0.8, 0), Vector3.ONE, Vector3(0, 0, -s * 0.25))
		var arm := CylinderMesh.new(); arm.top_radius = 0.13; arm.bottom_radius = 0.11; arm.height = 0.9
		Creatures.add(torso, arm, dark, Vector3(s * 0.85, 0.2, -0.15), Vector3.ONE, Vector3(0.4, 0, 0))
	# left arm: shield emitter; right arm: gun
	gun = Node3D.new(); gun.position = Vector3(0.85, -0.2, -0.5); torso.add_child(gun)
	var barrel := CylinderMesh.new(); barrel.top_radius = 0.08; barrel.bottom_radius = 0.1; barrel.height = 0.8
	Creatures.add(gun, barrel, dark, Vector3(0, 0, -0.3), Vector3.ONE, Vector3(PI / 2, 0, 0))
	shield_mat = ShaderMaterial.new()
	shield_mat.shader = preload("res://shaders/phase_barrier.gdshader")
	shield_mat.set_shader_parameter("color", Color(1.0, 0.55, 0.15))
	var sm := SphereMesh.new(); sm.radius = 1.3; sm.height = 2.6; sm.is_hemisphere = true; sm.radial_segments = 24; sm.rings = 8
	shield = Creatures.add(torso, sm, shield_mat, Vector3(-0.2, 0.3, -0.75), Vector3(1.0, 1.15, 0.45), Vector3(-PI / 2, 0, 0))
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s in [-1, 1]:
		var hip := Node3D.new(); hip.position = Vector3(s * 0.38, 0, 0); hips.add_child(hip)
		var thigh := BoxMesh.new(); thigh.size = Vector3(0.32, 0.65, 0.4)
		Creatures.add(hip, thigh, armor, Vector3(0, -0.3, 0))
		var knee := Node3D.new(); knee.position.y = -0.6; hip.add_child(knee)
		var shin := BoxMesh.new(); shin.size = Vector3(0.28, 0.6, 0.34)
		Creatures.add(knee, shin, dark, Vector3(0, -0.28, 0.05))
		var foot := BoxMesh.new(); foot.size = Vector3(0.36, 0.12, 0.6)
		Creatures.add(knee, foot, armor, Vector3(0, -0.55, -0.08))
		legs.append({"hip": hip, "knee": knee, "s": s})


func shield_blocks(dir_from_player: Vector3) -> bool:
	if not shield_up:
		return false
	var fwd := G.flat_forward(facing)
	var d := -dir_from_player
	d.y = 0
	return fwd.dot(d.normalized()) > 0.35


func take_damage(dmg: float, dir: Vector3, dmg_kind: String) -> void:
	if not alive:
		return
	if shield_blocks(dir) and dmg_kind not in ["grapple", "reflect"]:
		if dmg_kind in ["heavy", "wave"]:
			break_shield(4.5)
			G.audio.play3d("shield_hit", center(), 4.0, 0.7)
			return
		G.audio.play3d("shield_hit", center(), 2.0)
		G.fx.sparks(center() - dir * 0.8, -dir, 12)
		flash_t = 0.05
		G.hud.message("SHIELDED", 0.5)
		return
	super.take_damage(dmg, dir, dmg_kind)


func break_shield(t: float) -> void:
	shield_up = false
	shield_t = t
	shield.visible = false
	G.fx.burst(shield.global_position, {"count": 40, "color": Color(3, 1.6, 0.4), "speed": 7.0, "life": 0.6, "size": 0.1})
	stagger(0.9)


func grappled(from: Vector3) -> void:
	if not alive:
		return
	if shield_up:
		break_shield(6.0)
		G.hud.message("SHIELD TORN AWAY", 1.2)
	else:
		stagger(1.0)


func stagger(t := 1.0, _dir := Vector3.ZERO) -> void:
	if not alive:
		return
	set_state("stagger")
	stagger_dur = t


func on_die(_dir: Vector3) -> void:
	G.audio.play3d("explosion", center(), 4.0)
	G.audio.play3d("sentinel_die", center(), 2.0)
	G.fx.burst(center(), {"count": 60, "color": Color(3, 1.5, 0.5), "speed": 9.0, "life": 0.8, "size": 0.14})
	G.fx.light_flash(center(), Color(1, 0.6, 0.3), 10.0, 0.3)
	visor_mat.emission_energy_multiplier = 0.0
	shield.visible = false
	# armour sheds as debris
	var pieces: Array = []
	for c in torso.get_children():
		if c is MeshInstance3D and c != shield:
			pieces.append(c)
	for pc in pieces.slice(0, 6):
		G.fx.debris(pc, (pc.global_position - center()).normalized() * randf_range(3, 6) + Vector3(0, 4, 0), Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)))


func update(dt: float, ws: float) -> void:
	var P = G.player
	state_t += dt
	update_flash(dt)
	if not shield_up and alive:
		shield_t -= dt
		if shield_t <= 0.0:
			shield_up = true
			shield.visible = true
			G.audio.play3d("phase", center(), -2.0, 0.7)
	shield_mat.set_shader_parameter("color", Color(1.0, 0.55, 0.15) * (1.0 + flash_t * 6.0))
	var to: Vector3 = P.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir = to / max(dist, 0.001)
	var walk := 0.0
	fire_cd -= dt
	bash_cd -= dt
	match state:
		"advance":
			facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 2.5)
			var sp := 1.8 if dist > 4.0 else 0.0
			velocity.x = dir.x * sp
			velocity.z = dir.z * sp
			walk = sp
			if dist < 4.5 and bash_cd <= 0.0:
				set_state("bash_wind")
				G.audio.play3d("servo", center(), 2.0, 0.7)
			elif fire_cd <= 0.0 and dist < 22.0 and G.level.line_of_sight(center(), P.eye_pos()):
				set_state("aim")
				G.audio.play3d("sentinel_charge", center(), 0.0, 0.8)
		"aim":
			facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 4.0)
			velocity.x = 0; velocity.z = 0
			visor_mat.emission_energy_multiplier = 3.0 + sin(state_t * 40.0) * 2.0
			if state_t > 0.8:
				var from := gun.global_position + G.flat_forward(facing) * 0.6
				var tgt: Vector3 = P.eye_pos() - Vector3(0, 0.3, 0)
				var base := (tgt - from).normalized()
				for k in [-1, 0, 1]:
					var v := base.rotated(Vector3.UP, k * 0.12) * 13.0
					mgr.spawn_bolt(from, v, self)
				G.audio.play3d("turret_shot", from, 2.0, 0.7)
				fire_cd = randf_range(3.0, 4.5)
				visor_mat.emission_energy_multiplier = 3.0
				set_state("advance")
		"bash_wind":
			facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 6.0)
			velocity.x = 0; velocity.z = 0
			torso.rotation.x = lerp(torso.rotation.x, 0.25, dt * 8.0)
			if state_t > 0.55:
				set_state("bash")
				bash_hit = false
				velocity = dir * 11.0
				G.audio.play3d("stomp", center(), 0.0, 1.3)
		"bash":
			velocity.x *= 1.0 - min(1.0, dt * 3.0)
			velocity.z *= 1.0 - min(1.0, dt * 3.0)
			torso.rotation.x = lerp(torso.rotation.x, -0.2, dt * 10.0)
			if not bash_hit and dist < 2.2:
				bash_hit = true
				var r: String = P.receive_hit(22, center(), "melee", self)
				if r == "hit":
					P.velocity += dir * 9.0 + Vector3(0, 3, 0)
			if state_t > 0.6:
				bash_cd = randf_range(3.0, 5.0)
				torso.rotation.x = 0.0
				set_state("advance")
		"stagger":
			velocity.x *= 1.0 - min(1.0, dt * 5.0)
			velocity.z *= 1.0 - min(1.0, dt * 5.0)
			torso.rotation.z = sin(state_t * 25.0) * 0.08
			if state_t > stagger_dur:
				torso.rotation.z = 0.0
				set_state("advance")
		"dead":
			velocity *= 0.9
			rig.rotation.x = lerp(rig.rotation.x, -1.4, dt * 3.0)
			rig.position.y = lerp(rig.position.y, 0.3, dt * 3.0)
			if state_t > 3.0:
				remove_me = true
	velocity.y -= 20.0 * dt
	slide(ws)
	if is_on_floor():
		velocity.y = max(velocity.y, -1.0)
	if alive:
		push_from_player(1.2)
	walk_t += dt * walk * 2.5
	for l in legs:
		var ph: float = 0.0 if l.s > 0 else PI
		l.hip.rotation.x = sin(walk_t + ph) * 0.35 * min(1.0, walk)
		l.knee.rotation.x = max(0.0, -sin(walk_t + ph)) * 0.5 * min(1.0, walk)
	if walk > 0.0:
		servo_t -= dt
		if servo_t <= 0.0:
			servo_t = 0.6
			G.audio.play3d("stomp", global_position, -10.0, 1.6)
	rotation.y = facing
