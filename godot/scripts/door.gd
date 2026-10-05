class_name Door
extends Node3D
## Prime-style hatch: strike the hex lock to open; closes behind you; can be locked by encounters.

var level
var w := 3.0
var h := 3.5
var axis := "x"
var locked := false
var open_amt := 0.0
var target := 0.0
var timer := 0.0
var hold_open := false
var center := Vector3.ZERO
var panel_pos := Vector3.ZERO
var leaves: Array[Node3D] = []
var panel_mat: StandardMaterial3D
var strip_mat: StandardMaterial3D
var shape: CollisionShape3D


func setup(lvl, pos: Vector3, p_axis: String, p_w: float, p_h: float, p_locked: bool) -> void:
	level = lvl
	w = p_w; h = p_h; axis = p_axis; locked = p_locked
	center = pos
	panel_pos = pos + Vector3(0, 1.6, 0)
	position = pos
	if axis == "z":
		rotation.y = PI / 2
	var mats: Dictionary = level.mats
	panel_mat = level.emissive(Color.WHITE, 4.0)
	strip_mat = level.emissive(Color.WHITE, 2.0)
	for s in [-1, 1]:
		var leaf := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(w / 2, h, 0.3)
		body.mesh = bm
		body.material_override = mats.door
		body.position = Vector3(0, h / 2, 0)
		leaf.add_child(body)
		var strip := MeshInstance3D.new()
		var sm := BoxMesh.new(); sm.size = Vector3(0.06, h * 0.8, 0.34)
		strip.mesh = sm
		strip.material_override = strip_mat
		strip.position = Vector3(-s * (w / 4 - 0.05), h / 2, 0)
		leaf.add_child(strip)
		leaf.position.x = s * w / 4
		leaf.set_meta("side", s)
		add_child(leaf)
		leaves.append(leaf)
	var hex := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.32; cm.bottom_radius = 0.32; cm.height = 0.36; cm.radial_segments = 6
	hex.mesh = cm
	hex.material_override = panel_mat
	hex.rotation.x = PI / 2
	hex.position = Vector3(w / 4 - 0.38, 1.6, 0)
	leaves[0].add_child(hex)
	var fw := 0.35
	for s in [-1, 1]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new(); pm.size = Vector3(fw, h + fw, 0.7)
		post.mesh = pm
		post.material_override = mats.dark_metal
		post.position = Vector3(s * (w / 2 + fw / 2 - 0.05), (h + fw) / 2, 0)
		add_child(post)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new(); tm.size = Vector3(w + fw * 2, fw, 0.7)
	top.mesh = tm
	top.material_override = mats.dark_metal
	top.position = Vector3(0, h + fw / 2, 0)
	add_child(top)
	var glow := MeshInstance3D.new()
	var gm := BoxMesh.new(); gm.size = Vector3(w, 0.05, 0.74)
	glow.mesh = gm
	glow.material_override = strip_mat
	glow.position = Vector3(0, h - 0.02, 0)
	add_child(glow)
	# collision
	var body := StaticBody3D.new()
	body.collision_layer = 1
	shape = CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(w, h, 0.5)
	shape.shape = bs
	shape.position = Vector3(0, h / 2, 0)
	body.add_child(shape)
	add_child(body)
	refresh_color()


func refresh_color() -> void:
	var c := Color(1.0, 0.07, 0.09) if locked else Color(0.11, 0.83, 1.0)
	panel_mat.emission = c
	strip_mat.emission = c


func strike() -> void:
	if locked:
		G.audio.play3d("denied", panel_pos)
		G.hud.message("ACCESS DENIED", 1.2, true)
		return
	if target == 0.0:
		open_door()


func open_door() -> void:
	if target == 1.0:
		return
	target = 1.0
	timer = 0.0
	G.audio.play3d("door_open", panel_pos, 2.0)


func close_door() -> void:
	if target == 0.0:
		return
	target = 0.0
	G.audio.play3d("door_close", panel_pos)


func lock(slam := false) -> void:
	locked = true
	refresh_color()
	if target == 1.0:
		target = 0.0
		G.audio.play3d("door_slam" if slam else "door_close", panel_pos, 4.0 if slam else 0.0)


func unlock(chime := true) -> void:
	if not locked:
		return
	locked = false
	refresh_color()
	if chime:
		G.audio.play3d("unlock", panel_pos)


func update(dt: float, player_pos: Vector3) -> void:
	var speed := 1.6 if target > open_amt else 2.4
	open_amt = move_toward(open_amt, target, dt * speed)
	var e := open_amt * open_amt * (3.0 - 2.0 * open_amt)
	for leaf in leaves:
		leaf.position.x = leaf.get_meta("side") * (w / 4 + e * w / 2)
	shape.disabled = open_amt > 0.7
	if target == 1.0:
		timer += dt
		var dist := Vector2(player_pos.x - center.x, player_pos.z - center.z).length()
		if not hold_open and timer > 3.0 and dist > 6.0:
			close_door()
	elif open_amt > 0.05:
		var along: float = abs(player_pos.z - center.z) if axis == "x" else abs(player_pos.x - center.x)
		var across: float = abs(player_pos.x - center.x) if axis == "x" else abs(player_pos.z - center.z)
		if along < 0.7 and across < w / 2 and not locked:
			target = 1.0
			timer = 0.0
