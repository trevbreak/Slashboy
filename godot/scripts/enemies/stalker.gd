class_name Stalker
extends Enemy
## Bloom apex: cloaked, flanks with blinks, shrieks, lunges, swipes. Visible in the scan visor.

var body_mat: ShaderMaterial
var cloak_mat: ShaderMaterial
var parts: Array = []
var hips: Node3D
var torso: Node3D
var neck: Node3D
var jaw: Array = []
var eye: MeshInstance3D
var eye_mat: StandardMaterial3D
var eye_glow: MeshInstance3D
var tip_mat: StandardMaterial3D
var arms: Array = []
var legs: Array = []
var tendrils: Array = []
var speed := 3.6
var step_t := 0.0
var cycle_t := 0.0
var swipes := 0
var swipe_hit := false
var enraged := false
var shrieked := false
var stagger_dur := 1.0
var apparition := false
var anim_t := 0.0
var reveal := 0.0
var avatar := false
var brood_t := 0.0


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "stalker"
	max_hp = 230; hp = 230
	radius = 0.6; center_y = 1.5
	organic = true; drop_count = 6
	scan_info = {"title": "STALKER // BLOOM APEX", "text": "Optical camouflage grown from living tissue. Invisible in the combat visor, visible in the scan visor.\nIt flanks, appears, shrieks, and lunges. Dash through the lunge, or parry it to break its guard.\nIt stays visible for a short time after attacking. Punish it then."}
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 2.4
	cs.shape = cap; cs.position.y = 1.2
	add_child(cs)
	rig = Creatures.build_stalker(self)
	add_child(rig)
	set_cloak(true, true)
	set_state("emerge")
	if opts.get("avatar", false):
		avatar = true
		kind = "avatar"
		max_hp = 520; hp = 520
		radius = 0.85; center_y = 2.0
		speed = 4.4
		drop_count = 12
		rig.scale = Vector3.ONE * 1.35
		cs.scale = Vector3.ONE * 1.35
		cs.position.y = 1.6
		scan_info = {"title": "AVATAR // BLOOM INCARNATE", "text": "The Heart's last act: a body grown to carry the colony out of the station.
A stalker strain, larger, faster, with no fear of the blade.
It breeds as it bleeds. Keep the swarm off you and finish it."}
	if opts.get("apparition", false):
		apparition = true
		dormant = true
		scan_info = {}
		set_state("apparition")


func set_cloak(on: bool, silent := false) -> void:
	cloaked = on
	for p in parts:
		p.material_override = cloak_mat if on else body_mat
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	eye.visible = not on
	eye_glow.visible = not on
	tip_mat.emission_energy_multiplier = 0.0 if on else 3.0
	if not silent:
		G.audio.play3d("cloak", center())
		for i in 30:
			var p := center() + Vector3(randf_range(-0.4, 0.4), randf_range(-1.2, 1.2), randf_range(-0.4, 0.4))
			G.fx.emit(p, Vector3(0, randf_range(0.5, 1.5), 0), Color(0.6, 0.9, 1.6), 0.08, 0.5)


func stagger(t := 1.6, _dir := Vector3.ZERO) -> void:
	if not alive:
		return
	if cloaked:
		set_cloak(false)
	set_state("stagger")
	stagger_dur = t
	G.audio.play3d("stalker_shriek", center(), 4.0)


func on_hurt(_dmg: float, _dir: Vector3, k: String) -> void:
	if cloaked:
		set_cloak(false)
		stagger(0.7)
	elif k in ["heavy", "wave"] and state != "lunge" and state != "stagger":
		stagger(0.45)
	if not enraged and hp < max_hp * 0.5:
		enraged = true
		speed = 5.4 if avatar else 4.6
		G.audio.play3d("stalker_shriek", center(), 6.0)
		if avatar:
			for i in 5:
				var a := i * TAU / 5.0
				mgr.spawn("mite", global_position + Vector3(cos(a), 0, sin(a)) * 2.0, {"encounter": encounter})
			G.hud.message("IT BREEDS AS IT BLEEDS", 1.5, true)
		if encounter and encounter.has_method("on_enrage"):
			encounter.on_enrage(self)


func on_die(_dir: Vector3) -> void:
	if cloaked:
		set_cloak(false, true)
	G.audio.play3d("stalker_die", center(), 6.0)
	G.fx.ichor(center(), Vector3.ZERO, 90)
	G.fx.ring(global_position + Vector3(0, 0.1, 0), Color(1.5, 0.3, 2.5), 9.0, 0.9)
	G.fx.light_flash(center(), Color(0.69, 0.38, 1.0), 12.0, 0.6)
	G.hit_stop(0.3)


func blink_to() -> bool:
	var P = G.player
	var back := Vector3(sin(P.yaw), 0, cos(P.yaw))
	var side := Vector3(cos(P.yaw), 0, -sin(P.yaw)) * (-1.0 if randf() < 0.5 else 1.0)
	G.audio.play3d("stalker_whoosh", center(), 2.0)
	for off in [back * 4.5, (back + side).normalized() * 4.5, side * 5.0]:
		var p: Vector3 = P.global_position + off
		var xf := Transform3D(Basis(), p + Vector3(0, 0.05, 0))
		if not test_move(xf, Vector3(0, 0.01, 0)) and G.level.line_of_sight(P.eye_pos(), p + Vector3(0, 1.5, 0)):
			global_position = p
			G.audio.play3d("stalker_whoosh", center(), 2.0)
			return true
	return false


func update(dt: float, ws: float) -> void:
	var P = G.player
	state_t += dt
	update_flash(dt)
	reveal += ((1.0 if P.scan_mode else 0.0) - reveal) * min(1.0, dt * 6.0)
	var to: Vector3 = P.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir = to / max(dist, 0.001)
	var walk := 0.0
	var pose := "idle"
	if state == "apparition":
		facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 8.0)
		cloak_mat.set_shader_parameter("reveal", max(reveal, 0.3 + sin(state_t * 9.0) * 0.08))
		if state_t > 2.6 or dist < 8.0:
			set_cloak(true)
			G.audio.play3d("stalker_whoosh", center(), 2.0)
			remove_me = true
		_animate(dt, 0.0, "idle")
		rotation.y = facing
		return
	cloak_mat.set_shader_parameter("reveal", reveal)
	cloak_mat.set_shader_parameter("flash", 0.6 if flash_t > 0.0 else 0.0)
	var face := func(): facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 8.0)
	match state:
		"emerge":
			face.call()
			if state_t > 0.1 and not shrieked:
				shrieked = true
				G.audio.play3d("stalker_shriek", center(), 6.0)
			if state_t > 1.5:
				set_state("stalk")
		"stalk":
			face.call()
			cycle_t += dt
			var want = dir if dist > 5.5 else Vector3(-dir.z, 0, dir.x) * 0.7
			velocity.x += (want.x * speed - velocity.x) * min(1.0, dt * 4.0)
			velocity.z += (want.z * speed - velocity.z) * min(1.0, dt * 4.0)
			walk = 1.0
			step_t -= dt
			if step_t <= 0.0:
				step_t = 0.55
				G.audio.play3d("stalker_step", global_position + Vector3(0, 0.1, 0), 2.0)
			if randf() < dt * 0.4:
				G.audio.play3d("cloak", center(), -4.0)
			var window := 1.6 if enraged else 2.6
			if cycle_t > window + randf() * 1.5:
				cycle_t = 0.0
				if dist < 9.0 and randf() < 0.55 and blink_to():
					set_state("reveal"); set_cloak(false); G.audio.play3d("stalker_shriek", center(), 6.0)
				elif dist < 7.0:
					set_state("reveal"); set_cloak(false); G.audio.play3d("stalker_shriek", center(), 6.0)
		"reveal":
			face.call()
			velocity *= 1.0 - min(1.0, dt * 8.0)
			pose = "raise"
			if state_t > (0.42 if enraged else 0.6):
				set_state("lunge")
				swipes = 0
				swipe_hit = false
		"lunge":
			face.call()
			var sp := 15.0 if enraged else 13.0
			velocity.x = dir.x * sp
			velocity.z = dir.z * sp
			pose = "raise"
			if dist < (2.6 if avatar else 1.9) or state_t > 0.45:
				set_state("swipe")
		"swipe":
			velocity *= 1.0 - min(1.0, dt * 10.0)
			pose = "swipe"
			if not swipe_hit and state_t > 0.08:
				swipe_hit = true
				G.audio.play3d("stalker_whoosh", center(), 2.0)
				if dist < (3.4 if avatar else 2.6) and G.flat_forward(facing).dot(dir) > 0.3:
					P.receive_hit((26 if enraged else 22) if avatar else (22 if enraged else 18), center(), "melee", self)
			if state == "swipe" and state_t > 0.3:
				swipes += 1
				if swipes < (3 if enraged else 2) and dist < 3.5:
					set_state("swipe")
					swipe_hit = false
				else:
					set_state("recover")
		"recover":
			velocity *= 1.0 - min(1.0, dt * 6.0)
			pose = "slump"
			if state_t > (1.0 if enraged else 1.4):
				set_cloak(true)
				set_state("stalk")
				cycle_t = 0.0
		"stagger":
			velocity *= 1.0 - min(1.0, dt * 5.0)
			pose = "stagger"
			if state_t > stagger_dur:
				set_state("recover")
		"dead":
			pose = "dead"
			velocity *= 1.0 - min(1.0, dt * 4.0)
			if state_t > 1.2 and randf() < dt * 30.0:
				G.fx.ichor(center() + Vector3(randf_range(-0.5, 0.5), randf_range(-1, 1), randf_range(-0.5, 0.5)), Vector3.ZERO, 3)
			if state_t > 2.5:
				rig.scale *= 1.0 - dt * 1.5
			if state_t > 4.0:
				remove_me = true
	velocity.y -= 20.0 * dt
	slide(ws)
	if is_on_floor():
		velocity.y = max(velocity.y, -1.0)
	if alive:
		push_from_player(1.0)
	_animate(dt, walk, pose)
	rotation.y = facing


