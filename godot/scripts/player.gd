class_name Player
extends CharacterBody3D
## Slashboy: movement, katana combat, abilities and the scan visor.

const SLASHES := [
	{"a": "s0a", "b": "s0b", "dur": 0.34, "dmg": 12, "streak": -0.35, "heavy": false},
	{"a": "s1a", "b": "s1b", "dur": 0.34, "dmg": 12, "streak": 0.35, "heavy": false},
	{"a": "s2a", "b": "s2b", "dur": 0.46, "dmg": 22, "streak": 1.45, "heavy": true},
]
const EYE := 1.62
const RADIUS := 0.35
const HEIGHT := 1.75

var head: Node3D
var camera: Camera3D
var katana: Katana
var blade_light: OmniLight3D
var visor_light: OmniLight3D

var yaw := 0.0
var pitch := 0.0
var roll := 0.0
var max_hp := 100.0
var hp := 100.0
var ki := 100.0
var max_ki := 100.0
var grapple = null          # active zip: {pos, t}
var grapple_candidate = null
var chain: MeshInstance3D
var chain_t := 0.0
var chain_to := Vector3.ZERO
var double_jumped := false
var hazard_snd_t := 0.0
var hang_t := 0.0
var dead := false
var on_ground := true
var step_dist := 0.0
var bob_t := 0.0
var bob := 0.0
var land_dip := 0.0
var fov := 75.0
var shake := 0.0
var stat_v := 0.0
var dash_v := 0.0
var heart_t := 0.0
var look_delta := Vector2.ZERO
var was_on_floor := true
var fall_speed := 0.0

var attack = null
var combo_idx := 0
var combo_timer := 0.0
var queued := false
var lmb_t := 0.0
var charging := false
var charge_t := 0.0
var charge_need := 0.85
var charge_ready := false
var charge_snd: AudioStreamPlayer
var guard := false
var guard_t := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector3.ZERO
var air_dash_used := false
var dash_hits := {}
var focus_active := false
var focus_t := 0.0
var scan_mode := false
var scan_target = null
var scan_progress := 0.0
var scan_candidates: Array = []
var scan_panel_open := false
var scan_beep_t := 0.0
var lock_target = null
var lock_lost := 0.0
var invuln := 0.0
var waves: Array = []
var pose := {"p": Vector3(), "r": Vector3(), "tw": 0.0}


func build(cam: Camera3D, vm: Katana) -> void:
	collision_layer = 2
	collision_mask = 1 | 8   # world + phase barriers
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.35
	safe_margin = 0.02
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT / 2
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	camera = cam
	katana = vm
	pose = {"p": Katana.POSE.rest[0], "r": Katana.POSE.rest[1], "tw": Katana.POSE.rest[2]}
	blade_light = OmniLight3D.new()
	blade_light.light_color = Color(0.5, 0.91, 1.0)
	blade_light.light_energy = 0.5
	blade_light.omni_range = 6.0
	blade_light.light_volumetric_fog_energy = 0.4
	get_parent().add_child(blade_light)
	visor_light = OmniLight3D.new()
	visor_light.light_color = Color(0.66, 0.75, 0.85)
	visor_light.light_energy = 0.55
	visor_light.omni_range = 9.0
	visor_light.omni_attenuation = 1.4
	visor_light.light_volumetric_fog_energy = 0.0
	visor_light.light_specular = 0.2
	get_parent().add_child(visor_light)
	chain = MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.012; cm.bottom_radius = 0.012; cm.height = 1.0; cm.radial_segments = 6
	chain.mesh = cm
	var chm := StandardMaterial3D.new()
	chm.albedo_color = Color.BLACK; chm.emission_enabled = true; chm.emission = Color(1.0, 0.7, 0.3); chm.emission_energy_multiplier = 3.0
	chain.material_override = chm
	chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chain.visible = false
	get_parent().add_child(chain)


# ================================================================ helpers
func forward() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func eye_pos() -> Vector3:
	return global_position + Vector3(0, EYE, 0)


func add_shake(v: float) -> void:
	shake = min(1.2, shake + v)


