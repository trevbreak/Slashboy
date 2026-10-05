class_name FX
extends Node3D
## Particles and transient effects: bursts emitted from code, lit dust, steam vents,
## slash streaks, shockwave rings, light flashes and pickups.

const TEX := "res://assets/textures/"
var glow_tex: Texture2D
var burst_sys: GPUParticles3D
var dust: GPUParticles3D
var flash: OmniLight3D
var flash_t := 0.0
var flash_max := 0.1
var flash_i := 0.0
var transients: Array = []   # {node, life, max, kind, ...}
var pickups: Array = []
var debris_list: Array = []
var glow_shader := preload("res://shaders/glow_add.gdshader")


func _ready() -> void:
	glow_tex = load(TEX + "glow.png")
	burst_sys = _make_burst_system(2048, 1.2)
	flash = OmniLight3D.new()
	flash.light_energy = 0.0
	flash.omni_range = 16.0
	flash.shadow_enabled = false
	add_child(flash)
	_make_dust()


func _make_burst_system(amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = true
	p.one_shot = false
	p.explosiveness = 0.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 300, 800))
	var pm := ShaderMaterial.new()
	pm.shader = preload("res://shaders/particle_process.gdshader")
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var dm := ShaderMaterial.new()
	dm.shader = preload("res://shaders/particle_draw.gdshader")
	dm.set_shader_parameter("tex", glow_tex)
	q.material = dm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_dust() -> void:
	dust = GPUParticles3D.new()
	dust.amount = 700
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = false
	dust.visibility_aabb = AABB(Vector3(-10, -6, -10), Vector3(20, 12, 20))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(8, 3.5, 8)
	pm.gravity = Vector3(0, -0.01, 0)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.05
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_noise_speed = Vector3(0.05, 0.02, 0.05)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new(); gt.gradient = fade
	pm.color_ramp = gt
	dust.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = glow_tex
	m.albedo_color = Color(0.55, 0.58, 0.65)
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL   # lit: motes only show where light falls
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_receive_shadows = false
	q.material = m
	dust.draw_pass_1 = q
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)


var steams: Array = []


func clear() -> void:
	for s in steams:
		s.queue_free()
	steams.clear()
	for o in transients:
		o.node.queue_free()
	transients.clear()
	for p in pickups:
		p.node.queue_free()
	pickups.clear()
	for d in debris_list:
		d.node.queue_free()
	debris_list.clear()


var rain: GPUParticles3D


## Rain that follows the camera (outdoor sectors). Lit, so it glints under street lamps and neon.
func set_rain(on: bool) -> void:
	if on and rain == null:
		rain = GPUParticles3D.new()
		rain.amount = 2600
		rain.lifetime = 1.4
		rain.preprocess = 1.4
		rain.local_coords = false
		rain.visibility_aabb = AABB(Vector3(-14, -16, -14), Vector3(28, 30, 28))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(13, 0.5, 13)
		pm.direction = Vector3(0.08, -1, 0.04)
		pm.spread = 3.0
		pm.initial_velocity_min = 16.0
		pm.initial_velocity_max = 20.0
		pm.gravity = Vector3(0, -6, 0)
		pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
		rain.process_material = pm
		var q := QuadMesh.new(); q.size = Vector2(0.012, 0.55)
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(0.55, 0.6, 0.7, 0.35)
		m.roughness = 0.2
		q.material = m
		rain.draw_pass_1 = q
		rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rain)
		var col := GPUParticlesCollisionHeightField3D.new()
		col.size = Vector3(30, 40, 30)
		col.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
		col.follow_camera_enabled = true
		col.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS
		rain.add_child(col)
	if rain:
		rain.emitting = on
		rain.visible = on


func make_steam(pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	steams.append(p)
	p.amount = 90
	p.lifetime = 3.2
	p.preprocess = 3.0
	p.local_coords = false
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, 0.02, 0.3)
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0, 0.12, 0)
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 2.4))
	var sct := CurveTexture.new(); sct.curve = sc
	pm.scale_curve = sct
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 0.35))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new(); gt.gradient = fade
	pm.color_ramp = gt
	pm.angle_min = 0
	pm.angle_max = 360
	p.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = glow_tex
	m.albedo_color = Color(0.75, 0.78, 0.82, 0.5)
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.6
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


