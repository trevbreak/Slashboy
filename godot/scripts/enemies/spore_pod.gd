class_name SporePod
extends Enemy
## Bloom spore sac: swells when you come close, then bursts into a toxic cloud and a mite swarm.
## Cut it (or hit it from range) before it ripens.

var sac: MeshInstance3D
var swell := 0.0
var burst_done := false
var pulse := 0.0


func setup(p_mgr, pos: Vector3, opts: Dictionary) -> void:
	super.setup(p_mgr, pos, opts)
	kind = "spore_pod"
	max_hp = 20; hp = 20
	radius = 0.7; center_y = 0.7
	organic = true; drop_count = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	scan_info = {"title": "SPORE POD", "text": "A ripening Bloom sac. Senses warmth at five metres, then ruptures:\na toxic cloud and a brood of mites.\nCut it before it swells, or burst it from range with an Arc Wave."}
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new(); sh.radius = 0.6
	cs.shape = sh; cs.position.y = 0.7
	add_child(cs)
	var fl := Creatures.flesh(Color(0.9, 0.9, 0.2), 3.0, Color(0.6, 0.45, 0.3))
	flash_mats = [fl]
	rig = Node3D.new(); add_child(rig)
	sac = Creatures.add(rig, Creatures.organic(Creatures.sphere(0.6, 28, 16), 0.12, 3.0, randi() % 50), fl, Vector3(0, 0.7, 0), Vector3(1, 1.2, 1))
	for i in 5:
		var a := TAU * i / 5.0
		var root := CylinderMesh.new(); root.top_radius = 0.05; root.bottom_radius = 0.12; root.height = 0.9
		Creatures.add(rig, root, fl, Vector3(cos(a) * 0.5, 0.25, sin(a) * 0.5), Vector3.ONE, Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9))
	pulse = randf() * 6.0
	set_state("idle")


func on_die(_dir: Vector3) -> void:
	G.audio.play3d("spore", center(), -2.0, 1.3)
	G.fx.ichor(center(), Vector3.UP, 40)
	remove_me = true


func _burst() -> void:
	burst_done = true
	var c := center()
	G.audio.play3d("spore", c, 4.0)
	G.fx.burst(c, {"count": 80, "color": Color(0.9, 1.1, 0.25), "speed": 5.0, "life": 1.6, "size": 0.35})
	var p := global_position
	G.level.hazards.append({"box": [p.x - 2.5, p.y - 0.5, p.z - 2.5, p.x + 2.5, p.y + 3.0, p.z + 2.5], "dps": 14.0, "kind": "spore", "until": G.level.time + 4.0})
	for i in 3:
		var a := TAU * i / 3.0
		mgr.spawn("mite", p + Vector3(cos(a), 0.3, sin(a)) * 0.8, {"variant": "mite", "encounter": encounter})
	alive = false
	mgr.on_death(self)
	remove_me = true


func update(dt: float, _ws: float) -> void:
	update_flash(dt)
	if not alive:
		return
	pulse += dt
	var d: float = G.player.global_position.distance_to(global_position)
	if d < 5.0 or swell > 0.0:
		swell += dt / 1.1
		if swell >= 1.0 and not burst_done:
			_burst()
			return
	var k := 1.0 + sin(pulse * (2.0 + swell * 14.0)) * (0.04 + swell * 0.08) + swell * 0.45
	sac.scale = Vector3(k, k * 1.2, k)
	flash_mats[0].set_shader_parameter("vein_strength", 3.0 + swell * 8.0)
