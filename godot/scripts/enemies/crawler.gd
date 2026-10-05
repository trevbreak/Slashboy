class_name Crawler
extends Enemy
## Bloom-thrall: drops from vents, skitters in, crouches + hisses, then leaps.

const BODY_Y := 0.55
var body_y := 0.55
var body: Node3D
var abdomen: MeshInstance3D
var head: Node3D
var eye_mat: StandardMaterial3D
var eye_glow: MeshInstance3D
var mandibles: Array = []
var feelers: Array = []
var legs: Array = []
var gait := 0.0
var strafe_dir := 1.0
var leap_hit := false
var skitter_t := 0.0
var attack_cd := 1.0
var speed := 5.5
var stagger_dur := 0.4
var scurry_to := Vector3.ZERO
var bite := 14.0
var leap_range := 7.5
var cd_scale := 1.0


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "crawler"
	max_hp = 34; hp = 34
	radius = 0.6; center_y = 0.55
	organic = true; drop_count = 1
	scan_info = {"title": "CRAWLER // BLOOM-THRALL", "text": "Maintenance drone overgrown and repurposed by the Bloom.\nHunts by vibration. Telegraphs a crouch and hiss before it leaps.\nStrike or dash aside during the leap. A guard timed at the moment of impact staggers it."}
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new(); sh.radius = 0.45
	cs.shape = sh; cs.position.y = 0.5
	add_child(cs)
	floor_snap_length = 0.3
	body = Creatures.build_crawler(self)
	add_child(body)
	rig = body
	match opts.get("variant", ""):
		"hound":
			kind = "hound"
			max_hp = 24; hp = 24
			speed = randf_range(7.2, 8.2)
			bite = 12.0
			leap_range = 9.0
			cd_scale = 0.6
			body.scale = Vector3(0.85, 0.8, 1.15)
			body_y = 0.46
			body.position.y = body_y
			flash_mats[1].set_shader_parameter("vein_color", Color(1.0, 0.18, 0.1))
			flash_mats[1].set_shader_parameter("rim_color", Color(1.0, 0.25, 0.15))
			flash_mats[0].set_shader_parameter("tint", Color(0.55, 0.4, 0.38))
			scan_info = {"title": "HOUND // PACK-THRALL", "text": "A crawler strain bred for the open streets. Lean, fast, hunts in packs.\nIt leaps from farther away and recovers sooner.\nKeep moving. Let the pack bunch up, then sweep it with an Arc Wave."}
		"mite":
			kind = "mite"
			max_hp = 8; hp = 8
			speed = randf_range(8.0, 9.0)
			bite = 6.0
			leap_range = 5.0
			cd_scale = 0.5
			drop_count = 0
			radius = 0.3
			center_y = 0.25
			body.scale = Vector3.ONE * 0.45
			body_y = 0.26
			body.position.y = body_y
			scan_info = {"title": "MITE // BLOOM SWARM", "text": "Larval crawlers, budded from spore pods.\nIndividually weak. Never alone."}
	gait = randf() * 10.0
	strafe_dir = -1.0 if randf() < 0.5 else 1.0
	attack_cd = randf_range(0.8, 1.8)
	speed = randf_range(5.2, 6.0)
	if opts.get("drop", false):
		set_state("drop")
		velocity = Vector3(0, -2, 0)
	elif opts.has("scurry"):
		set_state("scurry")
		dormant = true
		scurry_to = opts.scurry
		scan_info = {}
	else:
		set_state("stalk")


func stagger(t := 0.6, dir := Vector3.ZERO) -> void:
	if not alive:
		return
	set_state("stagger")
	stagger_dur = t
	if dir != Vector3.ZERO:
		velocity = Vector3(dir.x * 6.0, 2.0, dir.z * 6.0)


func on_hurt(_dmg: float, dir: Vector3, k: String) -> void:
	if state == "drop":
		return
	if hp > 0.0:
		stagger(0.7 if k in ["heavy", "wave"] else 0.35, dir)
		if randf() < 0.5:
			G.audio.play3d("crawler_screech", center())


func on_die(dir: Vector3) -> void:
	G.audio.play3d("crawler_die", center(), 2.0)
	G.fx.ichor(center(), dir, 50)
	velocity = Vector3(dir.x * 7.0, 4.0, dir.z * 7.0)
	eye_mat.emission_energy_multiplier = 0.05
	eye_glow.visible = false