func respawn(pos: Vector3, p_yaw := 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	yaw = p_yaw
	pitch = 0.0
	hp = max_hp
	ki = max_ki
	grapple = null
	collision_mask = 1 | 8
	dead = false
	attack = null
	cancel_charge()
	guard = false
	lock_target = null
	invuln = 1.0
	dash_t = 0.0
	if focus_active:
		end_focus()
	for w in waves:
		w.node.queue_free()
	waves.clear()


func collect(kind: String) -> void:
	if kind == "hp":
		hp = min(max_hp, hp + 12)
	else:
		ki = min(max_ki, ki + 25)
	G.audio.play("pickup", -6.0)


# ================================================================ damage
func receive_hit(dmg: float, src: Vector3, kind := "melee", attacker = null) -> String:
	if dead:
		return "none"
	if invuln > 0.0:
		return "evaded"
	var to_src := (src - eye_pos()); to_src.y = 0
	to_src = to_src.normalized()
	var fwd := G.flat_forward(yaw)
	if guard and fwd.dot(to_src) > 0.25:
		if guard_t < 0.25:
			G.audio.play3d("deflect", src, 2.0)
			G.fx.cyan_burst(eye_pos() + fwd * 0.8, 30)
			G.fx.light_flash(eye_pos(), Color(0.62, 0.96, 1.0), 6.0, 0.2)
			G.hit_stop(0.14)
			ki = min(max_ki, ki + 15)
			add_shake(0.3)
			if attacker and attacker.has_method("stagger"):
				attacker.stagger(1.6, fwd)
			G.hud.message("PARRY", 0.6)
			return "parry"
		hp -= dmg * 0.15
		ki = max(0.0, ki - 8)
		G.audio.play3d("clang", src)
		G.fx.sparks(eye_pos() + fwd * 0.7, -to_src, 12)
		add_shake(0.25)
		velocity += to_src * -4.0
		return "block"
	hp -= dmg
	invuln = 0.6
	G.hud.damage(dmg)
	G.audio.play("hurt", 0.0)
	stat_v = 1.0
	add_shake(0.5)
	velocity += to_src * -6.0
	if hp <= 0.0:
		hp = 0.0
		dead = true
		G.director.on_death()
	return "hit"


# ================================================================ abilities
func start_slash(idx: int) -> void:
	var s: Dictionary = SLASHES[idx]
	attack = {"kind": "slash", "idx": idx, "t": 0.0, "dur": s.dur, "hit": false, "from": pose.duplicate(), "def": s}
	queued = false
	G.audio.play("swing_%d" % idx, -2.0)


func start_wave() -> void:
	attack = {"kind": "wave", "t": 0.0, "dur": 0.4, "hit": false, "from": pose.duplicate()}
	ki -= 25
	G.audio.play("wave_release", 0.0)


func fire_wave() -> void:
	var dir := forward()
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.3
	tm.rings = 32
	tm.ring_segments = 3
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.2, 3.0, 4.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	var p := eye_pos() + dir * 0.8 - Vector3(0, 0.15, 0)
	# a horizontal crescent facing along the throw direction (front half of a flattened torus)
	mi.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP).rotated(dir, randf_range(-0.15, 0.15)), p)
	mi.scale = Vector3(1, 0.06, 0.5)
	waves.append({"node": mi, "mat": m, "dir": dir, "dist": 0.0, "hits": {}, "life": 1.2})
	G.fx.light_flash(p, Color(0.56, 0.94, 1.0), 5.0, 0.2)
	add_shake(0.25)


