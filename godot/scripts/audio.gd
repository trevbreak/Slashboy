class_name AudioManager
extends Node
## Plays the pre-rendered procedural sound library: pooled 3D one-shots routed through a
## room-reverb bus, zone ambience beds, tension layer, combat music and ambient scares.

const LIB_DIR := "res://assets/audio/"
const POOL_3D := 40
const POOL_2D := 14

# zone -> [bed volume dB, reverb room size, reverb wet, damping]
const ZONES := {
	"silent": [-80.0, 0.3, 0.1, 0.5],
	"bay": [-12.0, 0.45, 0.22, 0.5],
	"corridor": [-11.0, 0.35, 0.18, 0.6],
	"atrium": [-11.0, 0.95, 0.42, 0.25],
	"funnel": [-9.0, 0.45, 0.24, 0.5],
	"arena": [-11.0, 0.7, 0.32, 0.35],
	"final": [-12.0, 0.75, 0.34, 0.3],
	"undercity": [-9.0, 0.8, 0.3, 0.45],
	"subway": [-11.0, 0.6, 0.38, 0.4],
	"foundry": [-8.0, 0.85, 0.32, 0.5],
	"archives": [-9.0, 1.0, 0.5, 0.15],
	"heart": [-7.0, 0.7, 0.4, 0.6],
}
const PALETTE := {
	"bay": ["creak", "clank", "drip", "vent_rumble", "boom"],
	"corridor": ["creak", "clank", "drip", "vent_rumble", "buzz", "skitter", "taps"],
	"atrium": ["boom", "creak", "clank", "whale", "chime", "boom"],
	"funnel": ["drip", "whisper", "skitter", "creak", "breath", "taps"],
	"arena": ["drip", "creak", "vent_rumble", "whisper"],
	"final": ["chime", "boom", "creak"],
	"undercity": ["boom", "clank", "skitter", "drip", "creak", "whale"],
	"subway": ["drip", "drip", "skitter", "creak", "whisper", "taps"],
	"foundry": ["clank", "hydraulic", "boom", "creak", "sparks"],
	"archives": ["chime", "chime", "glitch", "creak", "whisper"],
	"heart": ["breath", "whisper", "skitter", "drip", "spore"],
}
const BEDS := {"bay": "amb_bay", "corridor": "amb_corridor", "atrium": "amb_atrium", "funnel": "amb_funnel", "arena": "amb_arena", "final": "amb_final",
	"undercity": "amb_undercity", "subway": "amb_corridor", "foundry": "amb_foundry", "archives": "amb_archives", "heart": "amb_heart"}

var lib := {}                 # base name -> Array[AudioStream]
var pool3d: Array[AudioStreamPlayer3D] = []
var pool2d: Array[AudioStreamPlayer] = []
var beds := {}                # zone -> AudioStreamPlayer
var tension_player: AudioStreamPlayer
var combat_player: AudioStreamPlayer
var boss_player: AudioStreamPlayer
var escape_player: AudioStreamPlayer
var boss_on := false
var zone := "silent"
var combat := false
var tension := 0.0
var ambient_t := 6.0
var pad_t := 4.0
var i3 := 0
var i2 := 0
var bus_world := 0
var bus_amb := 0
var bus_music := 0
var bus_verb := 0
var reverb: AudioEffectReverb
var lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	_setup_buses()
	_load_library()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "World"
		p.unit_size = 3.0
		p.max_distance = 120.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 1.0
		add_child(p)
		pool3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "World"
		add_child(p)
		pool2d.append(p)
	for z in BEDS:
		if not beds.has(BEDS[z]):
			beds[BEDS[z]] = _loop_player(BEDS[z], "Ambience")
	tension_player = _loop_player("tension", "Ambience")
	combat_player = _loop_player("music_combat", "Music")
	boss_player = _loop_player("music_boss", "Music") if lib.has("music_boss") else combat_player
	escape_player = _loop_player("music_escape", "Music") if lib.has("music_escape") else combat_player


