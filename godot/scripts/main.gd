extends Node3D
## Bootstrap + game loop. Builds the world, systems, rendering environment and post layer.
##
## Debug harness (command line, after `--`):
##   --autostart            skip the title
##   --warp=x,y,z --yaw=r   start at a position
##   --scenario=name        run a scripted test scenario (see _run_scenario)
##   --shot=path.png --at=s capture a screenshot at time s, then (with --quit) exit
##   --quality=ULTRA|HIGH|MEDIUM

# budget = megapixels of internal 3D resolution; MetalFX/FSR2 upscales to the display.
const QUALITY := {
	"ULTRA": {"budget": 3.6, "ssao": true, "ssil": true, "ssr": true, "sdfgi": true, "fog_size": 128},
	"HIGH": {"budget": 2.4, "ssao": true, "ssil": true, "ssr": true, "sdfgi": false, "fog_size": 96},
	"MEDIUM": {"budget": 1.5, "ssao": true, "ssil": false, "ssr": false, "sdfgi": false, "fog_size": 64},
}
const TARGET_FPS := 60.0

var env: Environment
var camera: Camera3D
var post: ColorRect
var post_mat: ShaderMaterial
var katana: Katana
var mouse := Vector2.ZERO
var sensitivity := 0.0022
var fade := 1.0
var focus_v := 0.0
var scan_v := 0.0
var steam_v := 0.0
var mood := {"density": 0.012, "color": Color(0.07, 0.1, 0.14), "exposure": 1.25, "ambient": 0.55}
var shot_done := false
var render_scale := 1.0
var budget_scale := 1.0
var adapt_t := 0.0
var adapt_frames := 0
var lift := {"active": false, "y0": 0.0, "t": 0.0}


func _ready() -> void:
	G.main = self
	_parse_args()
	_setup_input()
	_setup_environment()
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 3500.0
	camera.fov = 75
	camera.rotation_order = EULER_ORDER_YXZ
	add_child(camera)
	camera.make_current()
	G.camera = camera

	var audio := AudioManager.new(); add_child(audio); G.audio = audio
	var fx := FX.new(); fx.name = "FX"; add_child(fx); G.fx = fx
	var enemies := EnemyManager.new(); enemies.name = "Enemies"; add_child(enemies); G.enemies = enemies

	var vm_layer := CanvasLayer.new(); vm_layer.layer = 1; add_child(vm_layer)
	katana = Katana.new(); add_child(katana); katana.build(vm_layer)
	var post_layer := CanvasLayer.new(); post_layer.layer = 2; add_child(post_layer)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = preload("res://shaders/visor_post.gdshader")
	post.material = post_mat
	post_layer.add_child(post)
	var hud := HUD.new(); add_child(hud); G.hud = hud

	var player := Player.new(); player.name = "Player"; add_child(player); G.player = player
	player.build(camera, katana)
	var director := Director.new(); add_child(director); G.director = director
	load_sector(G.debug.get("sector", "s1"), G.debug.get("entry", "start"), null, 0.0, false)
	player.update_camera(0.016)
	G.hud.set_continue(G.has_save())

	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	set_quality(G.debug.get("quality", "HIGH"))
	if G.debug.has("autostart"):
		start_game.call_deferred(G.debug.has("continue"))


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		G.debug[kv[0]] = kv[1] if kv.size() > 1 else true
	if G.debug.has("quality"):
		G.debug.quality = String(G.debug.quality).to_upper()


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "dash": [KEY_SHIFT], "lock": [KEY_Q], "scan": [KEY_E], "focus": [KEY_R], "quality": [KEY_G], "fullscreen": [KEY_F11],
		"grapple": [KEY_F], "map": [KEY_M, KEY_TAB],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for pair in [["attack", MOUSE_BUTTON_LEFT], ["guard", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)


func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/textures/stars.png")
	pano.energy_multiplier = 1.2
	sky.sky_material = pano
	env.sky = sky
	env.background_energy_multiplier = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.24, 0.32)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.25
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in range(1, 8):
		env.set("glow_levels/%d" % i, [0.0, 0.6, 0.9, 1.0, 0.8, 0.5, 0.2][i - 1])
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.2
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.fog_enabled = false
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.7, 0.75, 0.85)
	env.volumetric_fog_emission = Color(0.07, 0.1, 0.14)
	env.volumetric_fog_emission_energy = 0.35
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.9
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func set_quality(name: String) -> void:
	if not QUALITY.has(name):
		name = "HIGH"
	G.quality = name
	var q: Dictionary = QUALITY[name]
	env.ssao_enabled = q.ssao
	env.ssil_enabled = q.ssil
	env.ssr_enabled = q.ssr
	env.sdfgi_enabled = q.sdfgi
	RenderingServer.environment_set_volumetric_fog_volume_size(q.fog_size, q.fog_size)
	_apply_budget()


