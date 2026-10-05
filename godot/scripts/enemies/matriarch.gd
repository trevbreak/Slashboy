class_name Matriarch
extends Boss
## Undercity boss: crawler queen. Armoured except her glowing egg sac. Charges (stuns herself
## on walls, exposing the sac), leap-slams (shockwave), spits acid, spawns her brood.

var body: Node3D
var abdomen: MeshInstance3D
var head: Node3D
var eye_mat: StandardMaterial3D
var eye_glow: MeshInstance3D
var mandibles: Array = []
var feelers: Array = []
var legs: Array = []
var body_y := 1.5
var gait := 0.0
var attack_cd := 3.0
var charge_dir := Vector3.ZERO
var charge_hit := false
var leap_from := Vector3.ZERO
var leap_to := Vector3.ZERO
var spit_n := 0
var orbit := 1.0
var brood_spawned := {}
var arena_center := Vector3.ZERO
const SCALE := 2.7


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "matriarch"
	boss_name = "MATRIARCH // BROOD QUEEN"
	max_hp = 620; hp = 620
	radius = 1.6; center_y = 1.5
	organic = true; drop_count = 8
	dmg_mult = 0.4
	arena_center = opts.get("center", pos)
	scan_info = {"title": "MATRIARCH // BROOD QUEEN", "text": "The progenitor of every crawler in the Undercity. Her carapace turns most blades.\nThe egg sac on her back is soft, but only exposed when she is dazed.\nBait her charge into a wall. Jump her shockwaves. Never stand in the acid."}
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new(); sh.radius = 1.3; sh.height = 3.2
	cs.shape = sh; cs.position = Vector3(0, 1.4, 0); cs.rotation.x = PI / 2
	add_child(cs)
	floor_snap_length = 0.5
	body = Creatures.build_crawler(self)
	body.scale = Vector3.ONE * SCALE
	body.position.y = body_y
	add_child(body)
	rig = body
	flash_mats[1].set_shader_parameter("vein_color", Color(1.0, 0.5, 0.1))
	flash_mats[1].set_shader_parameter("vein_strength", 4.0)
	flash_mats[0].set_shader_parameter("tint", Color(0.4, 0.32, 0.3))
	var dark: Material = flash_mats[2]
	for i in 7:
		var a := -0.9 + i * 0.3
		Creatures.add(head, Creatures.cone(0.035, 0.32 + abs(i - 3) * -0.04 + 0.12, 5), dark, Vector3(sin(a) * 0.18, 0.15, -0.05 + cos(a) * 0.05), Vector3.ONE, Vector3(-0.5, 0, -a))
	for i in 4:
		var sac := Creatures.add(body, Creatures.organic(Creatures.sphere(0.12, 16, 10), 0.03, 6, i), flash_mats[1], Vector3((i - 1.5) * 0.18, 0.42, 0.75 + (i % 2) * 0.1))
	set_state("intro")


func on_hurt(_dmg: float, dir: Vector3, k: String) -> void:
	if state == "stunned":
		G.fx.ichor(center() + Vector3(0, 0.8, 0.0), dir, 20)
	var frac := hp / max_hp
	for t in [0.66, 0.33]:
		if frac < t and not brood_spawned.has(t):
			brood_spawned[t] = true
			phase += 1
			set_state("brood")
			roar()


func on_die(_dir: Vector3) -> void:
	roar("matriarch_roar", 10.0)
	G.fx.ichor(center(), Vector3.UP, 120)
	G.fx.ring(global_position + Vector3(0, 0.2, 0), Color(1.5, 0.6, 0.2), 12.0, 1.2)
	G.fx.light_flash(center(), Color(1.0, 0.5, 0.2), 14.0, 0.6)
	G.hit_stop(0.35)
	eye_mat.emission_energy_multiplier = 0.0
	eye_glow.visible = false


func _choose_attack(dist: float) -> void:
	var r := randf()
	if dist > 6.0 and r < 0.45:
		set_state("charge_wind"); roar("crawler_screech", 8.0)
	elif r < 0.75:
		set_state("leap_wind")
	else:
		set_state("spit"); spit_n = 0


