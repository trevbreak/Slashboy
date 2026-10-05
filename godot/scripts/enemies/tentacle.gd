class_name Tentacle
extends Boss
## Bloom Heart limb: a giant segmented tendril rooted in the floor. Sways, rears, and slams down
## at the player, or sweeps low across the floor (jump it). A slam embeds it in the deck for a
## moment: only then can it be cut. Severing it drops the upper length as debris.

const SEGS := 12
const SEG_LEN := 0.75
var segs: Array = []           # Node3D joints, chained
var seg_mats: Array = []
var weak_mat: StandardMaterial3D
var attack_cd := 2.0
var aim_yaw := 0.0
var rear := 0.0               # 0 = upright, 1 = reared back, -1 = slammed flat
var slam_hit := false
var sweep_dir := 1.0
var sway_t := 0.0
var lean := 0.0
var cd_scale := 1.0
var heart = null


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "tentacle"
	max_hp = opts.get("hp", 70.0); hp = max_hp
	radius = 0.55; center_y = 3.0
	organic = true; drop_count = 2
	cd_scale = opts.get("cd_scale", 1.0)
	heart = opts.get("heart", null)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = 0
	scan_info = {"title": "BLOOM LIMB", "text": "A tendril of the Heart, thick as a tram car and rooted through the deck.\nIts hide turns a blade. When it slams down it sticks for a moment:\nthe exposed seam can be cut. Jump its low sweeps."}
	var skin := Creatures.flesh(Color(1.0, 0.25, 0.5), 2.0, Color(0.45, 0.2, 0.3))
	flash_mats = [skin]
	weak_mat = Creatures.emissive(Color(1.0, 0.3, 0.55), 0.4)
	rig = Node3D.new(); add_child(rig)
	var parent: Node3D = rig
	for i in SEGS:
		var j := Node3D.new()
		j.position = Vector3(0, 0.0 if i == 0 else SEG_LEN, 0)
		parent.add_child(j)
		var r0 := 0.7 * (1.0 - float(i) / SEGS) + 0.12
		var r1 := 0.7 * (1.0 - float(i + 1) / SEGS) + 0.12
		var cm := CylinderMesh.new(); cm.top_radius = r1; cm.bottom_radius = r0; cm.height = SEG_LEN * 1.05; cm.radial_segments = 14; cm.rings = 1
		Creatures.add(j, cm, skin, Vector3(0, SEG_LEN * 0.5, 0))
		# seam of glowing weak tissue along the underside
		var sm := BoxMesh.new(); sm.size = Vector3(r0 * 0.5, SEG_LEN * 0.9, 0.06)
		Creatures.add(j, sm, weak_mat, Vector3(0, SEG_LEN * 0.5, -r0 * 0.92))
		if i % 3 == 1:
			for s in [-1, 1]:
				var spike := CylinderMesh.new(); spike.top_radius = 0.0; spike.bottom_radius = r0 * 0.25; spike.height = r0 * 1.1
				Creatures.add(j, spike, skin, Vector3(s * r0 * 0.9, SEG_LEN * 0.5, r0 * 0.3), Vector3.ONE, Vector3(0, 0, -s * 1.2))
		segs.append(j)
		parent = j
	set_state("rise")
	rig.position.y = -SEGS * SEG_LEN
	aim_yaw = randf() * TAU


## Nearest point along the limb to the player: lets the blade connect anywhere along it.
func center() -> Vector3:
	if segs.is_empty() or G.player == null:
		return global_position + Vector3(0, center_y, 0)
	var eye: Vector3 = G.player.eye_pos()
	var best: Vector3 = segs[0].global_position
	var bd := 1e9
	for s in segs:
		var p: Vector3 = s.global_position
		var d := p.distance_squared_to(eye)
		if d < bd:
			bd = d; best = p
	return best


func tip() -> Vector3:
	return segs[segs.size() - 1].global_position


func take_damage(dmg: float, dir: Vector3, dmg_kind: String) -> void:
	if not alive:
		return
	if state != "embedded" and dmg_kind != "reflect":
		G.audio.play3d("clang", center(), -2.0, 0.6)
		G.fx.sparks(center(), -dir, 6)
		return
	super.take_damage(dmg, dir, dmg_kind)


func on_hurt(_dmg: float, _dir: Vector3, _k: String) -> void:
	G.audio.play3d("crawler_screech", center(), 2.0, 0.5)


func on_die(_dir: Vector3) -> void:
	G.audio.play3d("tentacle", center(), 8.0, 0.6)
	G.audio.play3d("crawler_die", center(), 6.0, 0.5)
	G.hit_stop(0.12)
	# sever: the upper limb comes away in chunks
	var cut := 3
	for i in range(SEGS - 1, cut, -1):
		var s: Node3D = segs[i]
		G.fx.ichor(s.global_position, Vector3.UP, 12)
		G.fx.debris(s, Vector3(randf_range(-3, 3), randf_range(1, 4), randf_range(-3, 3)), Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)), 3.0)
	G.fx.ichor(segs[cut].global_position, Vector3.UP, 80)
	segs = segs.slice(0, cut + 1)
	weak_mat.emission_energy_multiplier = 0.0
	if heart and is_instance_valid(heart):
		heart.limb_severed(self)


