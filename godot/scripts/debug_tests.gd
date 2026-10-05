class_name DebugTests
extends RefCounted
## Automated scenario checks driven from the command line (--scenario=name). Headless-friendly.

static func wait(t: float) -> void:
	await G.main.get_tree().create_timer(t).timeout


static func say(m: String) -> void:
	print("[test] ", m)


static func kill_enc(name: String) -> String:
	var enc = G.director.encounters.get(name)
	if enc == null:
		return name + ": (no encounter)"
	var n := 0
	for e in G.enemies.list.duplicate():
		if e.encounter == enc and e.alive and not e.dormant:
			e.take_damage(99999, Vector3.FORWARD, "slash")
			if e.alive:
				e.die(Vector3.FORWARD)
			n += 1
	return "%s wave=%d state=%s killed=%d" % [name, enc.wave, enc.state, n]


static func states() -> String:
	return str(G.enemies.list.filter(func(e): return e.alive).map(func(e): return "%s:%s" % [e.kind, e.state]))


static func clear_encounter(name: String, max_rounds := 8) -> void:
	for i in max_rounds:
		var enc = G.director.encounters.get(name)
		if enc == null or enc.state == "done":
			return
		say(kill_enc(name))
		await wait(4.0)


static func grapple_to(from, yaw: float, pitch: float, settle := 1.8) -> String:
	var P = G.player
	if from != null:
		P.global_position = from
	P.yaw = yaw
	P.pitch = pitch
	await wait(0.3)
	P.grapple_candidate = P._find_grapple_target()
	var c = P.grapple_candidate
	if c == null:
		return "no grapple target from %s" % from
	P.fire_grapple()
	await wait(settle)
	return "grappled toward %s -> now at %s" % [c.pos, P.global_position.snapped(Vector3.ONE * 0.1)]


static func s2_flow() -> void:
	var P = G.player
	P.invuln = 1e9
	var F: Dictionary = G.progress.flags
	P.global_position = Vector3(0, 0, -55); await wait(3.0)
	say("market: " + states())
	await clear_encounter("market")
	say("market flag=%s" % F.has("s2_market"))
	P.global_position = Vector3(0, 0, -120); await wait(5.0)
	say("station: " + states())
	await clear_encounter("station")
	P.global_position = Vector3(0, 0, -155); await wait(3.0)
	P.global_position = Vector3(0, 0, -192); await wait(6.0)
	var b = G.enemies.list.filter(func(e): return e.kind == "matriarch")
	say("nest: matriarch=%d d_nest locked=%s" % [b.size(), G.level.doors.nest.locked])
	if b.size():
		var seen := {}
		for i in 30:
			seen[b[0].state] = true
			await wait(0.5)
		say("matriarch states seen: %s hp=%d" % [seen.keys(), b[0].hp])
		b[0].take_damage(99999, Vector3.FORWARD, "slash")
	await clear_encounter("nest")
	await wait(4.0)
	say("nest state=%s boss flag=%s items=%d" % [G.director.encounters.nest.state, G.progress.bosses.has("matriarch"), G.level.items.size()])
	P.global_position = Vector3(0, 0.2, -204.3); await wait(1.0)
	say("has grapple: %s" % G.has_ability("grapple"))
	# chain-grapple across the Gap
	say(await grapple_to(Vector3(30.5, 0, -60), -PI / 2, 0.42, 0.75))
	var eye: Vector3 = P.eye_pos()
	for gp in G.level.grapple_points:
		var to: Vector3 = gp.pos - eye
		var ang := acos(clamp(P.forward().dot(to.normalized()), -1.0, 1.0))
		say("  gp %s d=%.1f ang=%.2f los=%s" % [gp.pos, to.length(), ang, G.level.line_of_sight(eye, gp.pos - to.normalized() * 0.6)])
	say(await grapple_to(null, -PI / 2, -0.35, 2.0))
	say("after gap: %s on_ground=%s" % [P.global_position.snapped(Vector3.ONE * 0.1), P.on_ground])
	say("deaths=%d hp=%d" % [G.stats.deaths, P.hp])
	G.main.get_tree().quit()