func _animate(dt: float, walk: float, pose: String) -> void:
	anim_t += dt * (2.0 + walk * 5.0)
	var t := anim_t
	var k: float = min(1.0, dt * 12.0)
	for leg in legs:
		var ph := 0.0 if leg.s > 0 else PI
		leg.hip.rotation.x = lerp(leg.hip.rotation.x, sin(t + ph) * 0.6 - 0.2 if walk > 0.0 else -0.25, k)
		leg.knee.rotation.x = lerp(leg.knee.rotation.x, 0.9 + cos(t + ph) * 0.4 if walk > 0.0 else 0.8, k)
		leg.ank.rotation.x = lerp(leg.ank.rotation.x, -0.5, k)
	var sh_x := 0.3; var el_x := -0.6; var tor_x := -0.35; var neck_x := 0.2; var sh_z := 0.25
	match pose:
		"raise": sh_x = -2.4; el_x = -0.8; tor_x = -0.1; sh_z = 0.55; neck_x = -0.2
		"swipe": sh_x = 0.9; el_x = -0.2; tor_x = -0.7; sh_z = 0.1
		"slump": sh_x = 0.5; el_x = -0.3; tor_x = -0.8 + sin(state_t * 6.0) * 0.06; neck_x = 0.6
		"stagger": sh_x = -0.4; el_x = -1.2; tor_x = 0.2 + sin(state_t * 30.0) * 0.1; neck_x = -0.6
		"dead": tor_x = -1.4; sh_x = 1.4; neck_x = 1.0
	torso.rotation.x = lerp(torso.rotation.x, tor_x, k)
	neck.rotation.x = lerp(neck.rotation.x, neck_x, k)
	for a in arms:
		a.sh.rotation.x = lerp(a.sh.rotation.x, sh_x + (sin(t + (PI if a.s > 0 else 0.0)) * 0.3 if walk > 0.0 else 0.0), k)
		a.sh.rotation.z = lerp(a.sh.rotation.z, a.s * sh_z, k)
		a.el.rotation.x = lerp(a.el.rotation.x, el_x, k)
	if pose == "dead":
		hips.position.y += (0.5 - hips.position.y) * min(1.0, dt * 3.0)
	else:
		hips.position.y = 1.3 + (abs(sin(t)) * 0.05 if walk > 0.0 else 0.0)
	if alive and randf() < dt * 2.0:
		neck.rotation.z = randf_range(-0.3, 0.3)
	neck.rotation.z *= 1.0 - dt * 3.0
	var gape := 0.55 + sin(state_t * 40.0) * 0.08 if pose in ["raise", "stagger"] else (0.35 if pose == "swipe" else 0.06)
	for j in jaw:
		j.g.rotation.y = lerp(j.g.rotation.y, j.s * gape, k)
	var sway := Vector2(velocity.x, velocity.z).length()
	for td in tendrils:
		for i in range(1, td.chain.size()):
			td.chain[i].rotation.x = sin(t * 0.8 + td.ph - i * 0.6) * (0.18 + sway * 0.03) + sway * 0.04
			td.chain[i].rotation.z = cos(t * 0.6 + td.ph - i * 0.5) * 0.15