# ------------------------------------------------------------------ bursts
func emit(pos: Vector3, vel: Vector3, col: Color, size: float, life_scale: float, gravity := 9.0, drag := 1.0) -> void:
	# gravity/drag are per-system uniforms; bursts share a sensible default and vary by velocity
	var xf := Transform3D(Basis().scaled(Vector3.ONE * size), pos)
	burst_sys.emit_particle(xf, vel, col, Color(life_scale, 0, 0, 0),
		GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_ROTATION_SCALE | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM)


func burst(pos: Vector3, o := {}) -> void:
	var count: int = o.get("count", 20)
	var col: Color = o.get("color", Color(2, 1.5, 0.8))
	var speed: float = o.get("speed", 6.0)
	var life: float = o.get("life", 0.5)
	var size: float = o.get("size", 0.12)
	var dir: Vector3 = o.get("dir", Vector3.ZERO)
	var spread: float = o.get("spread", 1.0)
	for i in count:
		var v := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized() * spread
		v = (v + dir).normalized() * speed * randf_range(0.3, 1.0)
		emit(pos, v, col, size * randf_range(0.6, 1.4), life * randf_range(0.5, 1.0) / burst_sys.lifetime)


func sparks(pos: Vector3, dir := Vector3.ZERO, n := 18) -> void:
	burst(pos, {"count": n, "color": Color(3, 2, 0.8), "speed": 9.0, "life": 0.45, "size": 0.07, "dir": dir, "spread": 0.9})


func ichor(pos: Vector3, dir := Vector3.ZERO, n := 22) -> void:
	burst(pos, {"count": n, "color": Color(1.2, 0.2, 2.2), "speed": 6.0, "life": 0.7, "size": 0.13, "dir": dir})


func cyan_burst(pos: Vector3, n := 30) -> void:
	burst(pos, {"count": n, "color": Color(0.4, 2.2, 3.0), "speed": 7.0, "life": 0.5, "size": 0.1})