static func s3_flow() -> void:
	var P = G.player
	P.invuln = 1e9
	var F: Dictionary = G.progress.flags
	P.global_position = Vector3(0, 0, -30); await wait(2.0)
	P.global_position = Vector3(0, 0.3, -48); await wait(3.0)
	say("smelting: " + states())
	await clear_encounter("smelting")
	say("smelting flag=%s" % F.has("s3_smelting"))
	# lava: stand in it briefly without invulnerability
	P.invuln = 0.0
	var hp0: float = P.hp
	P.global_position = Vector3(-5, 0, -43); await wait(1.0)
	say("lava: hp %d -> %d pos=%s" % [hp0, P.hp, P.global_position.snapped(Vector3.ONE * 0.1)])
	P.hp = P.max_hp
	# crusher: stand under one through a full cycle
	hp0 = P.hp
	P.global_position = Vector3(0, 0, -91); await wait(3.5)
	say("crusher: hp %d -> %d pos=%s" % [hp0, P.hp, P.global_position.snapped(Vector3.ONE * 0.1)])
	P.invuln = 1e9
	P.hp = P.max_hp
	P.global_position = Vector3(0, 0, -124); await wait(2.0)
	say("coolant zone=%s saved=%s" % [G.director.zone, G.progress.get("save_pos")])
	P.global_position = Vector3(0, 0, -145); await wait(5.0)
	var b = G.enemies.list.filter(func(e): return e.kind == "warden")
	say("crucible: warden=%d door locked=%s gps=%d" % [b.size(), G.level.doors.arena.locked, G.level.grapple_points.size()])
	if b.size():
		var w = b[0]
		var seen := {}
		for i in 24:
			seen[w.state] = true
			await wait(0.5)
		say("warden states (shielded): %s hp=%d shield=%s" % [seen.keys(), w.hp, w.shield_up])
		var hp1: float = w.hp
		w.take_damage(50, Vector3.FORWARD, "slash")
		say("slash vs shield: hp %d -> %d" % [hp1, w.hp])
		for gp in G.level.grapple_points.duplicate():
			if gp.has("on_pull"):
				gp.on_pull.call()
		await wait(1.0)
		say("after gens: shield=%s gens=%s" % [w.shield_up, w.gens.map(func(g): return g.alive)])
		seen = {}
		for i in 24:
			seen[w.state] = true
			await wait(0.5)
		say("warden states (phase 2): %s hp=%d" % [seen.keys(), w.hp])
		w.take_damage(99999, Vector3.FORWARD, "slash")
	await clear_encounter("warden")
	await wait(6.0)
	say("warden enc=%s boss flag=%s items=%d" % [G.director.encounters.warden.state, G.progress.bosses.has("warden"), G.level.items.size()])
	P.global_position = Vector3(0, 0.2, -162.3); await wait(1.0)
	say("has phase: %s door locked=%s" % [G.has_ability("phase"), G.level.doors.arena.locked])
	P.global_position = Vector3(0, 0, -124); await wait(2.0)
	say("return ambush: " + states())
	say("deaths=%d hp=%d" % [G.stats.deaths, P.hp])
	G.main.get_tree().quit()


static func s4_flow() -> void:
	var P = G.player
	P.invuln = 1e9
	var F: Dictionary = G.progress.flags
	P.global_position = Vector3(0, 0, -30); await wait(2.0)
	P.global_position = Vector3(0, 0, -40); await wait(4.0)
	say("stacks: " + states())
	await clear_encounter("stacks")
	say("stacks flag=%s" % F.has("s4_stacks"))
	P.global_position = Vector3(0, 0, -84); await wait(1.0)
	say("index door locked=%s" % G.level.doors.index.locked)
	for sc in G.level.scannables:
		if sc.title.begins_with("MONOLITH"):
			sc.scanned = true
			sc.on_scan.call()
	await wait(1.0)
	say("index flag=%s door locked=%s" % [F.has("s4_index"), G.level.doors.index.locked])
	P.global_position = Vector3(0, 0, -102); await wait(1.0)
	P.global_position = Vector3(0, 0, -111); await wait(4.0)
	say("cold: " + states())
	for e in G.enemies.list.duplicate():
		if e.alive: e.die(Vector3.FORWARD)
	P.global_position = Vector3(0, 0, -144); await wait(1.0)
	P.global_position = Vector3(0, 0, -150); await wait(6.0)
	var b = G.enemies.list.filter(func(e): return e.kind == "archivist")
	say("hall: archivist=%d door locked=%s" % [b.size(), G.level.doors.hall.locked])
	if b.size():
		var w = b[0]
		var seen := {}
		for i in 50:
			seen[w.state] = true
			if w.state == "clones_cast" and not seen.has("_scan"):
				seen["_scan"] = true
				P.scan_mode = true
				await wait(0.3)
				say("decoys=%d decoy param=%s" % [w.decoys.size(), w.decoys[0].mat.get_shader_parameter("decoy") if w.decoys.size() else "-"])
				P.scan_mode = false
			await wait(0.5)
		say("archivist states: %s hp=%d walls=%d" % [seen.keys(), w.hp, w.walls.size()])
		var hp1: float = w.hp
		w.grappled(P.global_position)
		say("grappled -> state=%s" % w.state)
		w._split(); w.set_state("clones")
		w.take_damage(40, Vector3.FORWARD, "slash")
		say("hit during clones: hp %d -> %d decoys=%d state=%s" % [hp1, w.hp, w.decoys.size(), w.state])
		w.take_damage(450, Vector3.FORWARD, "slash")
		say("phase=%d" % w.phase)
		await wait(6.0)
		say("phase2 enemies: " + states())
		w.take_damage(99999, Vector3.FORWARD, "slash")
	await clear_encounter("hall")
	await wait(5.0)
	say("hall enc=%s boss flag=%s" % [G.director.encounters.hall.state, G.progress.bosses.has("archivist")])
	P.global_position = Vector3(0, 0.2, -162.3); await wait(1.0)
	say("has leap: %s door locked=%s" % [G.has_ability("leap"), G.level.doors.hall.locked])
	say("deaths=%d hp=%d" % [G.stats.deaths, P.hp])
	G.main.get_tree().quit()


