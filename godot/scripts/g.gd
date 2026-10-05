extends Node
## Global game state, persistent progression and save data (autoload "G").

const SAVE_PATH := "user://slashboy_save.json"
const ABILITIES := {
	"grapple": {"name": "KUSARI GRAPPLE", "key": "F", "text": "A monofilament chain-kunai.\n[F] at an amber anchor to zip to it. [F] at an enemy to yank it off balance.\nShield generators and loose armour can be torn away."},
	"phase": {"name": "PHASE STEP", "key": "SHIFT", "text": "Your dash briefly unthreads you from local space.\nDash through red phase barriers and energy beams. Phantom strikes deal double damage."},
	"leap": {"name": "KAGE LEAP", "key": "SPACE x2", "text": "A second jump off nothing but intent.\nPress jump again in mid-air. Reach ledges and anchors far above."},
}

var main: Node
var level: Node
var player: Node
var enemies: Node
var fx: Node
var hud: Node
var audio: Node
var director: Node
var camera: Camera3D

var state := "title"            # title, playing, paused, loading, ending
var controls_enabled := false
var flags := {}
var scanned_types := {}
var hitstop := 0.0
var world_scale := 1.0
var player_scale := 1.0
var quality := "HIGH"
var stats := {"deaths": 0, "start_ms": 0}
var debug := {}
var progress := {}


func _ready() -> void:
	new_progress()


func new_progress() -> void:
	progress = {
		"sector": "s1", "entry": "start", "save_pos": null, "save_yaw": 0.0,
		"abilities": {}, "tanks": 0, "shards": 0, "items": {}, "scans": {}, "bosses": {},
		"flags": {}, "visited": {}, "time": 0.0, "deaths": 0,
	}
	scanned_types = {}


func has_ability(n: String) -> bool:
	return progress.abilities.has(n)


func hit_stop(t: float) -> void:
	hitstop = max(hitstop, t)


func playing() -> bool:
	return state == "playing"


static func yaw_to(dx: float, dz: float) -> float:
	return atan2(-dx, -dz)


static func flat_forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


# ------------------------------------------------------------------ items
func collect_item(kind: String, id: String) -> void:
	progress.items[id] = true
	match kind:
		"tank":
			progress.tanks += 1
			player.max_hp = 100.0 + 25.0 * progress.tanks
			player.hp = player.max_hp
			audio.stinger("discovery")
			hud.message("ENERGY TANK ACQUIRED  ·  MAX ENERGY %d" % int(player.max_hp), 3.5)
		"shard":
			progress.shards += 1
			player.max_ki = 100.0 + 15.0 * progress.shards
			player.ki = player.max_ki
			audio.stinger("discovery")
			hud.message("KI SHARD ACQUIRED  ·  MAX KI %d" % int(player.max_ki), 3.5)
		_:
			progress.abilities[kind] = true
			audio.stinger("clear")
			audio.play("leviathan_horn", -10.0)
			hud.ability_get(kind)
	fx.cyan_burst(player.global_position + Vector3(0, 1.2, 0), 60)
	fx.ring(player.global_position + Vector3(0, 0.1, 0), Color(0.5, 2.0, 3.0), 6.0, 0.8)


func item_count() -> Vector2i:
	return Vector2i(progress.items.size(), 0)


# ------------------------------------------------------------------ save / load
func save_at(sector: String, pos: Vector3, yaw: float) -> void:
	progress.sector = sector
	progress.save_pos = [pos.x, pos.y, pos.z]
	progress.save_yaw = yaw
	progress.time += (Time.get_ticks_msec() - stats.start_ms) / 1000.0
	stats.start_ms = Time.get_ticks_msec()
	progress.deaths = stats.deaths
	progress.scans_types = scanned_types.keys()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress, "  "))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	new_progress()
	for k in data:
		progress[k] = data[k]
	progress.tanks = int(progress.tanks)
	progress.shards = int(progress.shards)
	stats.deaths = int(progress.get("deaths", 0))
	for t in progress.get("scans_types", []):
		scanned_types[t] = true
	return true


func elapsed() -> float:
	return progress.time + (Time.get_ticks_msec() - stats.start_ms) / 1000.0