func _setup_buses() -> void:
	var make := func(bus_name: String, send: String) -> int:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, send)
		return idx
	bus_verb = make.call("MusicVerb", "Master")
	bus_world = make.call("World", "Master")
	bus_amb = make.call("Ambience", "Master")
	bus_music = make.call("Music", "Master")
	reverb = AudioEffectReverb.new()
	reverb.room_size = 0.45
	reverb.damping = 0.5
	reverb.wet = 0.22
	reverb.dry = 1.0
	reverb.spread = 1.0
	reverb.predelay_msec = 30
	AudioServer.add_bus_effect(bus_world, reverb)
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 20000
	AudioServer.add_bus_effect(bus_world, lowpass)
	var big := AudioEffectReverb.new()
	big.room_size = 1.0
	big.damping = 0.2
	big.wet = 0.55
	big.dry = 0.7
	big.predelay_msec = 60
	AudioServer.add_bus_effect(bus_verb, big)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -14
	comp.ratio = 4
	AudioServer.add_bus_effect(0, comp)
	AudioServer.set_bus_volume_db(bus_music, -6)


func _load_library() -> void:
	var files: PackedStringArray
	if ResourceLoader.has_method("list_directory"):
		files = ResourceLoader.list_directory(LIB_DIR)
	else:
		files = DirAccess.get_files_at(LIB_DIR)
	for f in files:
		var name := f.replace(".import", "").replace(".remap", "")
		if not name.ends_with(".wav"):
			continue
		var stem := name.get_basename()
		var base := stem
		var us := stem.rfind("_")
		if us > 0 and stem.substr(us + 1).is_valid_int():
			base = stem.substr(0, us)
		var s = load(LIB_DIR + name)
		if s == null:
			continue
		if not lib.has(base):
			lib[base] = []
		if not s in lib[base]:
			lib[base].append(s)
		if stem != base:
			lib[stem] = [s]   # exact variant, e.g. "focus_1"