func _glow_quad(pos: Vector3, col: Color, size: Vector2, billboard := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2.ONE
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = glow_shader
	m.set_shader_parameter("tex", glow_tex)
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("billboard", billboard)
	mi.material_override = m
	mi.scale = Vector3(size.x, size.y, 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	return mi


func streak(pos: Vector3, angle: float, col := Color(1.5, 3, 3.5), length := 2.6, life := 0.16) -> void:
	# a camera-facing slash line: build it as a quad aligned to the view, rotated in screen space
	var cam := G.camera
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2.ONE
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = glow_shader
	m.set_shader_parameter("tex", glow_tex)
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("billboard", false)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var b := cam.global_transform.basis
	mi.global_transform = Transform3D(b * Basis(Vector3.BACK, angle), pos)
	mi.scale = Vector3(length, 0.12, 1)
	transients.append({"node": mi, "mat": m, "life": life, "max": life, "kind": "streak", "len": length})


func glow_flash(pos: Vector3, col := Color(2, 2, 2), size := 3.0, life := 0.25) -> void:
	var mi := _glow_quad(pos, col, Vector2(size, size))
	transients.append({"node": mi, "mat": mi.material_override, "life": life, "max": life, "kind": "flash", "size": size})


func ring(pos: Vector3, col := Color(0.5, 2, 3), max_r := 6.0, life := 0.6) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.85; tm.outer_radius = 1.0; tm.rings = 48; tm.ring_segments = 4
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(1, 0.05, 1)
	transients.append({"node": mi, "mat": m, "life": life, "max": life, "kind": "ring", "r": max_r, "col": col})


func light_flash(pos: Vector3, col := Color.WHITE, energy := 6.0, dur := 0.15) -> void:
	flash.global_position = pos
	flash.light_color = col
	flash.light_energy = energy
	flash_t = dur
	flash_max = dur
	flash_i = energy


## Detach a piece of a model and let it tumble, bounce, smoke and shrink away.
func debris(node: Node3D, vel: Vector3, spin: Vector3, life := 3.2) -> void:
	node.reparent(self, true)
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	debris_list.append({"node": node, "vel": vel, "spin": spin, "life": life, "max": life, "scale": node.scale, "spark_t": 0.0})


func pickup(pos: Vector3, kind := "hp") -> void:
	var col := Color(0.6, 2.5, 3.0) if kind == "hp" else Color(2, 1, 3)
	var mi := _glow_quad(pos, col, Vector2(0.5, 0.5))
	pickups.append({"node": mi, "kind": kind, "vel": Vector3(randf_range(-2, 2), randf_range(3, 5), randf_range(-2, 2)), "life": 14.0, "t": 0.0})


# ------------------------------------------------------------------ update
func update(dt: float, cam_pos: Vector3, player) -> void:
	dust.global_position = cam_pos
	if rain and rain.visible:
		rain.global_position = cam_pos + Vector3(0, 12, 0)
	for i in range(transients.size() - 1, -1, -1):
		var o: Dictionary = transients[i]
		o.life -= dt
		var k: float = max(0.0, o.life / o.max)
		match o.kind:
			"streak":
				o.node.scale = Vector3(o.len * (1.3 - k * 0.3), 0.12 * k + 0.02, 1)
				o.mat.set_shader_parameter("gain", k)
			"flash":
				o.node.scale = Vector3.ONE * o.size * (1.0 + (1.0 - k) * 0.6)
				o.mat.set_shader_parameter("gain", k)
			"ring":
				var r: float = 0.2 + (1.0 - k) * o.r
				o.node.scale = Vector3(r, 0.05, r)
				o.mat.albedo_color = Color(o.col.r, o.col.g, o.col.b, k)
		if o.life <= 0.0:
			o.node.queue_free()
			transients.remove_at(i)
	for i in range(debris_list.size() - 1, -1, -1):
		var d: Dictionary = debris_list[i]
		var n: Node3D = d.node
		d.life -= dt
		d.vel.y -= 14.0 * dt
		var p: Vector3 = n.global_position + d.vel * dt
		if p.y < 0.08 and d.vel.y < 0.0:
			p.y = 0.08
			d.vel.y = -d.vel.y * 0.35
			d.vel.x *= 0.6
			d.vel.z *= 0.6
			d.spin *= 0.6
			if abs(d.vel.y) > 1.5:
				G.audio.play3d("clank", p, -10.0)
		n.global_position = p
		n.rotate_x(d.spin.x * dt)
		n.rotate_y(d.spin.y * dt)
		n.rotate_z(d.spin.z * dt)
		d.spark_t -= dt
		if d.spark_t <= 0.0 and d.life > d.max * 0.4:
			d.spark_t = randf_range(0.04, 0.12)
			emit(p, Vector3(randf_range(-1, 1), randf_range(0.5, 2.0), randf_range(-1, 1)), Color(3, 1.4, 0.5), 0.07, 0.3)
		var k: float = clamp(d.life / (d.max * 0.35), 0.0, 1.0)
		n.scale = d.scale * k
		if d.life <= 0.0:
			n.queue_free()
			debris_list.remove_at(i)
	if flash_t > 0.0:
		flash_t -= dt
		flash.light_energy = max(0.0, flash_t / flash_max) * flash_i
	else:
		flash.light_energy = 0.0
	if player == null:
		return
	var target: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	for i in range(pickups.size() - 1, -1, -1):
		var p: Dictionary = pickups[i]
		p.t += dt
		p.life -= dt
		var node: MeshInstance3D = p.node
		var d := node.global_position.distance_to(target)
		if p.t > 0.6 and d < 5.0:
			p.vel = p.vel.lerp((target - node.global_position).normalized() * 14.0, min(1.0, dt * 6.0))
		else:
			p.vel.y -= 9.0 * dt
			p.vel *= 1.0 - dt * 1.5
		node.global_position += p.vel * dt
		if node.global_position.y < 0.3:
			node.global_position.y = 0.3
			p.vel.y = abs(p.vel.y) * 0.4
		node.scale = Vector3.ONE * (0.4 + sin(p.t * 8.0) * 0.08)
		if p.t > 0.6 and d < 0.8:
			player.collect(p.kind)
			node.queue_free()
			pickups.remove_at(i)
		elif p.life <= 0.0:
			node.queue_free()
			pickups.remove_at(i)
