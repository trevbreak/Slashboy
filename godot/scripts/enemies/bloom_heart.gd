class_name BloomHeart
extends Boss
## The Bloom Heart: the colony's core organ, slung from the cavern roof on arteries.
## Armoured petals keep it sealed while its limbs fight. Sever every limb and it sags open,
## dropping within reach of the blade. It closes again after a while, or after enough damage,
## and regrows the limbs: faster, angrier. Three cycles, then it bursts and the Avatar emerges.

var heart_node: Node3D
var heart_mesh: MeshInstance3D
var petals: Array = []
var core_mat: StandardMaterial3D
var flesh_mat: ShaderMaterial
var glow: OmniLight3D
var limbs: Array = []
var limb_count := 0
var beat_t := 0.0
var beat_period := 1.3
var pulse := 0.0
var hang_y := 9.0
var open_y := 2.4
var cur_y := 9.0
var open_amt := 0.0
var window_hp := 0.0
var cycle := 0
var volley_t := 0.0
var limb_slots: Array = []


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "heart"
	boss_name = "THE BLOOM HEART"
	max_hp = 600; hp = 600
	radius = 2.6; center_y = hang_y
	organic = true; drop_count = 0
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = 0
	limb_slots = opts.get("slots", [])
	scan_info = {"title": "THE BLOOM HEART", "text": "The colony's central organ. Every thrall, every growth on the station, beats to this rhythm.\nArmoured while its limbs live. Cut the limbs when they embed in the deck.\nWhen it sags open, strike the core."}
	flesh_mat = Creatures.flesh(Color(1.0, 0.2, 0.45), 3.2, Color(0.55, 0.18, 0.28))
	var chit := Creatures.chitin()
	flash_mats = [flesh_mat]
	rig = Node3D.new(); add_child(rig)
	heart_node = Node3D.new(); heart_node.position.y = hang_y; rig.add_child(heart_node)
	heart_mesh = Creatures.add(heart_node, Creatures.organic(Creatures.sphere(2.2, 48, 28), 0.22, 2.2, 7), flesh_mat, Vector3.ZERO, Vector3(1, 1.15, 1))
	# chambers / lobes
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		Creatures.add(heart_node, Creatures.organic(Creatures.sphere(1.1, 28, 16), 0.2, 3.0, i), flesh_mat, Vector3(cos(a) * 1.5, 0.9 - (i % 2) * 1.4, sin(a) * 1.5))
	# exposed core
	core_mat = Creatures.emissive(Color(1.0, 0.35, 0.6), 1.0)
	Creatures.add(heart_node, Creatures.sphere(1.0, 32, 16), core_mat, Vector3(0, -1.2, 0))
	# armoured petals hinged at the top
	for i in 6:
		var a := i * TAU / 6.0
		var hinge := Node3D.new()
		hinge.position = Vector3(0, 1.6, 0)
		hinge.rotation.y = a
		heart_node.add_child(hinge)
		var pm := SphereMesh.new(); pm.radius = 1.6; pm.height = 3.2; pm.is_hemisphere = false
		var petal := Creatures.add(hinge, pm, chit, Vector3(0, -1.8, 1.55), Vector3(0.9, 1.5, 0.28))
		petal.rotation.x = -0.15
		petals.append(hinge)
	# arteries up to the roof
	for i in 7:
		var a := i * TAU / 7.0 + 0.2
		var r := 0.25 + (i % 3) * 0.1
		var cm := CylinderMesh.new(); cm.top_radius = r * 1.6; cm.bottom_radius = r; cm.height = 16.0; cm.radial_segments = 12
		var art := Creatures.add(rig, cm, flesh_mat, Vector3(cos(a) * (1.2 + (i % 2)), hang_y + 9.0, sin(a) * (1.2 + (i % 2))))
		art.rotation = Vector3(sin(a) * 0.2, 0, -cos(a) * 0.2)
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.3, 0.5)
	glow.light_energy = 2.0
	glow.omni_range = 22.0
	glow.light_volumetric_fog_energy = 2.5
	heart_node.add_child(glow)
	set_state("intro")


func center() -> Vector3:
	return heart_node.global_position + Vector3(0, -0.6 * open_amt, 0)


func limb_severed(_t) -> void:
	limb_count -= 1
	if limb_count <= 0 and state == "guarded":
		set_state("opening")
		G.audio.play3d("matriarch_roar", center(), 10.0, 0.5)
		G.hud.message("THE HEART IS EXPOSED", 2.0)


func _spawn_limbs() -> void:
	limbs.clear()
	var n: int = 4 if cycle < 2 else 5
	limb_count = 0
	for i in n:
		var p: Vector3 = limb_slots[i % limb_slots.size()] if limb_slots.size() else global_position + Vector3(cos(i * TAU / n), 0, sin(i * TAU / n)) * 9.0
		var t = mgr.spawn("tentacle", p, {"heart": self, "encounter": encounter, "hp": 60.0 + cycle * 15.0, "cd_scale": 1.0 - cycle * 0.2})
		G.fx.burst(p + Vector3(0, 0.3, 0), {"count": 40, "color": Color(0.4, 0.2, 0.25), "speed": 7.0, "life": 0.9, "size": 0.3})
		G.audio.play3d("tentacle", p, 6.0, 0.7)
		limbs.append(t)
		limb_count += 1
	G.player.add_shake(0.4)