func _loop_player(stream_name: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -80
	var s: AudioStream = _pick(stream_name)
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	p.stream = s
	add_child(p)
	p.play()
	return p


func _pick(base: String) -> AudioStream:
	var arr: Array = lib.get(base, [])
	if arr.is_empty():
		push_warning("missing sound: " + base)
		return null
	return arr[randi() % arr.size()]


func has(base: String) -> bool:
	return lib.has(base)


# ------------------------------------------------------------------ playback
## Positional one-shot. Returns the player (e.g. to move it along a path).
func play3d(base: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, unit := 3.0) -> AudioStreamPlayer3D:
	var s := _pick(base)
	if s == null:
		return null
	var p := pool3d[i3]
	i3 = (i3 + 1) % POOL_3D
	p.stop()
	p.stream = s
	p.global_position = pos
	p.volume_db = vol_db
	p.unit_size = unit
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.play()
	return p


## Non-positional one-shot (player sounds, stingers, UI).
func play(base: String, vol_db := 0.0, pitch := 1.0, bus := "World") -> AudioStreamPlayer:
	var s := _pick(base)
	if s == null:
		return null
	var p := pool2d[i2]
	i2 = (i2 + 1) % POOL_2D
	p.stop()
	p.stream = s
	p.bus = bus
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()
	return p


func play_later(t: float, base: String, pos = null, vol_db := 0.0) -> void:
	get_tree().create_timer(t, false).timeout.connect(func():
		if pos == null:
			play(base, vol_db)
		else:
			play3d(base, pos, vol_db))


## A scuttling run across the ceiling: the sound source travels along a path.
func skitter_path(from: Vector3, to: Vector3, dur: float, vol_db := 2.0) -> void:
	var p := play3d("skitter_run", from, vol_db, 1.0, 4.0)
	if p:
		var tw := create_tween()
		tw.tween_property(p, "global_position", to, dur)


func stinger(kind: String) -> void:
	play("stinger_" + kind, -2.0, 1.0, "MusicVerb")


# ------------------------------------------------------------------ mood
func set_zone(z: String) -> void:
	if z == zone or not ZONES.has(z):
		return
	zone = z
	var cfg: Array = ZONES[z]
	for key in beds:
		var target: float = cfg[0] if key == BEDS.get(z, "amb_corridor") else -80.0
		var tw := create_tween()
		tw.tween_property(beds[key], "volume_db", target, 3.0).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(reverb, "room_size", cfg[1], 2.0)
	tw2.tween_property(reverb, "wet", cfg[2], 2.0)
	tw2.tween_property(reverb, "damping", cfg[3], 2.0)


func _bed_for(z: String) -> String:
	return z if beds.has(z) else "corridor"


func duck(amount: float, time := 0.5) -> void:
	var tw := create_tween()
	tw.tween_method(func(v): AudioServer.set_bus_volume_db(bus_amb, v), AudioServer.get_bus_volume_db(bus_amb), linear_to_db(max(amount, 0.0001)), time)


func set_tension(v: float) -> void:
	v = clamp(v, 0.0, 1.0)
	if abs(v - tension) < 0.01:
		return
	tension = v
	var db = -80.0 if v < 0.02 else lerp(-34.0, -14.0, v)
	create_tween().tween_property(tension_player, "volume_db", db, 1.2)


func set_combat(on: bool) -> void:
	if on == combat:
		return
	combat = on
	if on:
		combat_player.stop()
		combat_player.play()
		create_tween().tween_property(combat_player, "volume_db", -2.0, 0.6)
	else:
		create_tween().tween_property(combat_player, "volume_db", -80.0, 3.0)
		pad_t = 5.0


func set_boss_music(on: bool) -> void:
	if on == boss_on:
		return
	boss_on = on
	if on:
		set_combat(false)
		boss_player.stop()
		boss_player.play()
		create_tween().tween_property(boss_player, "volume_db", 0.0, 0.8)
	else:
		create_tween().tween_property(boss_player, "volume_db", -80.0, 3.0)


func set_escape_music(on: bool) -> void:
	if on:
		set_combat(false)
		escape_player.stop()
		escape_player.play()
		create_tween().tween_property(escape_player, "volume_db", 0.0, 0.5)
	else:
		create_tween().tween_property(escape_player, "volume_db", -80.0, 2.0)


func focus(on: bool) -> void:
	if on:
		play("focus_0", -2.0)
	else:
		play("focus_1", -4.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lowpass, "cutoff_hz", 1400.0 if on else 20000.0, 0.25)
	duck(0.35 if on else 1.0, 0.25)


func heartbeat(vol_db := -4.0) -> void:
	play("heartbeat", vol_db)


func update(dt: float, player_pos: Vector3) -> void:
	ambient_t -= dt
	if ambient_t <= 0.0:
		ambient_t = randf_range(7.0, 21.0)
		var pal: Array = PALETTE.get(zone, [])
		if not pal.is_empty():
			var kind: String = pal[randi() % pal.size()]
			var a := randf() * TAU
			var r := randf_range(8.0, 28.0)
			var pos := player_pos + Vector3(cos(a) * r, randf_range(1.0, 6.0), sin(a) * r)
			if kind == "chime":
				play("chime", -6.0, 1.0, "MusicVerb")
			elif kind == "boom":
				play("boom", -3.0)
			elif kind == "whale":
				play3d("whale", pos + Vector3(120, -30, 0), 8.0, 1.0, 60.0)
			else:
				play3d(kind, pos, 0.0, 1.0, 4.0)
	if not combat and zone != "silent":
		pad_t -= dt
		if pad_t <= 0.0:
			pad_t = randf_range(9.0, 23.0)
			play("pad", -4.0, 1.0, "MusicVerb")
			if randf() < 0.35:
				play("chime", -8.0, 1.0, "MusicVerb")


func pause(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)