## Pick an internal render scale that fits the preset's pixel budget for the current window.
func _apply_budget() -> void:
	var px := Vector2(get_window().size)
	var q: Dictionary = QUALITY[G.quality]
	budget_scale = clamp(sqrt(q.budget * 1e6 / max(1.0, px.x * px.y)), 0.34, 1.0)
	_set_scale(budget_scale)


func _set_scale(sc: float) -> void:
	render_scale = clamp(sc, 0.34, 1.0)
	var vp := get_viewport()
	if render_scale < 0.99:
		var metal := OS.get_name() == "macOS" and RenderingServer.get_current_rendering_driver_name() == "metal"
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL if metal else Viewport.SCALING_3D_MODE_FSR2
		vp.msaa_3d = Viewport.MSAA_DISABLED   # temporal upscaler provides anti-aliasing
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.msaa_3d = Viewport.MSAA_2X
	vp.scaling_3d_scale = render_scale


## Dynamic resolution: hold ~60 fps by trimming or restoring the render scale.
func _adapt(dt: float) -> void:
	adapt_t += dt
	adapt_frames += 1
	if adapt_t < 1.5:
		return
	var fps := adapt_frames / adapt_t
	adapt_t = 0.0
	adapt_frames = 0
	if fps < TARGET_FPS - 6.0 and render_scale > 0.35:
		_set_scale(render_scale * clamp(sqrt(fps / TARGET_FPS), 0.75, 0.95))
	elif fps > TARGET_FPS + 14.0 and render_scale < budget_scale:
		_set_scale(min(budget_scale, render_scale * 1.06))


func set_mood(density: float, color: Color, exposure: float, ambient: float, instant := false) -> void:
	mood = {"density": density, "color": color, "exposure": exposure, "ambient": ambient}
	if instant:
		env.volumetric_fog_density = density
		env.volumetric_fog_emission = color
		env.tonemap_exposure = exposure
		env.ambient_light_energy = ambient


func _on_resize() -> void:
	var size := get_window().size
	katana.resize(size)
	if env != null and G.quality != "":
		_apply_budget()


## Build a sector and drop the player in at an entry (or an explicit position, e.g. a save station).
func load_sector(id: String, entry: String, pos = null, yaw := 0.0, announce := true) -> void:
	G.enemies.clear_all()
	G.fx.clear()
	G.director.reset()
	G.player.grapple = null
	G.hud.boss(null)
	if G.level != null and is_instance_valid(G.level):
		G.level.name = "OldLevel"
		remove_child(G.level)
		G.level.queue_free()
	var lv: Level = Sectors.make(id)
	lv.name = "Level"
	add_child(lv)
	G.level = lv
	lv.build()
	lv.configure_environment(env)
	for v in lv.points.get("steam_vents", []):
		G.fx.make_steam(v)
	G.progress.sector = id
	G.director.setup()
	var spawn: Dictionary = lv.entries.get(entry, lv.entries.values()[0])
	var p: Vector3 = pos if pos != null else spawn.pos
	var y: float = yaw if pos != null else spawn.yaw
	var P = G.player
	P.max_hp = 100.0 + 25.0 * G.progress.tanks
	P.max_ki = 100.0 + 15.0 * G.progress.shards
	P.respawn(p, y)
	G.director.checkpoint = {"pos": p, "yaw": y}
	var first: bool = not G.progress.visited.has(id)
	G.progress.visited[id] = true
	print("[slashboy] sector %s: %d draw calls, %d lights, %d colliders" % [id, lv.merged_calls, lv.fixtures.size(), lv.world_body.get_child_count()])
	if announce:
		G.director.enter(entry, first)