func update(dt: float, ws: float) -> void:
	var P = G.player
	state_t += dt
	update_flash(dt)
	var to_p: Vector3 = P.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	var dir := to_p / dist if dist > 0.001 else Vector3.BACK
	attack_cd -= dt
	match state:
		"scurry":
			var d := scurry_to - global_position
			d.y = 0
			if d.length() < 0.6:
				remove_me = true
			d = d.normalized()
			facing = G.yaw_to(d.x, d.z)
			velocity.x = d.x * 10.0
			velocity.z = d.z * 10.0
		"drop":
			body.rotation.x = min(body.rotation.x + dt * 4.0, 0.0)
		"land":
			facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 8.0)
			if state_t > 0.5:
				set_state("stalk")
		"stalk":
			facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 7.0)
			var side := Vector3(-dir.z, 0, dir.x) * sin(state_t * 2.2) * 0.8 * strafe_dir
			var want := (dir + side).normalized() if dist > 4.5 else (side.normalized() * 0.6 - dir * 0.2)
			velocity.x += (want.x * speed - velocity.x) * min(1.0, dt * 8.0)
			velocity.z += (want.z * speed - velocity.z) * min(1.0, dt * 8.0)
			skitter_t -= dt
			if skitter_t <= 0.0:
				skitter_t = randf_range(0.6, 1.1)
				G.audio.play3d("skitter", center(), -6.0)
			if dist < leap_range and attack_cd <= 0.0 and G.level.line_of_sight(center(), P.eye_pos()):
				set_state("windup")
				G.audio.play3d("crawler_hiss", center(), 2.0)
			if randf() < dt * 0.15:
				strafe_dir *= -1.0
		"windup":
			facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * 12.0)
			velocity.x *= 1.0 - min(1.0, dt * 10.0)
			velocity.z *= 1.0 - min(1.0, dt * 10.0)
			body.position.y = body_y - min(1.0, state_t / 0.5) * 0.22 * body.scale.y
			eye_mat.emission_energy_multiplier = 3.5 + sin(state_t * 60.0) * 1.5
			if state_t > 0.55:
				var tgt: Vector3 = P.global_position + Vector3(P.velocity.x, 0, P.velocity.z) * 0.25
				var d := tgt - global_position
				d.y = 0
				var l: float = min(d.length(), 9.0)
				d = d.normalized()
				velocity = Vector3(d.x * (6.0 + l), 5.2, d.z * (6.0 + l))
				leap_hit = false
				set_state("leap")
				G.audio.play3d("crawler_screech", center(), 2.0)
		"leap":
			body.rotation.x = -0.4
			var c := center()
			if not leap_hit and c.distance_to(P.global_position + Vector3(0, 1.0, 0)) < 1.15:
				leap_hit = true
				var r: String = P.receive_hit(bite, c, "melee", self)
				if r == "hit" or r == "block":
					velocity *= -0.3
		"recover":
			velocity.x *= 1.0 - min(1.0, dt * 8.0)
			velocity.z *= 1.0 - min(1.0, dt * 8.0)
			body.position.y += (body_y - body.position.y) * min(1.0, dt * 6.0)
			if state_t > 0.7:
				set_state("stalk")
				attack_cd = randf_range(1.2, 2.7) * cd_scale
		"stagger":
			velocity.x *= 1.0 - min(1.0, dt * 6.0)
			velocity.z *= 1.0 - min(1.0, dt * 6.0)
			body.rotation.z = sin(state_t * 40.0) * 0.15 * (1.0 - state_t / stagger_dur)
			if state_t > stagger_dur:
				body.rotation.z = 0.0
				set_state("stalk")
				attack_cd = randf_range(0.5, 1.5)
		"dead":
			velocity.x *= 1.0 - min(1.0, dt * 3.0)
			velocity.z *= 1.0 - min(1.0, dt * 3.0)
			body.rotation.z += (PI - body.rotation.z) * min(1.0, dt * 6.0)
			if state_t > 2.5:
				body.position.y -= dt * 0.3
			if state_t > 4.5:
				remove_me = true
	# gravity + collide (world time)
	velocity.y -= (22.0 if state == "drop" else (16.0 if state == "leap" else 20.0)) * dt
	slide(ws)
	if is_on_floor():
		if state == "drop":
			G.audio.play3d("land", global_position, 2.0)
			G.audio.play3d("crawler_screech", center(), 2.0)
			G.fx.burst(global_position + Vector3(0, 0.1, 0), {"count": 14, "color": Color(0.4, 0.4, 0.45), "speed": 3.0, "life": 0.6, "size": 0.25})
			set_state("land")
		elif state == "leap" and velocity.y <= 0.0:
			set_state("recover")
			body.rotation.x = 0.0
			G.audio.play3d("land", global_position)
		velocity.y = max(velocity.y, -1.0)
	# separation from other crawlers and the player
	for o in mgr.list:
		if o == self or not o.alive or not o is Crawler:
			continue
		var dv: Vector3 = global_position - o.global_position
		dv.y = 0
		var dd := dv.length()
		if dd < 1.1 and dd > 0.001:
			global_position += dv / dd * (1.1 - dd) * 0.5
	if alive and state != "leap":
		push_from_player(0.9)
	# animation
	var hs := Vector2(velocity.x, velocity.z).length()
	gait += dt * (4.0 + hs * 3.2)
	if alive:
		var fast := state in ["windup", "leap"]
		for i in mandibles.size():
			mandibles[i].rotation.y = (-1.0 if i else 1.0) * (0.15 + (0.5 + 0.5 * sin(state_t * (40.0 if fast else 7.0))) * (0.6 if fast else 0.25))
		if state != "windup":
			eye_mat.emission_energy_multiplier = 2.2
		var br := 1.0 + sin(gait * 0.35 + state_t) * 0.04
		abdomen.scale = Vector3(1.05 * br, 0.8 * br, 1.35 * (2.0 - br))
		for f in feelers:
			for i in range(1, f.chain.size()):
				f.chain[i].rotation.x = -0.25 + sin(state_t * 3.0 + i + f.s) * 0.18 + (randf_range(-0.5, 0.5) if randf() < 0.01 else 0.0)
				f.chain[i].rotation.z = sin(state_t * 2.3 + i * 0.7) * 0.12 * f.s
		head.rotation.y = sin(state_t * 1.7) * 0.12
		head.rotation.x = -0.3 if state == "windup" else sin(state_t * 2.1) * 0.06
		if state != "stagger":
			body.rotation.z = sin(gait * 0.5) * 0.04 * min(1.0, hs / 3.0)
	rotation.y = facing
	# IK legs
	var planted := alive and not state in ["drop", "leap"]
	var tuck := 0.45 if not alive else (0.2 if state in ["leap", "drop"] else 0.0)
	var stepping := [false, false]
	for l in legs:
		if l.stepping:
			stepping[l.group] = true
	for l in legs:
		l.update(dt, global_position.y, velocity, planted, stepping[1 - l.group], tuck)
