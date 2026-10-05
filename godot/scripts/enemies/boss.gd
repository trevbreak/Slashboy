class_name Boss
extends Enemy
## Shared boss plumbing: damage multiplier, phases, ground shockwaves.

var boss_name := ""
var phase := 1
var dmg_mult := 1.0
var waves: Array = []        # expanding ground shockwaves


static func make(kind: String) -> Enemy:
	match kind:
		"matriarch": return Matriarch.new()
		"warden": return Warden.new()
		"archivist": return Archivist.new()
		"heart": return BloomHeart.new()
		"tentacle": return Tentacle.new()
	push_error("unknown enemy " + kind)
	return Crawler.new()


func take_damage(dmg: float, dir: Vector3, dmg_kind: String) -> void:
	super.take_damage(dmg * dmg_mult, dir, dmg_kind)


## Ring of force expanding along the floor: jump to clear it.
func shockwave(c: Vector3, max_r: float, dur: float, dmg: float, col := Color(1.5, 1.0, 0.6)) -> void:
	waves.append({"c": c, "r": 0.5, "max": max_r, "speed": max_r / dur, "dmg": dmg, "hit": false})
	G.fx.ring(c + Vector3(0, 0.15, 0), col, max_r, dur)
	G.fx.burst(c, {"count": 40, "color": Color(0.5, 0.45, 0.4), "speed": 6.0, "life": 0.8, "size": 0.3})
	G.player.add_shake(0.5)


func update_waves(dt: float) -> void:
	var P = G.player
	for i in range(waves.size() - 1, -1, -1):
		var w: Dictionary = waves[i]
		w.r += w.speed * dt
		var p: Vector3 = P.global_position
		var d := Vector2(p.x - w.c.x, p.z - w.c.z).length()
		if not w.hit and abs(d - w.r) < 0.9 and p.y - w.c.y < 0.6:
			w.hit = true
			P.receive_hit(w.dmg, w.c, "shock")
		if w.r > w.max:
			waves.remove_at(i)


func roar(snd := "matriarch_roar", vol := 6.0) -> void:
	G.audio.play3d(snd, center(), vol)
	G.player.add_shake(0.35)