func take_damage(dmg: float, dir: Vector3, dmg_kind: String) -> void:
	if not alive:
		return
	if state != "open":
		G.audio.play3d("clang", center(), -2.0, 0.5)
		return
	super.take_damage(dmg, dir, dmg_kind)
	window_hp += dmg * dmg_mult


func on_hurt(_dmg: float, _dir: Vector3, _k: String) -> void:
	G.audio.play3d("heart_thump", center(), 4.0, 1.3)
	pulse = 1.0


func on_die(_dir: Vector3) -> void:
	G.hit_stop(0.4)
	G.audio.play3d("matriarch_roar", center(), 12.0, 0.4)
	G.audio.play3d("collapse", center(), 8.0)
	for i in 10:
		G.main.get_tree().create_timer(i * 0.22).timeout.connect(func():
			if is_instance_valid(self):
				var p := center() + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
				G.audio.play3d("crawler_die", p, 6.0, 0.4)
				G.fx.ichor(p, Vector3(randf_range(-1, 1), 1, randf_range(-1, 1)), 80)
				G.fx.light_flash(p, Color(1.0, 0.3, 0.5), 14.0, 0.3))
	for l in limbs:
		if is_instance_valid(l) and l.alive:
			l.die(Vector3.UP)


func _spore_volley(n: int) -> void:
	var P = G.player
	for i in n:
		var from := center() + Vector3(randf_range(-1, 1), -1.0, randf_range(-1, 1))
		var tgt: Vector3 = P.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		if i == 0:
			tgt = P.global_position + P.velocity * 0.6
		var d := tgt - from
		var flat := Vector3(d.x, 0, d.z)
		var t := 1.3
		var v := flat / t
		v.y = (d.y + 0.5 * 12.0 * t * t) / t
		mgr.spawn_bolt(from, v, self, {"gravity": 12.0, "color": Color(1.2, 1.6, 0.4), "size": 1.0, "dmg": 10.0, "life": 4.0, "on_land": func(p: Vector3):
			G.audio.play3d("spore", p, 0.0, 1.2)
			G.fx.burst(p, {"count": 30, "color": Color(0.8, 1.2, 0.3), "speed": 3.0, "life": 1.4, "size": 0.35})
			var gy: float = global_position.y
			G.level.hazards.append({"box": [p.x - 1.6, gy - 0.5, p.z - 1.6, p.x + 1.6, gy + 2.0, p.z + 1.6], "dps": 18.0, "kind": "spore", "until": G.level.time + 3.0})})
	G.audio.play3d("spore", center(), 6.0, 0.7)


func update(dt: float, ws: float) -> void:
	state_t += dt
	update_flash(dt)
	# heartbeat
	beat_t -= dt
	if beat_t <= 0.0 and alive:
		beat_t = beat_period
		pulse = 1.0
		G.audio.play3d("heart_thump", center(), 6.0 + cycle * 2.0)
		if G.player.global_position.distance_to(center()) < 26.0:
			G.player.add_shake(0.08)
	pulse = max(0.0, pulse - dt * 3.0)
	var s := 1.0 + pulse * 0.07
	heart_node.scale = Vector3(s, s * 0.98, s)
	glow.light_energy = 1.5 + pulse * 3.0 + open_amt * 2.0
	flesh_mat.set_shader_parameter("vein_strength", 2.5 + pulse * 3.0)
	core_mat.emission_energy_multiplier = 0.6 + open_amt * (3.0 + pulse * 3.0)
	# limb list upkeep
	for i in range(limbs.size() - 1, -1, -1):
		if not is_instance_valid(limbs[i]):
			limbs.remove_at(i)
	match state:
		"intro":
			if state_t > 2.0:
				_spawn_limbs()
				set_state("guarded")
		"guarded":
			open_amt = lerp(open_amt, 0.0, dt * 2.0)
			cur_y = lerp(cur_y, hang_y, dt * 1.0)
			beat_period = 1.3 - cycle * 0.25
			if cycle >= 1:
				volley_t -= dt
				if volley_t <= 0.0:
					volley_t = 7.0 - cycle * 1.5
					_spore_volley(2 + cycle)
		"opening":
			open_amt = min(1.0, open_amt + dt * 0.8)
			cur_y = lerp(cur_y, open_y, min(1.0, dt * 1.6))
			if state_t > 2.0:
				set_state("open")
				window_hp = 0.0
				G.audio.play3d("heart_thump", center(), 10.0, 0.6)
		"open":
			open_amt = 1.0
			cur_y = open_y + sin(state_t * 1.2) * 0.2
			beat_period = 0.7
			if state_t > 9.0 or window_hp >= max_hp / 3.0 - 1.0:
				set_state("closing")
				G.audio.play3d("matriarch_roar", center(), 8.0, 0.6)
				cycle += 1
		"closing":
			open_amt = max(0.0, open_amt - dt * 1.2)
			cur_y = lerp(cur_y, hang_y, min(1.0, dt * 1.2))
			if state_t > 2.2:
				_spawn_limbs()
				set_state("guarded")
				volley_t = 3.0
		"dead":
			open_amt = 1.0
			cur_y = lerp(cur_y, -1.0, dt * 0.6)
			heart_node.scale = Vector3.ONE * max(0.1, 1.0 - state_t * 0.18)
			if state_t > 5.0:
				remove_me = true
	heart_node.position.y = cur_y
	for i in petals.size():
		petals[i].rotation.x = -open_amt * 1.05 - pulse * 0.04