func perform_hit(dmg: float, heavy: bool, streak_angle: float) -> void:
	var eye := eye_pos()
	var fwd := forward()
	var hits := 0
	for e in G.enemies.list:
		if not e.alive or e.dormant:
			continue
		var c: Vector3 = e.center()
		var to := c - eye
		var dist = to.length() - e.radius
		if dist > 3.0:
			continue
		to = to.normalized()
		var cos_limit := 0.2 if dist < 1.2 else 0.55
		if fwd.dot(to) < cos_limit:
			continue
		var hp_pos = c - to * e.radius * 0.7
		e.take_damage(dmg, fwd, "heavy" if heavy else "slash")
		hits += 1
		if e.organic:
			G.fx.ichor(hp_pos, fwd, 30 if heavy else 18)
		else:
			G.fx.sparks(hp_pos, fwd, 28 if heavy else 16)
		G.fx.streak(hp_pos, streak_angle + randf_range(-0.1, 0.1))
		G.audio.play3d("slash_heavy" if heavy else "slash_hit", hp_pos, 2.0)
	for b in G.enemies.bolts:
		if b.reflected or b.dead:
			continue
		var to: Vector3 = b.pos - eye
		if to.length() > 3.6 or fwd.dot(to.normalized()) < 0.35:
			continue
		G.enemies.reflect_bolt(b)
		G.audio.play3d("deflect", b.pos, 2.0)
		G.fx.cyan_burst(b.pos, 24)
		G.hud.message("DEFLECT", 0.6)
		hits += 1
	for d in G.level.doors.values():
		var to: Vector3 = d.panel_pos - eye
		var dist := to.length()
		if dist > 3.4 or fwd.dot(to.normalized()) < 0.5:
			continue
		d.strike()
		G.fx.sparks(eye + fwd * min(dist, 2.5), Vector3.ZERO, 8)
		G.audio.play3d("clang", d.panel_pos)
	if hits > 0:
		G.hit_stop(0.11 if heavy else 0.065)
		add_shake(0.35 if heavy else 0.18)
		G.hud.hit_marker()
		ki = min(max_ki, ki + 3 * hits)
		G.fx.light_flash(eye + fwd * 1.5, Color(0.62, 0.96, 1.0), 4.0 if heavy else 2.5, 0.1)


func start_dash(wish: Vector3) -> void:
	dash_dir = (wish if wish.length_squared() > 0.01 else G.flat_forward(yaw)).normalized()
	dash_t = 0.17
	dash_cd = 0.5
	ki -= 12
	invuln = max(invuln, 0.24)
	if not on_ground:
		air_dash_used = true
	dash_hits.clear()
	if G.has_ability("phase"):
		collision_mask = 1          # slip through phase barriers
		invuln = max(invuln, 0.3)
		G.audio.play("cloak", -6.0, 1.4)
	G.audio.play("dash", -1.0)
	dash_v = 1.0


func start_focus() -> void:
	focus_active = true
	focus_t = 4.5
	ki -= 35
	G.audio.focus(true)


func end_focus() -> void:
	focus_active = false
	G.audio.focus(false)


func toggle_lock() -> void:
	if lock_target:
		lock_target = null
		return
	var eye := eye_pos()
	var fwd := forward()
	var best = null
	var best_score := INF
	for e in G.enemies.list:
		if not e.alive or e.dormant or (e.cloaked and not scan_mode):
			continue
		var to: Vector3 = e.center() - eye
		var d := to.length()
		if d > 32.0:
			continue
		var ang := acos(clamp(fwd.dot(to.normalized()), -1.0, 1.0))
		if ang > 0.65:
			continue
		var score := ang * 3.0 + d * 0.05
		if score < best_score and G.level.line_of_sight(eye, e.center()):
			best = e
			best_score = score
	if best:
		lock_target = best
		G.audio.play("lock_0", -8.0)
	else:
		G.audio.play("lock_1", -10.0)


func cancel_charge() -> void:
	charging = false
	charge_t = 0.0
	charge_ready = false
	if charge_snd:
		charge_snd.stop()
		charge_snd = null