static func grapple_at(target: Vector3, settle := 1.8) -> String:
	var P = G.player
	var d: Vector3 = target - P.eye_pos()
	return await grapple_to(null, G.yaw_to(d.x, d.z), atan2(d.y, Vector2(d.x, d.z).length()), settle)


static func s5_flow() -> void:
	var P = G.player
	P.invuln = 1e9
	var F: Dictionary = G.progress.flags
	P.global_position = Vector3(0, 0, -30); await wait(1.0)
	P.global_position = Vector3(0, 0, -37); await wait(3.0)
	say("gut: " + states())
	await clear_encounter("gut")
	say("gut flag=%s" % F.has("s5_gut"))
	P.global_position = Vector3(0, 0, -60); await wait(1.0)
	P.global_position = Vector3(0, -24, -80); await wait(3.5)
	say("throat floor: zone=%s %s" % [G.director.zone, states()])
	for e in G.enemies.list.duplicate():
		if e.alive: e.die(Vector3.FORWARD)
	P.global_position = Vector3(0, -24, -100); await wait(1.0)
	P.global_position = Vector3(0, -24, -116); await wait(5.0)
	var hs = G.enemies.list.filter(func(e): return e.kind == "heart")
	say("heart: n=%d door locked=%s %s" % [hs.size(), G.level.doors.heart.locked, states()])
	if hs.size():
		var h = hs[0]
		var seen := {}
		for i in 30:
			for e in G.enemies.list:
				if e.kind == "tentacle" and e.alive:
					seen[e.state] = true
			await wait(0.5)
		say("tentacle states: %s heart state=%s" % [seen.keys(), h.state])
		var hp0: float = h.hp
		h.take_damage(100, Vector3.FORWARD, "slash")
		say("guarded hit: hp %d -> %d" % [hp0, h.hp])
		for cyc in 3:
			for e in G.enemies.list.duplicate():
				if e.kind == "tentacle" and e.alive:
					e.set_state("embedded")
					e.take_damage(999, Vector3.FORWARD, "slash")
			await wait(2.5)
			say("cycle %d: heart state=%s y=%.1f" % [cyc, h.state, h.center().y])
			await wait(1.0)
			h.take_damage(210, Vector3.FORWARD, "slash")
			say("  after hit: hp=%d state=%s alive=%s" % [h.hp, h.state, h.alive])
			if not h.alive:
				break
			await wait(5.0)
			say("  regrown: " + states())
	await wait(6.0)
	say("avatar wave: " + states())
	var av = G.enemies.list.filter(func(e): return e.kind == "avatar")
	if av.size():
		var a = av[0]
		var seen := {}
		for i in 16:
			seen[a.state] = true
			await wait(0.5)
		say("avatar states: %s hp=%d" % [seen.keys(), a.hp])
		a.take_damage(300, Vector3.FORWARD, "slash")
		await wait(0.5)
		say("avatar enraged=%s %s" % [a.enraged, states()])
	await clear_encounter("heart")
	await wait(4.0)
	say("heart flag=%s escape=%s t=%.1f timer_vis=%s" % [G.progress.bosses.has("heart"), G.level.escape, G.level.escape_t, G.hud.timer_label.visible])
	# climb out of the throat
	P.global_position = Vector3(0, -24, -88); P.velocity = Vector3.ZERO; await wait(1.0)
	for a in [Vector3(6.0, -13.0, -86), Vector3(-9, -8.0, -77), Vector3(9, -2.0, -71), Vector3(0, 3.5, -61.0)]:
		say(await grapple_at(a, 2.2))
	say("top of throat: %s on_ground=%s" % [P.global_position.snapped(Vector3.ONE * 0.1), P.on_ground])
	P.global_position = Vector3(0, 0, -4.5); await wait(2.0)
	say("ending: state=%s finished=%s complete=%s" % [G.state, G.level.finished, F.has("game_complete")])
	await wait(7.0)
	say("end title: %s" % G.hud.end_title.text)
	say("deaths=%d" % G.stats.deaths)
	G.main.get_tree().quit()


static func save_step() -> void:
	var P = G.player
	P.invuln = 1e9
	await wait(1.0)
	P.global_position = Vector3(5, 0, -11); await wait(1.0)
	say("saved: has_save=%s sector=%s abilities=%s" % [G.has_save(), G.progress.sector, G.progress.abilities.keys()])
	G.main.get_tree().quit()


static func continue_check() -> void:
	await wait(2.0)
	say("continued: sector=%s pos=%s abilities=%s max_hp=%d" % [G.level.sector_id, G.player.global_position.snapped(Vector3.ONE * 0.1), G.progress.abilities.keys(), G.player.max_hp])
	G.main.get_tree().quit()