func update(dt: float, ws: float) -> void:
	var P = G.player
	state_t += dt
	update_flash(dt)
	update_waves(dt)
	var to: Vector3 = P.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir = to / max(dist, 0.001)
	attack_cd -= dt
	dmg_mult = 1.6 if state == "stunned" else 0.4
	var face := func(rate: float): facing = lerp_angle(facing, G.yaw_to(dir.x, dir.z), dt * rate)
	match state:
		"intro":
			face.call(3.0)
			body.rotation.x = -0.5 * sin(min(1.0, state_t / 2.5) * PI)
			if state_t > 0.3 and state_t - dt <= 0.3:
				roar("matriarch_roar", 10.0)
			if state_t > 2.6:
				set_state("prowl")
				attack_cd = 1.5
		"prowl":
			face.call(5.0)
			var side := Vector3(-dir.z, 0, dir.x) * orbit
			var want = (dir * (1.0 if dist > 12.0 else (-0.6 if dist < 7.0 else 0.0)) + side).normalized()
			var sp := 6.5 + phase * 0.8
			velocity.x += (want.x * sp - velocity.x) * min(1.0, dt * 4.0)
			velocity.z += (want.z * sp - velocity.z) * min(1.0, dt * 4.0)
			if randf() < dt * 0.25:
				orbit = -orbit
			if attack_cd <= 0.0:
				_choose_attack(dist)
		"charge_wind":
			face.call(10.0)
			velocity.x *= 0.85; velocity.z *= 0.85
			body.rotation.x = lerp(body.rotation.x, -0.35, dt * 6.0)
			eye_mat.emission_energy_multiplier = 3.0 + sin(state_t * 50.0) * 2.0
			if state_t > 0.9:
				charge_dir = dir
				charge_hit = false
				set_state("charge")
				body.rotation.x = 0.1
		"charge":
			facing = G.yaw_to(charge_dir.x, charge_dir.z)
			velocity.x = charge_dir.x * 19.0
			velocity.z = charge_dir.z * 19.0
			if randf() < 0.5:
				G.fx.burst(global_position, {"count": 3, "color": Color(0.5, 0.45, 0.4), "speed": 3.0, "life": 0.5, "size": 0.25})
			if not charge_hit and center().distance_to(P.global_position + Vector3(0, 1, 0)) < 2.6:
				charge_hit = true
				if P.receive_hit(28, center(), "melee", self) == "hit":
					P.velocity += charge_dir * 14.0 + Vector3(0, 5, 0)
			if is_on_wall() and state_t > 0.15:
				set_state("stunned")
				roar("crawler_die", 8.0)
				G.audio.play3d("stomp", center(), 8.0)
				G.player.add_shake(0.8)
				G.fx.sparks(center() + charge_dir * 2.0, -charge_dir, 40)
				G.hud.message("SHE'S DAZED  ·  STRIKE THE SAC", 2.0)
				velocity = -charge_dir * 3.0
			elif state_t > 2.2:
				set_state("prowl"); attack_cd = 1.5
		"stunned":
			velocity.x *= 0.9; velocity.z *= 0.9
			body.rotation.z = sin(state_t * 8.0) * 0.12
			flash_mats[1].set_shader_parameter("vein_strength", 9.0 + sin(state_t * 12.0) * 3.0)
			if state_t > 3.6:
				body.rotation.z = 0.0
				flash_mats[1].set_shader_parameter("vein_strength", 4.0)
				set_state("prowl"); attack_cd = 2.0
		"leap_wind":
			face.call(10.0)
			velocity.x *= 0.85; velocity.z *= 0.85
			body.position.y = lerp(body.position.y, body_y - 0.6, dt * 8.0)
			if state_t > 0.6:
				leap_from = global_position
				leap_to = P.global_position + P.velocity * 0.3
				leap_to.y = global_position.y
				set_state("leap")
				roar("crawler_screech", 6.0)
		"leap":
			var k: float = min(1.0, state_t / 1.0)
			var p := leap_from.lerp(leap_to, k)
			p.y = leap_from.y + sin(k * PI) * 7.0
			velocity = (p - global_position) / max(dt, 0.001)
			body.position.y = lerp(body.position.y, body_y, dt * 8.0)
			body.rotation.x = -0.4 + k * 0.6
			if k >= 1.0:
				velocity = Vector3.ZERO
				shockwave(global_position, 13.0, 1.0, 20.0)
				G.audio.play3d("stomp", global_position, 10.0)
				body.rotation.x = 0.0
				set_state("recover")
		"spit":
			face.call(8.0)
			velocity.x *= 0.85; velocity.z *= 0.85
			if state_t > 0.45 * (spit_n + 1) and spit_n < 3 + phase:
				spit_n += 1
				var from := head.global_position
				var target: Vector3 = P.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
				var flat_d := Vector2(target.x - from.x, target.z - from.z).length()
				var T := 1.1
				var v := Vector3((target.x - from.x) / T, (target.y - from.y + 0.5 * 14.0 * T * T) / T, (target.z - from.z) / T)
				mgr.spawn_bolt(from, v, self, {"gravity": 14.0, "color": Color(0.7, 2.2, 0.3), "size": 1.0, "dmg": 14.0, "on_land": func(p): _acid_pool(p)})
				G.audio.play3d("acid", from, 4.0)
			if state_t > 0.45 * (4 + phase):
				set_state("prowl"); attack_cd = 2.0
		"brood":
			velocity.x *= 0.9; velocity.z *= 0.9
			body.rotation.x = -0.4 * sin(min(1.0, state_t / 1.6) * PI)
			if state_t > 0.5 and state_t - dt <= 0.5:
				for i in 2 + phase:
					var a := TAU * i / (2.0 + phase)
					var sp_pos := arena_center + Vector3(cos(a) * 12.0, 0.5, sin(a) * 12.0)
					mgr.spawn("hound" if i % 2 == 0 else "mite", sp_pos, {"encounter": encounter})
					G.fx.ichor(sp_pos, Vector3.UP, 20)
			if state_t > 1.8:
				set_state("prowl"); attack_cd = 1.0
		"recover":
			velocity.x *= 0.85; velocity.z *= 0.85
			if state_t > 1.0:
				set_state("prowl"); attack_cd = randf_range(1.5, 2.8) - phase * 0.3
		"dead":
			velocity.x *= 0.9; velocity.z *= 0.9
			body.rotation.z += (PI * 0.9 - body.rotation.z) * min(1.0, dt * 2.0)
			if state_t > 4.0:
				body.position.y -= dt * 0.4
			if state_t > 7.0:
				remove_me = true
	if state != "leap":
		velocity.y -= 22.0 * dt
	slide(ws)
	if is_on_floor() and state != "leap":
		velocity.y = max(velocity.y, -1.0)
	if alive and state not in ["leap", "charge"]:
		push_from_player(2.4)
	rotation.y = facing
	# animation (crawler rig, scaled)
	var hs := Vector2(velocity.x, velocity.z).length()
	gait += dt * (3.0 + hs * 1.2)
	if alive:
		for i in mandibles.size():
			mandibles[i].rotation.y = (-1.0 if i else 1.0) * (0.15 + (0.5 + 0.5 * sin(state_t * 9.0)) * 0.3)
		var br := 1.0 + sin(gait * 0.3) * 0.05
		abdomen.scale = Vector3(1.05 * br, 0.8 * br, 1.35 * (2.0 - br))
		head.rotation.y = sin(state_t * 1.3) * 0.15
	var planted := state not in ["leap"]
	var stepping := [false, false]
	for l in legs:
		if l.stepping:
			stepping[l.group] = true
	for l in legs:
		l.update(dt, global_position.y, velocity, planted and alive, stepping[1 - l.group], 0.0 if alive else 0.45)


func _acid_pool(p: Vector3) -> void:
	var c := Vector3(p.x, 0.02, p.z)
	G.audio.play3d("acid", c, 2.0, 0.8)
	G.level.hazards.append({"box": [c.x - 1.6, -0.5, c.z - 1.6, c.x + 1.6, 1.0, c.z + 1.6], "dps": 12.0, "kind": "acid", "until": G.level.time + 4.0})
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 1.6; cm.bottom_radius = 1.6; cm.height = 0.02; cm.radial_segments = 24
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.2, 0.02); m.emission_enabled = true; m.emission = Color(0.4, 1.0, 0.15); m.emission_energy_multiplier = 1.6; m.roughness = 0.05
	mi.material_override = m
	G.level.add_child(mi)
	mi.global_position = c
	G.fx.burst(c, {"count": 30, "color": Color(0.6, 2.0, 0.3), "speed": 4.0, "life": 0.6, "size": 0.12})
	var tw := mi.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(mi, "scale", Vector3(0.01, 1, 0.01), 0.5)
	tw.tween_callback(mi.queue_free)
