class_name EnemyManager
extends Node3D
## Spawns and updates enemies, owns plasma bolts (incl. deflection back at their owner).

var list: Array = []
var bolts: Array = []
var glow_shader := preload("res://shaders/glow_add.gdshader")


func spawn(kind: String, pos: Vector3, opts := {}) -> Enemy:
	var e: Enemy
	match kind:
		"crawler", "hound", "mite":
			e = Crawler.new()
			if kind != "crawler" and not opts.has("variant"):
				opts["variant"] = kind
		"sentinel": e = Sentinel.new()
		"stalker": e = Stalker.new()
		"bulwark": e = Bulwark.new()
		"turret": e = Turret.new()
		"phantom": e = Phantom.new()
		"spore_pod": e = SporePod.new()
		_:
			e = Boss.make(kind)
	add_child(e)
	e.setup(self, pos, opts)
	if opts.has("encounter"):
		e.encounter = opts.encounter
	list.append(e)
	return e


func _glow(c: Color, size: float) -> MeshInstance3D:
	var mi := Creatures.glow_quad(c, size)
	add_child(mi)
	return mi


func spawn_bolt(pos: Vector3, vel: Vector3, owner, o := {}) -> void:
	var col: Color = o.get("color", Color(4, 1.2, 0.5))
	var outer := _glow(col, o.get("size", 0.8))
	var core := Creatures.glow_quad(Color(5, 4, 3), 0.375)
	outer.add_child(core)
	outer.global_position = pos
	var light := OmniLight3D.new()
	light.light_color = Color(col.r, col.g, col.b).clamp() if o.has("color") else Color(1, 0.45, 0.2)
	light.light_energy = 1.5
	light.omni_range = 4.0
	outer.add_child(light)
	bolts.append({"pos": pos, "vel": vel, "owner": owner, "reflected": false, "dead": false, "node": outer, "light": light, "life": o.get("life", 5.0), "trail_t": 0.0,
		"homing": o.get("homing", 0.0), "dmg": o.get("dmg", 15.0), "gravity": o.get("gravity", 0.0), "color": col, "on_land": o.get("on_land", Callable())})


func reflect_bolt(b: Dictionary) -> void:
	b.reflected = true
	var tgt: Vector3 = b.owner.center() if (is_instance_valid(b.owner) and b.owner.alive) else b.pos - b.vel
	b.vel = (tgt - b.pos).normalized() * 24.0
	b.node.material_override.set_shader_parameter("color", Color(0.6, 3, 4))
	b.light.light_color = Color(0.4, 0.9, 1.0)
	b.life = 3.0


func clear_all() -> void:
	for e in list:
		e.dispose()
	list.clear()
	for b in bolts:
		b.node.queue_free()
	bolts.clear()


func threat_level(pos: Vector3) -> float:
	var t := 0.0
	for e in list:
		if not e.alive or e.dormant:
			continue
		t = max(t, 1.0 - clamp((e.global_position.distance_to(pos) - 3.0) / 25.0, 0.0, 1.0))
	return t


func on_death(e) -> void:
	if G.player.lock_target == e:
		G.player.lock_target = null
	if e.encounter != null and e.encounter.has_method("on_death"):
		e.encounter.on_death(e)


func remove_encounter(enc) -> void:
	for e in list:
		if e.encounter == enc:
			e.dispose()
	list = list.filter(func(e): return e.encounter != enc)
	for b in bolts:
		b.dead = true


func update(dt: float, ws: float) -> void:
	for e in list:
		e.update(dt, ws)
	for i in range(list.size() - 1, -1, -1):
		if list[i].remove_me:
			list[i].dispose()
			list.remove_at(i)
	var P = G.player
	var eye: Vector3 = P.eye_pos()
	for i in range(bolts.size() - 1, -1, -1):
		var b: Dictionary = bolts[i]
		if not b.dead:
			var prev: Vector3 = b.pos
			if b.homing > 0.0 and not b.reflected:
				var want: Vector3 = (eye - Vector3(0, 0.3, 0) - b.pos).normalized() * b.vel.length()
				b.vel += (want - b.vel) * min(1.0, b.homing * dt)
			b.vel.y -= b.gravity * dt
			b.pos += b.vel * dt
			b.life -= dt
			b.node.global_position = b.pos
			b.trail_t -= dt
			if b.trail_t <= 0.0:
				b.trail_t = 0.02
				G.fx.emit(b.pos, Vector3.ZERO, Color(0.5, 2, 3) if b.reflected else b.color * 0.75, 0.25, 0.2)
			if not b.reflected:
				if b.pos.distance_to(eye - Vector3(0, 0.35, 0)) < 0.75:
					var r: String = P.receive_hit(b.dmg, b.pos, "bolt")
					if r == "parry":
						reflect_bolt(b)
						G.hud.message("DEFLECT", 0.6)
						continue
					if r == "evaded":
						continue
					b.dead = true
					G.fx.burst(b.pos, {"count": 16, "color": Color(3, 1, 0.4), "speed": 5.0, "life": 0.4, "size": 0.1})
			else:
				for e in list:
					if not e.alive or e.dormant:
						continue
					if e.center().distance_to(b.pos) < e.radius + 0.45:
						e.take_damage(30, b.vel.normalized(), "reflect")
						G.audio.play3d("explosion", b.pos, 2.0)
						G.fx.burst(b.pos, {"count": 30, "color": Color(0.5, 2.5, 3.5), "speed": 8.0, "life": 0.5, "size": 0.12})
						G.fx.light_flash(b.pos, Color(0.5, 0.94, 1.0), 8.0, 0.2)
						G.hit_stop(0.08)
						b.dead = true
						break
			if not b.dead and not G.level.line_of_sight(prev, b.pos):
				b.dead = true
				if b.on_land.is_valid():
					b.on_land.call(prev)
				G.fx.burst(prev, {"count": 12, "color": Color(3, 1, 0.4), "speed": 4.0, "life": 0.35, "size": 0.08})
				G.audio.play3d("fizzle", prev)
			if b.life <= 0.0:
				b.dead = true
		if b.dead:
			b.node.queue_free()
			bolts.remove_at(i)