# ================================================================ scan visor
func update_scan(dt: float) -> void:
	var eye := eye_pos()
	var fwd := forward()
	scan_candidates.clear()
	for s in G.level.scannables:
		var to: Vector3 = s.pos - eye
		if to.length() > 22.0 or fwd.dot(to.normalized()) < 0.3:
			continue
		scan_candidates.append(s)
	for e in G.enemies.list:
		if not e.alive or e.scan_info.is_empty():
			continue
		var c: Vector3 = e.center()
		var to := c - eye
		if to.length() > 30.0 or fwd.dot(to.normalized()) < 0.3:
			continue
		if e.scan_proxy.is_empty():
			e.scan_proxy = {"pos": c, "enemy": e, "title": e.scan_info.title, "text": e.scan_info.text, "radius": 0.8, "type": e.kind, "on_scan": Callable()}
		e.scan_proxy.pos = c
		e.scan_proxy.scanned = G.scanned_types.has(e.kind)
		scan_candidates.append(e.scan_proxy)
	var best = null
	var best_a := INF
	for s in scan_candidates:
		var to: Vector3 = s.pos - eye
		var d := to.length()
		var a := acos(clamp(fwd.dot(to.normalized()), -1.0, 1.0))
		var tol: float = max(0.06, atan(s.get("radius", 0.8) / d) * 1.4)
		if a < tol and a < best_a and G.level.line_of_sight(eye, s.pos - to.normalized() * 0.4):
			best = s
			best_a = a
	if best != scan_target:
		scan_progress = 0.0
		scan_target = best
	if scan_panel_open:
		if Input.is_action_just_pressed("attack"):
			scan_panel_open = false
			G.hud.close_scan()
		return
	if best and Input.is_action_pressed("attack"):
		if best.get("scanned", false):
			if Input.is_action_just_pressed("attack"):
				G.hud.open_scan(best)
				scan_panel_open = true
				G.audio.play("scan_beep_3", -10.0)
		else:
			scan_progress += dt / 1.1
			scan_beep_t -= dt
			if scan_beep_t <= 0.0:
				scan_beep_t = 0.12
				G.audio.play("scan_beep_%d" % clamp(int(scan_progress * 6), 0, 5), -14.0)
			if scan_progress >= 1.0:
				best.scanned = true
				if best.has("enemy"):
					G.scanned_types[best.type] = true
				scan_progress = 0.0
				G.audio.play("scan_done", -6.0)
				G.hud.open_scan(best)
				scan_panel_open = true
				if best.on_scan.is_valid():
					best.on_scan.call()
	else:
		scan_progress = max(0.0, scan_progress - dt * 2.0)