## Fade out, swap sectors, fade in.
func travel(sector: String, entry: String, label: String) -> void:
	if G.state == "loading":
		return
	G.state = "loading"
	G.controls_enabled = false
	G.audio.set_combat(false)
	G.audio.set_boss_music(false)
	G.hud.message(label, 3.0)
	G.audio.play("door_close", -2.0)
	G.audio.play("leviathan_horn", -6.0)
	G.hud.fade_to(1.0, 1.4)
	await get_tree().create_timer(1.6).timeout
	load_sector(sector, entry)
	G.state = "playing"


func start_game(resume_save := false) -> void:
	if G.state != "title":
		return
	G.hud.show_hud()
	G.stats.start_ms = Time.get_ticks_msec()
	if not G.debug.has("shot"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	G.state = "playing"
	if resume_save and G.load_save():
		var sp = G.progress.save_pos
		load_sector(G.progress.sector, "", Vector3(sp[0], sp[1], sp[2]) if sp != null else null, float(G.progress.save_yaw))
		G.hud.message("SIGNAL RESTORED", 2.0)
	else:
		if not G.debug.has("sector"):
			G.new_progress()
		for a in String(G.debug.get("abilities", "")).split(",", false):
			G.progress.abilities[a] = true
		G.director.enter(G.debug.get("entry", "start"), true)
	if G.debug.has("warp"):
		var v := String(G.debug.warp).split_floats(",")
		G.player.global_position = Vector3(v[0], v[1], v[2])
		G.player.yaw = float(G.debug.get("yaw", 0.0))
		G.player.pitch = float(G.debug.get("pitch", 0.0))
		fade = 0.0
		G.controls_enabled = true
	if G.debug.has("scenario"):
		_run_scenario(G.debug.scenario)


func pause_game() -> void:
	if G.state != "playing":
		return
	G.state = "paused"
	G.hud.set_screen("pause", true)
	G.audio.pause(true)
	get_tree().paused = false


func resume_game() -> void:
	if G.state != "paused":
		return
	G.state = "playing"
	G.hud.set_screen("pause", false)
	G.audio.pause(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func lift_descent(y0: float) -> void:
	lift = {"active": true, "y0": y0, "t": 0.0}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if abs(event.relative.x) < 400 and abs(event.relative.y) < 400:
			mouse += event.relative
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if G.state == "playing":
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				pause_game()
		elif event.is_action("fullscreen"):
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		elif event.is_action("map") and G.state == "playing":
			G.hud.toggle_map()
		elif event.is_action("quality"):
			var names := QUALITY.keys()
			set_quality(names[(names.find(G.quality) + 1) % names.size()])
			G.hud.message("GRAPHICS: " + G.quality, 1.5)
	elif event is InputEventMouseButton and event.pressed and G.state == "playing" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not G.debug.has("shot"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and G.state == "playing" and not G.debug.has("shot"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_game()


func _physics_process(delta: float) -> void:
	if G.state != "playing" and G.state != "ending":
		return
	if G.state == "playing":
		G.player.physics_update(delta * G.player_scale)
	G.enemies.update(delta * G.world_scale, G.world_scale)


func _process(delta: float) -> void:
	var real_dt: float = min(delta, 0.05)
	var P = G.player
	if G.state == "playing" or G.state == "ending":
		var ws := 0.3 if P.focus_active else 1.0
		var ps := 0.85 if P.focus_active else 1.0
		if G.hitstop > 0.0:
			G.hitstop -= real_dt
			ws *= 0.04
			ps *= 0.15
		G.world_scale = ws
		G.player_scale = ps
		var wdt := real_dt * ws
		if G.state == "ending":
			if lift.active:
				lift.t += real_dt
				P.global_position.y = lift.y0 - lift.t * lift.t * 0.6
				P.velocity = Vector3.ZERO
			P.update_camera(real_dt)
		else:
			P.frame_update(real_dt * ps, real_dt, mouse)
		G.level.update(wdt, P.global_position)
		G.fx.update(wdt, camera.global_position, P)
		G.director.update(real_dt)
		G.hud.update(real_dt)
		G.audio.update(real_dt, P.global_position)
		# zone mood transitions
		var k: float = min(1.0, real_dt * 0.8)
		env.volumetric_fog_density = lerp(env.volumetric_fog_density, mood.density, k)
		env.volumetric_fog_emission = env.volumetric_fog_emission.lerp(mood.color, k)
		env.tonemap_exposure = lerp(env.tonemap_exposure, mood.exposure, k)
		env.ambient_light_energy = lerp(env.ambient_light_energy, mood.ambient, k)
		# steam vents fog the visor
		var near := false
		for v in G.level.points.get("steam_vents", []):
			if Vector2(P.global_position.x - v.x, P.global_position.z - v.z).length() < 1.1 and P.global_position.y < 2.0:
				near = true
		steam_v = min(1.0, steam_v + real_dt * 1.6) if near else max(0.0, steam_v - real_dt * 0.3)
		focus_v = lerp(focus_v, 1.0 if P.focus_active else 0.0, min(1.0, real_dt * 6.0))
		scan_v = lerp(scan_v, 1.0 if P.scan_mode else 0.0, min(1.0, real_dt * 8.0))
		post_mat.set_shader_parameter("damage", G.hud.damage_v)
		post_mat.set_shader_parameter("stat", P.stat_v)
		post_mat.set_shader_parameter("focus", focus_v)
		post_mat.set_shader_parameter("scan", scan_v)
		post_mat.set_shader_parameter("lowhp", 1.0 if P.hp < 30.0 else 0.0)
		post_mat.set_shader_parameter("dash", P.dash_v)
		post_mat.set_shader_parameter("steam", steam_v)
	else:
		G.level.update(real_dt * 0.2, P.global_position)
	post_mat.set_shader_parameter("fade", fade)
	mouse = Vector2.ZERO
	if not G.debug.has("noadapt"):
		_adapt(delta)
	_debug_tick()


# ------------------------------------------------------------------ debug harness
var _fps_t := 0.0
func _debug_tick() -> void:
	if G.debug.has("fps"):
		_fps_t += get_process_delta_time()
		if _fps_t > 2.0:
			_fps_t = 0.0
			print("[fps] %d  scale %.2f  frame %.1f ms  draw calls %d  prims %d" % [Engine.get_frames_per_second(), render_scale, 1000.0 / max(1, Engine.get_frames_per_second()),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	if not G.debug.has("shot") or shot_done:
		return
	var at := float(G.debug.get("at", 3.0))
	if Time.get_ticks_msec() / 1000.0 >= at:
		shot_done = true
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(String(G.debug.shot))
		print("[slashboy] screenshot -> ", G.debug.shot, "  fps=", Engine.get_frames_per_second())
		if G.debug.has("quit"):
			get_tree().quit()


func _run_scenario(name: String) -> void:
	var P = G.player
	P.invuln = 99999.0
	match name:
		"lineup":
			# a lit stage in the concourse with all three creatures frozen for inspection
			for t in G.director.triggers:
				t.fired = true
			P.global_position = Vector3(31, 0, -27)
			P.yaw = 0.15
			P.pitch = -0.12
			var c = G.enemies.spawn("crawler", Vector3(31.8, 0, -31.2))
			c.speed = 0.0; c.attack_cd = 1e9; c.facing = 2.6
			var s = G.enemies.spawn("sentinel", Vector3(33.6, 2.2, -32.5))
			s.fire_cd = 1e9
			var k = G.enemies.spawn("stalker", Vector3(28.8, 0, -32.8))
			k.set_cloak(false, true)
			k.set_state("recover")
			k.state_t = -1e9
		"arena":
			P.global_position = Vector3(34, 0, -106)
		"slash":
			P.start_slash(0)
		"scan":
			P.scan_mode = true
		"flow":
			_flow_test()
		"s2flow":
			DebugTests.s2_flow()
		"s3flow":
			DebugTests.s3_flow()
		"s4flow":
			DebugTests.s4_flow()
		"s5flow":
			DebugTests.s5_flow()
		"save_step":
			DebugTests.save_step()
		"continue_check":
			DebugTests.continue_check()
		"sentinel_death":
			for t in G.director.triggers:
				t.fired = true
			P.global_position = Vector3(34, 0, -26)
			P.yaw = 0.0
			P.pitch = 0.1
			var s = G.enemies.spawn("sentinel", Vector3(34, 3.0, -31))
			s.fire_cd = 1e9
			await _wait(1.0)
			s.take_damage(9999, Vector3.FORWARD, "slash")
			while is_instance_valid(s) and not s.exploded:
				await get_tree().process_frame
			if G.debug.has("boomshot"):
				await _wait(float(G.debug.get("boomdelay", 0.25)))
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(String(G.debug.boomshot))
				print("[sentinel_death] shot saved")
			await _wait(4.0)
			print("[sentinel_death] exploded=%s in_list=%s debris_left=%d" % [s.exploded if is_instance_valid(s) else "freed", G.enemies.list.has(s), G.fx.debris_list.size()])
		"cloak":
			for t in G.director.triggers:
				t.fired = true
			P.global_position = Vector3(34, 0, -108)
			P.yaw = 0.0
			var k = G.enemies.spawn("stalker", Vector3(34.5, 0, -111.5))
			k.set_state("recover")
			k.state_t = -1e9
			k.facing = PI
			k.set_cloak(G.debug.get("visible", "0") == "0")
			if G.debug.has("scanmode"):
				P.scan_mode = true


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _kill(enc_name: String) -> String:
	var enc = G.director.encounters[enc_name]
	var n := 0
	for e in G.enemies.list.duplicate():
		if e.encounter == enc and e.alive and not e.dormant:
			e.take_damage(9999, Vector3.FORWARD, "slash")
			n += 1
	return "%s wave=%d state=%s killed=%d" % [enc_name, enc.wave, enc.state, n]


## Headless end-to-end check of every scripted beat and encounter.
func _flow_test() -> void:
	var P = G.player
	var D = G.director
	var L = G.level
	var log := func(m): print("[flow] ", m)
	P.global_position = Vector3(0, 0, -21); await _wait(6.0)
	log.call("spine scare fired: %s, scurry crawlers: %d" % [D.triggers[0].fired, G.enemies.list.size()])
	P.global_position = Vector3(9, 0, -38.5); await _wait(3.0)
	log.call("junction: d2 locked=%s enemies=%s" % [L.doors.d2.locked, G.enemies.list.map(func(e): return e.kind + ":" + e.state)])
	log.call(_kill("junction")); await _wait(3.0)
	log.call("junction state=%s d2 locked=%s" % [D.encounters.junction.state, L.doors.d2.locked])
	P.global_position = Vector3(34, 0, -36); await _wait(5.0)
	log.call("atrium: d3 locked=%s sentinels=%s" % [L.doors.d3.locked, G.enemies.list.filter(func(e): return e.kind == "sentinel").map(func(e): return e.state)])
	log.call(_kill("atrium")); await _wait(3.0)
	log.call("atrium state=%s d3 locked=%s leviathan=%s" % [D.encounters.atrium.state, L.doors.d3.locked, L.leviathan.visible])
	P.global_position = Vector3(34, 0, -82.5); await _wait(1.0)
	log.call("funnel apparition: %s" % [G.enemies.list.filter(func(e): return e.kind == "stalker").size()])
	P.global_position = Vector3(34, 0, -106); await _wait(10.0)
	log.call("arena: d4 locked=%s enemies=%s" % [L.doors.d4.locked, G.enemies.list.filter(func(e): return e.alive and not e.dormant).map(func(e): return e.kind + ":" + e.state + "@%.1f" % e.global_position.y)])
	log.call(_kill("arena")); await _wait(9.0)
	log.call(_kill("arena")); await _wait(9.0)
	var st = G.enemies.list.filter(func(e): return e.kind == "stalker" and e.alive)
	log.call("stalker present=%d cloaked=%s" % [st.size(), st[0].cloaked if st.size() else "-"])
	if st.size():
		st[0].take_damage(130, Vector3.FORWARD, "heavy")
		log.call("stalker hp=%d enraged=%s" % [st[0].hp, st[0].enraged])
	await _wait(2.5); log.call(_kill("arena")); await _wait(2.5); log.call(_kill("arena")); await _wait(7.0)
	log.call("arena state=%s d5 locked=%s" % [D.encounters.arena.state, L.doors.d5.locked])
	P.global_position = Vector3(34, 0.3, -141.5); await _wait(10.0)
	log.call("lift: now in sector=%s state=%s s1_done=%s" % [G.level.sector_id, G.state, G.progress.flags.has("s1_done")])
	get_tree().quit()
