class_name Director
extends Node
## Generic pacing engine: timed events, box triggers, wave encounters, zone mood, checkpoints.
## Each sector supplies its script via Level.script(director).

## Sequential waves; each must be cleared before the next. Reset cancels pending spawns.
class Encounter:
	var dir
	var id: String
	var def: Dictionary
	var state := "idle"
	var run := 0
	var wave := -1
	var pending := 0
	var waiting := false
	var data := {}

	func _init(p_dir, p_id: String, p_def: Dictionary) -> void:
		dir = p_dir; id = p_id; def = p_def
		if def.has("setup"):
			def.setup.call(self)

	func spawn(kind: String, pos: Vector3, opts := {}):
		opts["encounter"] = self
		return G.enemies.spawn(kind, pos, opts)

	func spawn_later(t: float, kind: String, pos: Vector3, opts := {}, after := Callable()) -> void:
		pending += 1
		var r := run
		dir.after(t, func():
			if r != run:
				return
			pending -= 1
			var e = spawn(kind, pos, opts)
			if after.is_valid():
				after.call(e))

	func later(t: float, fn: Callable) -> void:
		var r := run
		dir.after(t, func():
			if r == run:
				fn.call())

	func alive() -> int:
		var n := 0
		for e in G.enemies.list:
			if e.encounter == self and e.alive and not e.dormant:
				n += 1
		return n

	func begin() -> void:
		if state != "idle":
			return
		state = "active"
		wave = -1
		if def.has("start"):
			def.start.call(self)
		next_wave(def.get("first_delay", 0.0))

	func next_wave(delay: float) -> void:
		wave += 1
		if wave >= def.waves.size():
			finish()
			return
		pending += 1
		later(delay, func():
			pending -= 1
			def.waves[wave].call(self))

	func update() -> void:
		if state != "active":
			return
		if pending == 0 and alive() == 0 and not waiting:
			waiting = true
			var gaps: Array = def.get("gaps", [])
			var gap: float = gaps[wave] if wave < gaps.size() else 2.0
			later(0.01, func():
				waiting = false
				next_wave(gap))

	func on_death(_e) -> void:
		pass

	func on_enrage(_e) -> void:
		if def.has("enrage"):
			def.enrage.call(self)

	func finish() -> void:
		state = "done"
		if def.has("clear"):
			def.clear.call(self)

	func reset() -> void:
		if state == "done":
			return
		run += 1
		pending = 0
		waiting = false
		G.enemies.remove_encounter(self)
		state = "idle"
		if def.has("reset"):
			def.reset.call(self)
		if def.has("setup"):
			def.setup.call(self)


var events: Array = []
var triggers: Array = []
var encounters := {}
var zone := ""
var visited := {}
var checkpoint := {"pos": Vector3(0, 0, -2.5), "yaw": 0.0}
var time := 0.0


func after(t: float, fn: Callable) -> void:
	events.append({"t": time + t, "fn": fn})


func trigger(box: Array, fn: Callable, id := "") -> Dictionary:
	var t := {"box": box, "fn": fn, "fired": false, "id": id}
	triggers.append(t)
	return t


## Clear everything sector-specific before a new sector loads.
func reset() -> void:
	events.clear()
	triggers.clear()
	encounters.clear()
	zone = ""
	visited = {}


func setup() -> void:
	G.level.script(self)


## Called once the player is placed in a freshly loaded sector.
func enter(entry: String, first_time: bool) -> void:
	G.hud.fade_to(0.0, 2.5)
	G.controls_enabled = false
	after(0.8, func(): G.controls_enabled = true)
	var z = G.level.zone_at(G.player.global_position)
	if z != null:
		zone = z.id
		visited[z.id] = true
		_apply_zone(z, true)
		if z.has("title") and not (entry == "start" and G.level.sector_id == "s1"):
			after(1.2, func(): G.hud.area(z.title, z.sub))
	G.level.on_enter(self, entry, first_time)


func on_death() -> void:
	G.stats.deaths += 1
	if G.debug.size():
		print("[slashboy] player died at ", G.player.global_position.snapped(Vector3.ONE * 0.1))
	G.controls_enabled = false
	G.hud.set_screen("death", true)
	G.audio.set_combat(false)
	G.audio.set_boss_music(false)
	G.audio.duck(0.2, 0.3)
	after(3.2, func(): respawn(true))


func respawn(from_death: bool) -> void:
	for enc in encounters.values():
		if enc.state == "active":
			enc.reset()
			for t in triggers:
				if t.id != "" and t.id.begins_with(enc.id):
					t.fired = false
	G.player.respawn(checkpoint.pos, checkpoint.yaw)
	G.hud.boss(null)
	if from_death:
		G.hud.set_screen("death", false)
		G.main.fade = 1.0
		after(0.2, func(): G.hud.fade_to(0.0, 1.5))
		G.audio.duck(1.0, 1.0)
		G.controls_enabled = true


func _apply_zone(z: Dictionary, instant := false) -> void:
	G.audio.set_zone(z.amb)
	G.level.moon_target = z.get("moon", 0.0)
	if z.has("mood"):
		var m: Array = z.mood
		G.main.set_mood(m[0], m[1], m[2], m[3], instant)


func update(dt: float) -> void:
	time += dt
	var i := 0
	while i < events.size():
		if time >= events[i].t:
			var e = events[i]
			events.remove_at(i)
			e.fn.call()
		else:
			i += 1
	if G.state != "playing":
		return
	var P = G.player
	var p: Vector3 = P.global_position
	for t in triggers:
		if t.fired:
			continue
		var b: Array = t.box
		if p.x >= b[0] and p.x <= b[2] and p.z >= b[1] and p.z <= b[3] and not P.dead:
			if b.size() > 4 and (p.y < b[4] or p.y > b[5]):
				continue
			t.fired = true
			t.fn.call()
	for enc in encounters.values():
		enc.update()
	var z = G.level.zone_at(p)
	if z != null and z.id != zone:
		zone = z.id
		_apply_zone(z)
		if not visited.has(z.id):
			visited[z.id] = true
			if z.has("title"):
				G.hud.area(z.title, z.sub)
			if z.has("checkpoint"):
				checkpoint = z.checkpoint
	var threat: float = G.enemies.threat_level(p)
	if not G.level.has_method("custom_tension") or not G.level.custom_tension(zone):
		G.audio.set_tension(threat * 0.9)
	G.level.sector_update(self, dt)


## Final ending (called by the last sector after the escape).
func game_complete(text: String) -> void:
	G.controls_enabled = false
	G.state = "ending"
	G.audio.set_combat(false)
	G.audio.set_boss_music(false)
	after(1.0, func(): G.hud.fade_to(1.0, 4.0))
	after(5.5, func():
		var secs := int(G.elapsed())
		var items: int = G.progress.tanks + G.progress.shards
		G.hud.end_title.text = "  ".join("KUROGANE-9 // SILENCE RESTORED".split(""))
		G.hud.end_body.text = text
		G.hud.end_stats.text = "TIME %d:%02d:%02d  ·  DEATHS %d  ·  ITEMS %d/%d  ·  SCANS %d" % [secs / 3600, (secs / 60) % 60, secs % 60, G.stats.deaths, items, Sectors.TOTAL_ITEMS, G.progress.scans.size() + G.scanned_types.size()]
		G.hud.set_screen("end", true)
		G.audio.stinger("clear")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
