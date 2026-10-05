class_name Phantom
extends Enemy
## Archive wraith: a hooded hologram. Intangible (strikes pass through) except while casting.
## Teleports around the player and fires slow homing orbs. Phase Step dashes always connect.

var robe_mat: ShaderMaterial
var core_mat: StandardMaterial3D
var bob := 0.0
var cast_cd := 2.5
var blink_cd := 3.0
var orbs: Array = []


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "phantom"
	max_hp = 40; hp = 40
	radius = 0.6; center_y = 1.3
	organic = false; drop_count = 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = 0
	scan_info = {"title": "PHANTOM // ARCHIVE WRAITH", "text": "A self-propagating memory construct of the station AI.\nIntangible: blades pass through it, except at the instant it casts.\nStrike it as its core flares. A Phase Step dash always connects."}
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new(); sh.radius = 0.4; sh.height = 2.0
	cs.shape = sh; cs.position.y = 1.2
	add_child(cs)
	robe_mat = ShaderMaterial.new()
	robe_mat.shader = preload("res://shaders/hologram_solid.gdshader")
	core_mat = Creatures.emissive(Color(0.5, 0.9, 1.0), 3.0)
	rig = Node3D.new(); add_child(rig)
	var robe := CylinderMesh.new(); robe.top_radius = 0.15; robe.bottom_radius = 0.6; robe.height = 1.9; robe.radial_segments = 16
	Creatures.add(rig, robe, robe_mat, Vector3(0, 1.1, 0))
	var hood := SphereMesh.new(); hood.radius = 0.28; hood.height = 0.6
	Creatures.add(rig, hood, robe_mat, Vector3(0, 2.15, 0.02), Vector3(1, 1.2, 1))
	Creatures.add(rig, Creatures.sphere(0.12, 12, 8), core_mat, Vector3(0, 1.5, -0.2))
	for s in [-1, 1]:
		var sleeve := CylinderMesh.new(); sleeve.top_radius = 0.08; sleeve.bottom_radius = 0.18; sleeve.height = 0.9
		Creatures.add(rig, sleeve, robe_mat, Vector3(s * 0.45, 1.5, -0.1), Vector3.ONE, Vector3(-0.6, 0, s * 0.5))
	set_state("drift")
	cast_cd = randf_range(1.5, 3.0)


func take_damage(dmg: float, dir: Vector3, dmg_kind: String) -> void:
	var solid := state == "cast" or dmg_kind in ["dash", "wave", "reflect"]
	if dmg_kind == "dash" and G.has_ability("phase"):
		dmg *= 2.0
	if not solid:
		G.audio.play3d("glitch", center(), -6.0)
		G.fx.burst(center(), {"count": 8, "color": Color(0.4, 1.4, 2.0), "speed": 3.0, "life": 0.3, "size": 0.06})
		return
	super.take_damage(dmg, dir, dmg_kind)
	if alive and state == "cast":
		set_state("blink")


func on_die(_dir: Vector3) -> void:
	G.audio.play3d("glitch", center(), 4.0, 0.6)
	G.fx.burst(center(), {"count": 70, "color": Color(0.5, 1.8, 2.6), "speed": 6.0, "life": 0.9, "size": 0.09})
	remove_me = true


func _blink() -> void:
	var P = G.player
	G.audio.play3d("phantom", center(), 0.0)
	G.fx.burst(center(), {"count": 25, "color": Color(0.5, 1.8, 2.6), "speed": 4.0, "life": 0.4, "size": 0.07})
	for i in 6:
		var a := randf() * TAU
		var p: Vector3 = P.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(6.0, 10.0)
		p.y = P.global_position.y + 0.4
		if G.level.line_of_sight(P.eye_pos(), p + Vector3(0, 1.3, 0)) and G.level.line_of_sight(p + Vector3(0, 1.3, 0), p + Vector3(0, -2, 0)) == false:
			global_position = p
			break
	G.fx.burst(center(), {"count": 25, "color": Color(0.5, 1.8, 2.6), "speed": 4.0, "life": 0.4, "size": 0.07})


func update(dt: float, ws: float) -> void:
	var P = G.player
	state_t += dt
	bob += dt
	var to: Vector3 = P.global_position - global_position
	to.y = 0
	var dir := to.normalized()
	facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 4.0)
	rig.position.y = sin(bob * 1.6) * 0.15
	robe_mat.set_shader_parameter("solid", 1.0 if state == "cast" else 0.0)
	match state:
		"drift":
			velocity = Vector3(-dir.z, 0, dir.x) * 1.2
			cast_cd -= dt
			blink_cd -= dt
			if blink_cd <= 0.0:
				blink_cd = randf_range(3.5, 6.0)
				_blink()
			elif cast_cd <= 0.0 and G.level.line_of_sight(center(), P.eye_pos()):
				set_state("cast")
				G.audio.play3d("beam_charge", center(), -6.0, 2.0)
		"cast":
			velocity = Vector3.ZERO
			core_mat.emission_energy_multiplier = 3.0 + state_t * 10.0
			if state_t > 0.9:
				var from := center() + Vector3(0, 0.2, 0)
				mgr.spawn_bolt(from, (P.eye_pos() - from).normalized() * 7.0, self, {"homing": 2.2, "color": Color(0.6, 1.6, 3.0)})
				G.audio.play3d("phantom", from, 0.0, 1.5)
				core_mat.emission_energy_multiplier = 3.0
				cast_cd = randf_range(2.5, 4.0)
				set_state("drift")
		"blink":
			velocity = Vector3.ZERO
			if state_t > 0.35:
				_blink()
				set_state("drift")
		"dead":
			pass
	slide(ws)
	rotation.y = facing