func _pose(dt: float) -> void:
	# a curve: bend accumulates along the chain. rear>0 arcs backward, rear<0 slams forward.
	sway_t += dt
	rig.rotation.y = aim_yaw
	var base_bend: float
	for i in segs.size():
		var s: Node3D = segs[i]
		var k := float(i) / SEGS
		var sway = sin(sway_t * 1.3 + i * 0.5) * 0.06 * (1.0 - abs(rear))
		if rear >= 0.0:
			base_bend = -rear * 0.22 * (0.5 + k)
		else:
			base_bend = -rear * (0.42 if i < 3 else (0.25 if i < 5 else 0.0))
		s.rotation.x = lerp(s.rotation.x, base_bend + sway, min(1.0, dt * 12.0))
		s.rotation.z = lerp(s.rotation.z, lean * 0.12 * k + sin(sway_t * 0.9 + i * 0.4) * 0.04, min(1.0, dt * 6.0))


func update(dt: float, ws: float) -> void:
	var P = G.player
	state_t += dt
	update_flash(dt)
	update_waves(dt)
	var to: Vector3 = P.global_position - global_position
	to.y = 0
	var dist := to.length()
	# rig yaw: -Z of the rig is "forward"; the curl bends toward +Z when rear < 0, so face away
	var want_yaw := G.yaw_to(to.x, to.z) + PI
	attack_cd -= dt
	match state:
		"rise":
			rig.position.y = lerp(rig.position.y, 0.0, min(1.0, dt * 2.5))
			if state_t > 1.6:
				rig.position.y = 0.0
				set_state("idle")
				attack_cd = randf_range(0.5, 2.5) * cd_scale
		"idle":
			aim_yaw = lerp_angle(aim_yaw, want_yaw, dt * 1.5)
			rear = lerp(rear, 0.0, dt * 3.0)
			if attack_cd <= 0.0:
				if dist < 10.5 and randf() < 0.65:
					set_state("windup")
					G.audio.play3d("tentacle", tip(), 2.0, 0.8)
				else:
					set_state("sweep_wind")
					sweep_dir = -1.0 if randf() < 0.5 else 1.0
					G.audio.play3d("tentacle", tip(), 2.0, 0.6)
		"windup":
			aim_yaw = lerp_angle(aim_yaw, want_yaw, dt * 4.0)
			rear = lerp(rear, 1.0, dt * 4.0)
			weak_mat.emission_energy_multiplier = 0.4 + state_t * 2.0
			if state_t > 0.9 / max(cd_scale, 0.6):
				set_state("slam")
				slam_hit = false
		"slam":
			rear = lerp(rear, -1.0, min(1.0, dt * 14.0))
			if rear < -0.9 and not slam_hit:
				slam_hit = true
				var t := tip()
				t.y = global_position.y
				shockwave(t, 4.5, 0.4, 14.0, Color(1.6, 0.4, 0.7))
				G.audio.play3d("stomp", t, 6.0)
				G.fx.burst(t, {"count": 30, "color": Color(0.4, 0.2, 0.25), "speed": 6.0, "life": 0.7, "size": 0.25})
				P.add_shake(0.4)
				# direct hit along the limb's line
				var fwd := G.flat_forward(aim_yaw + PI)
				var pp: Vector3 = P.global_position - global_position
				var along := pp.dot(fwd)
				var lat := (pp - fwd * along); lat.y = 0
				if along > 0.0 and along < SEGS * SEG_LEN + 0.5 and lat.length() < 1.3 and P.global_position.y - global_position.y < 1.2:
					P.receive_hit(22, t, "melee", self)
				set_state("embedded")
				weak_mat.emission_energy_multiplier = 3.5
		"embedded":
			rear = -1.0
			weak_mat.emission_energy_multiplier = 2.5 + sin(state_t * 14.0) * 1.0
			if randf() < 0.1:
				G.fx.emit(tip(), Vector3(0, 2, 0), Color(1.2, 0.3, 0.6), 0.1, 0.5)
			if state_t > 2.4:
				set_state("recover")
				G.audio.play3d("tentacle", tip(), 0.0, 1.0)
		"recover":
			rear = lerp(rear, 0.0, dt * 3.0)
			weak_mat.emission_energy_multiplier = lerp(weak_mat.emission_energy_multiplier, 0.4, dt * 3.0)
			if state_t > 0.9:
				set_state("idle")
				attack_cd = randf_range(2.0, 4.0) * cd_scale
		"sweep_wind":
			aim_yaw = lerp_angle(aim_yaw, want_yaw - sweep_dir * 1.4, dt * 4.0)
			rear = lerp(rear, -0.85, dt * 5.0)
			if state_t > 0.8:
				set_state("sweep")
				slam_hit = false
		"sweep":
			rear = -0.85
			aim_yaw += sweep_dir * dt * 2.6
			var fwd := G.flat_forward(aim_yaw + PI)
			var pp: Vector3 = P.global_position - global_position
			var along := pp.dot(fwd)
			var lat := (pp - fwd * along); lat.y = 0
			if not slam_hit and along > 0.0 and along < SEGS * SEG_LEN and lat.length() < 1.0 and P.global_position.y - global_position.y < 1.0:
				slam_hit = true
				P.receive_hit(16, global_position + fwd * along, "melee", self)
				P.velocity += Vector3(fwd.z, 0, -fwd.x) * sweep_dir * 8.0 + Vector3(0, 3, 0)
			if randf() < 0.4:
				G.fx.emit(global_position + fwd * randf_range(2.0, 8.0) + Vector3(0, 0.1, 0), Vector3(0, 1.5, 0), Color(0.4, 0.3, 0.3), 0.2, 0.5)
			if state_t > 1.2:
				set_state("recover")
		"dead":
			rear = lerp(rear, 0.0, dt * 2.0)
			rig.position.y -= dt * 1.5
			if state_t > 3.5:
				remove_me = true
	_pose(dt)