# ================================================================ physics (movement)
func physics_update(dt: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	var controls: bool = G.controls_enabled
	var f := 0.0
	var s := 0.0
	if controls:
		f = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		s = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var fwd_flat := G.flat_forward(yaw)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var wish := fwd_flat * f + right * s
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	if controls and Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and ki >= 12 and (on_ground or not air_dash_used):
		start_dash(wish)
	var speed := 5.4
	if guard: speed *= 0.45
	if scan_mode: speed *= 0.6
	if charging: speed *= 0.65
	if attack != null: speed *= 0.75
	if dash_t > 0.0:
		dash_t -= dt
		velocity.x = dash_dir.x * 24.0
		velocity.z = dash_dir.z * 24.0
		velocity.y = max(velocity.y, 0.0) * 0.5
		for e in G.enemies.list:
			if not e.alive or e.dormant or dash_hits.has(e):
				continue
			var c: Vector3 = e.center()
			if Vector2(c.x - global_position.x, c.z - global_position.z).length() < e.radius + 1.0 and abs(c.y - (global_position.y + 1.0)) < 2.0:
				dash_hits[e] = true
				e.take_damage(20 if G.has_ability("phase") else 10, dash_dir, "dash")
				if e.organic:
					G.fx.ichor(c, dash_dir, 14)
				else:
					G.fx.sparks(c, dash_dir, 14)
				G.audio.play3d("slash_hit", c)
				G.fx.streak(c, 0.0, Color(1.5, 1, 3.5), 3.5, 0.2)
				G.hit_stop(0.04)
		if dash_t <= 0.0:
			velocity.x *= 0.35
			velocity.z *= 0.35
			collision_mask = 1 | 8
	elif grapple != null:
		_grapple_physics(dt)
	else:
		var rate := 14.0 if on_ground else 3.0
		var k := 1.0 - exp(-rate * dt)
		velocity.x += (wish.x * speed - velocity.x) * k
		velocity.z += (wish.z * speed - velocity.z) * k
	if controls and Input.is_action_just_pressed("jump"):
		if on_ground:
			velocity.y = 6.4
			on_ground = false
			G.audio.play("jump", -10.0)
		elif G.has_ability("leap") and not double_jumped and grapple == null:
			double_jumped = true
			velocity.y = 6.8
			G.audio.play("dash", -6.0, 1.5)
			G.fx.ring(global_position + Vector3(0, 0.05, 0), Color(0.6, 0.4, 1.6), 1.8, 0.35)
			G.fx.burst(global_position, {"count": 14, "color": Color(0.8, 0.5, 2.0), "speed": 3.0, "life": 0.4, "size": 0.08})
	if dash_t <= 0.0 and grapple == null:
		hang_t = max(0.0, hang_t - dt)
		velocity.y -= 19.0 * dt * (0.3 if hang_t > 0.0 else 1.0)
	fall_speed = -velocity.y
	var pre_vel := velocity
	move_and_slide()
	# step up onto low ledges (crates, plinths) when blocked while grounded
	if is_on_floor() and is_on_wall() and Vector2(wish.x, wish.z).length() > 0.1:
		var horiz := Vector3(pre_vel.x, 0, pre_vel.z) * dt
		var up := Transform3D(global_transform.basis, global_position + Vector3(0, 0.45, 0))
		if not test_move(global_transform, Vector3(0, 0.45, 0)) and not test_move(up, horiz):
			global_position += Vector3(0, 0.45, 0) + horiz
			apply_floor_snap()
	on_ground = is_on_floor()
	if on_ground and not was_on_floor and fall_speed > 3.0:
		G.audio.play("land", linear_to_db(clamp(fall_speed / 12.0, 0.2, 1.0)))
		land_dip = min(0.25, fall_speed * 0.02)
	if on_ground:
		air_dash_used = false
		double_jumped = false
	was_on_floor = on_ground
	if global_position.y < G.level.kill_y:
		receive_hit(15, global_position, "fall")
		G.director.respawn(false)
	var hs := Vector2(velocity.x, velocity.z).length()
	if on_ground and hs > 0.8 and dash_t <= 0.0:
		step_dist += hs * dt
		bob_t += hs * dt * 1.35
		if step_dist > 2.0:
			step_dist = 0.0
			G.audio.play("footstep", linear_to_db(0.35 * min(1.0, hs / 5.0)))
	bob += ((sin(bob_t * 2.0) * 0.035 * min(1.0, hs / 5.0) if on_ground else 0.0) - bob) * min(1.0, dt * 10.0)


# ================================================================ frame (look, combat, camera)
func frame_update(dt: float, real_dt: float, mouse: Vector2) -> void:
	if dead:
		update_camera(real_dt)
		return
	invuln = max(0.0, invuln - dt)
	dash_cd = max(0.0, dash_cd - dt)
	combo_timer = max(0.0, combo_timer - dt)
	if not focus_active and not charging:
		ki = min(max_ki, ki + dt * 7.0)
	var controls: bool = G.controls_enabled
	look_delta = mouse if controls else Vector2.ZERO
	if lock_target and (not lock_target.alive or lock_target.dormant or (lock_target.cloaked and not scan_mode)):
		lock_target = null
	if lock_target:
		var c: Vector3 = lock_target.center()
		var to := c - eye_pos()
		var d := to.length()
		if d > 40.0:
			lock_target = null
		else:
			var k := 1.0 - exp(-real_dt * 12.0)
			yaw = lerp_angle(yaw, atan2(-to.x, -to.z), k)
			pitch += (asin(clamp(to.y / d, -1.0, 1.0)) - pitch) * k
			lock_lost = 0.0 if G.level.line_of_sight(eye_pos(), c) else lock_lost + real_dt
			if lock_lost > 1.5:
				lock_target = null
	else:
		var sens: float = G.main.sensitivity
		yaw -= look_delta.x * sens
		pitch = clamp(pitch - look_delta.y * sens, -1.45, 1.45)
	if controls:
		if Input.is_action_just_pressed("scan"):
			scan_mode = not scan_mode
			G.audio.play("visor_0" if scan_mode else "visor_1", -8.0)
			if not scan_mode:
				scan_panel_open = false
				G.hud.close_scan()
				scan_target = null
			if charging:
				cancel_charge()
			if scan_mode and not G.flags.get("scan_hinted", false):
				G.flags.scan_hinted = true
				G.hud.hint("Hold [b]LMB[/b] on a marker to scan. Cloaked things show up in this visor.", 6.0)
		if Input.is_action_just_pressed("lock"):
			toggle_lock()
		if G.has_ability("grapple"):
			grapple_candidate = _find_grapple_target()
			if Input.is_action_just_pressed("grapple") and grapple == null:
				fire_grapple()
		if Input.is_action_just_pressed("focus"):
			if focus_active:
				end_focus()
			elif ki >= 35:
				start_focus()
			else:
				G.audio.play("denied", -10.0)
	if focus_active:
		focus_t -= real_dt
		if focus_t <= 0.0:
			end_focus()
	if controls and scan_mode:
		update_scan(real_dt)
		guard = false
	elif controls:
		var want_guard := Input.is_action_pressed("guard") and attack == null and not charging
		if want_guard and not guard:
			guard_t = 0.0
			G.audio.play("clang", -18.0, 1.6)
		guard = want_guard
		if guard:
			guard_t += dt
		if Input.is_action_just_pressed("attack"):
			lmb_t = 0.0
			if attack == null:
				start_slash(combo_idx if combo_timer > 0.0 else 0)
			elif attack.kind == "slash" and attack.t > attack.dur * 0.35:
				queued = true
		if Input.is_action_pressed("attack"):
			lmb_t += dt
			if attack == null and lmb_t > 0.32 and not charging and ki >= 25:
				charging = true
				charge_t = 0.0
				charge_ready = false
				charge_snd = G.audio.play("charge", -4.0)
			if charging:
				charge_t += dt
				if not charge_ready and charge_t >= charge_need:
					charge_ready = true
					G.audio.play("scan_done", -8.0, 1.4)
		if Input.is_action_just_released("attack"):
			if charging:
				var ready := charge_t >= charge_need
				cancel_charge()
				if ready:
					start_wave()
			lmb_t = 0.0
	update_attack(dt)
	update_waves(dt)
	if hp < 30.0:
		heart_t -= real_dt
		if heart_t <= 0.0:
			heart_t = 0.75 + hp / 60.0
			G.audio.heartbeat(-4.0)
	update_camera(real_dt)


func update_attack(dt: float) -> void:
	var trail_on := false
	if attack != null:
		attack.t += dt
		var k: float = attack.t / attack.dur
		var pa: Array
		var pb: Array
		if attack.kind == "slash":
			pa = Katana.POSE[attack.def.a]
			pb = Katana.POSE[attack.def.b]
		else:
			pa = Katana.POSE.wavea
			pb = Katana.POSE.waveb
		var W := 0.2
		var S := 0.3
		var target: Dictionary
		if k < W:
			target = Katana.mix_pose(attack.from, pa, ease_out(k / W))
		elif k < W + S:
			target = Katana.mix_poses(pa, pb, ease_in_out((k - W) / S))
			trail_on = true
		else:
			target = Katana.mix_poses(pb, Katana.POSE.rest, ease_in_out(min(1.0, (k - W - S) / (1.0 - W - S))))
		if k > W + S * 0.2 and k < W + S + 0.05:
			trail_on = true
		if not attack.hit and k >= W + S * 0.45:
			attack.hit = true
			if attack.kind == "slash":
				perform_hit(attack.def.dmg, attack.def.heavy, attack.def.streak)
			else:
				fire_wave()
				perform_hit(14, true, 0.0)
		pose = target
		if attack.t >= attack.dur:
			var a = attack
			attack = null
			if a.kind == "slash":
				combo_idx = (a.idx + 1) % 3
				combo_timer = 0.0 if a.idx == 2 else 0.38
				if queued:
					start_slash(a.idx + 1 if a.idx < 2 else 0)
		elif attack.kind == "slash" and queued and k > 0.62 and attack.idx < 2:
			var idx: int = attack.idx
			attack = null
			start_slash(idx + 1)
	else:
		var rest: Array = Katana.POSE.rest
		if charging: rest = Katana.POSE.charge
		elif guard: rest = Katana.POSE.guard
		elif dash_t > 0.0: rest = Katana.POSE.dash
		elif scan_mode: rest = Katana.POSE.scan
		pose = Katana.mix_pose(pose, rest, 1.0 - exp(-dt * (22.0 if guard else 12.0)))
	var jitter = min(1.0, charge_t / charge_need) * 0.004 if charging else 0.0
	katana.apply(pose, look_delta, 1.0, bob_t, land_dip, jitter)
	katana.update_trail(trail_on)
	var charge = min(1.0, charge_t / charge_need) if charging else 0.0
	var glow = 0.9 + charge * 1.4 + (0.4 if trail_on else 0.0) + (0.3 if focus_active else 0.0)
	var col := Color(1.4, 1.2, 3.6) if focus_active else (Color(2.4, 2.6, 4.0) if charge >= 1.0 else Color(0.4, 2.6, 3.4))
	katana.set_glow(col * glow, 0.12 + charge * 1.2, dt)
	blade_light.light_energy = 0.4 + charge * 2.0 + (0.8 if trail_on else 0.0)


static func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


static func ease_in_out(t: float) -> float:
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0


func update_waves(dt: float) -> void:
	for i in range(waves.size() - 1, -1, -1):
		var w: Dictionary = waves[i]
		var node: MeshInstance3D = w.node
		var prev := node.global_position
		var step := 34.0 * dt
		node.global_position += w.dir * step
		w.dist += step
		w.life -= dt
		var sc = 1.0 + w.dist * 0.03
		node.scale = Vector3(sc, 0.06 * sc, 0.5 * sc)
		w.mat.albedo_color.a = min(1.0, w.life * 2.0)
		for e in G.enemies.list:
			if not e.alive or e.dormant or w.hits.has(e):
				continue
			var c: Vector3 = e.center()
			if _dist_point_segment(c, prev, node.global_position) < e.radius + 1.3 * sc:
				w.hits[e] = true
				e.take_damage(38, w.dir, "wave")
				if e.organic:
					G.fx.ichor(c, w.dir, 30)
				else:
					G.fx.sparks(c, w.dir, 30)
				G.audio.play3d("slash_heavy", c, 2.0)
				G.fx.streak(c, 0.0, Color(1.5, 3, 4), 4.0, 0.25)
				G.hit_stop(0.05)
		for b in G.enemies.bolts:
			if not b.dead and not b.reflected and _dist_point_segment(b.pos, prev, node.global_position) < 1.4:
				b.dead = true
				G.fx.cyan_burst(b.pos, 12)
		var wall_hit = not G.level.line_of_sight(prev, node.global_position)
		if wall_hit or w.life <= 0.0 or w.dist > 40.0:
			if wall_hit:
				G.fx.sparks(prev, -w.dir, 20)
				G.audio.play3d("clang", prev)
			node.queue_free()
			waves.remove_at(i)


static func _dist_point_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t: float = clamp((p - a).dot(ab) / max(1e-6, ab.length_squared()), 0.0, 1.0)
	return (a + ab * t).distance_to(p)


func update_camera(dt: float) -> void:
	shake = max(0.0, shake - dt * 2.2)
	land_dip = max(0.0, land_dip - dt * 0.8)
	stat_v = max(0.0, stat_v - dt * 1.6)
	dash_v = max(0.0, dash_v - dt * 4.0)
	var sh := shake * shake
	var strafe := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	roll += ((-strafe * 0.012 if G.controls_enabled else 0.0) - roll) * min(1.0, dt * 6.0)
	var cam_pos := global_position + Vector3(randf_range(-0.06, 0.06) * sh, EYE + bob - land_dip + randf_range(-0.06, 0.06) * sh, randf_range(-0.06, 0.06) * sh)
	if dead:
		cam_pos.y = global_position.y + 0.5
	camera.global_position = cam_pos
	camera.rotation = Vector3(pitch + randf_range(-0.015, 0.015) * sh, yaw, roll + (0.4 if dead else 0.0))
	var target_fov = 75.0 + (10.0 if dash_t > 0.0 else 0.0) - (6.0 if focus_active else 0.0) - (min(1.0, charge_t) * 4.0 if charging else 0.0)
	fov += (target_fov - fov) * min(1.0, dt * 10.0)
	camera.fov = fov
	var fwd := forward()
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	blade_light.global_position = cam_pos + fwd * 0.5 + right * 0.35 - Vector3(0, 0.2, 0)
	visor_light.global_position = cam_pos + fwd * 0.6
	_update_chain(dt, cam_pos + fwd * 0.4 + right * 0.3 - Vector3(0, 0.25, 0))


# ================================================================ abilities: grapple, hazards
func _find_grapple_target():
	var eye := eye_pos()
	var fwd := forward()
	var best = null
	var best_score := INF
	for gp in G.level.grapple_points:
		if not gp.get("active", true):
			continue
		var p: Vector3 = gp.get_pos.call() if gp.has("get_pos") else gp.pos
		var to := p - eye
		var d := to.length()
		if d > 28.0 or d < 1.5:
			continue
		var ang := acos(clamp(fwd.dot(to / d), -1.0, 1.0))
		if ang > 0.4:
			continue
		var score := ang * 4.0 + d * 0.02
		if score < best_score and G.level.line_of_sight(eye, p - to / d * 0.6):
			best = {"kind": "point", "gp": gp, "pos": p}
			best_score = score
	for e in G.enemies.list:
		if not e.alive or e.dormant or e.cloaked:
			continue
		var c: Vector3 = e.center()
		var to := c - eye
		var d := to.length()
		if d > 24.0:
			continue
		var ang := acos(clamp(fwd.dot(to / d), -1.0, 1.0))
		if ang > 0.18:
			continue
		var score := ang * 4.0 + d * 0.02 + 0.05
		if score < best_score and G.level.line_of_sight(eye, c):
			best = {"kind": "enemy", "enemy": e, "pos": c}
			best_score = score
	return best


func fire_grapple() -> void:
	var t = grapple_candidate
	G.audio.play("dash", -4.0, 0.7)
	if t == null:
		G.audio.play("lock_1", -10.0)
		return
	chain_t = 0.35
	chain_to = t.pos
	if t.kind == "enemy":
		var e = t.enemy
		if e.has_method("grappled"):
			e.grappled(eye_pos())
		G.audio.play3d("clang", t.pos, -2.0, 0.7)
		G.fx.sparks(t.pos, Vector3.ZERO, 12)
	elif t.gp.has("on_pull"):
		t.gp.on_pull.call()
		G.audio.play3d("clang", t.pos, 0.0, 0.6)
		G.fx.sparks(t.pos, Vector3.ZERO, 20)
	else:
		grapple = {"pos": t.pos, "t": 0.0}
		chain_t = 99.0
		lock_target = null
		G.audio.play3d("clang", t.pos, -4.0, 1.2)


func _grapple_physics(dt: float) -> void:
	grapple.t += dt
	var target: Vector3 = grapple.pos - Vector3(0, 1.4, 0)
	var to := target - global_position
	var d := to.length()
	velocity = to / max(d, 0.001) * min(26.0, 8.0 + grapple.t * 60.0)
	chain_to = grapple.pos
	if d < 1.2 or grapple.t > 1.6 or (grapple.t > 0.3 and get_real_velocity().length() < 2.0):
		velocity = velocity.normalized() * 6.0 + Vector3(0, 4.0, 0)
		grapple = null
		chain_t = 0.12
		double_jumped = false
		air_dash_used = false
		hang_t = 0.5


func _update_chain(dt: float, hand: Vector3) -> void:
	chain_t -= dt
	if chain_t <= 0.0:
		chain.visible = false
		return
	chain.visible = true
	var len := hand.distance_to(chain_to)
	if len < 0.05:
		chain.visible = false
		return
	chain.global_transform = G.level.cyl_xform(hand, chain_to)
	chain.scale = Vector3(1, len, 1)


func hazard_damage(amount: float, kind: String) -> void:
	if dead or invuln > 1e5:
		return
	hp -= amount
	G.hud.damage(amount * 0.6)
	hazard_snd_t -= get_process_delta_time()
	if hazard_snd_t <= 0.0:
		hazard_snd_t = 0.35
		G.audio.play("fizzle" if kind == "lava" else "crawler_hiss", -6.0, 1.3)
		stat_v = max(stat_v, 0.3)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		G.director.on_death()
