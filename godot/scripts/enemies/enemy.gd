class_name Enemy
extends CharacterBody3D
## Shared enemy plumbing: health, hit flash, state timer, drops, world-time movement.

var mgr
var kind := "enemy"
var alive := true
var dormant := false
var cloaked := false
var organic := true
var state := "idle"
var state_t := 0.0
var flash_t := 0.0
var max_hp := 30.0
var hp := 30.0
var radius := 0.5
var center_y := 0.5
var facing := 0.0
var drop_count := 2
var encounter = null
var remove_me := false
var scan_info := {}
var scan_proxy := {}
var flash_mats: Array = []
var rig: Node3D


func setup(p_mgr, pos: Vector3, _opts: Dictionary) -> void:
	mgr = p_mgr
	collision_layer = 4
	collision_mask = 1
	global_position = pos


func center() -> Vector3:
	return global_position + Vector3(0, center_y, 0)


func set_state(s: String) -> void:
	state = s
	state_t = 0.0


func take_damage(dmg: float, dir: Vector3, dmg_kind: String) -> void:
	if not alive or dormant:
		return
	hp -= dmg
	flash_t = 0.1
	on_hurt(dmg, dir, dmg_kind)
	if hp <= 0.0:
		die(dir)


func on_hurt(_dmg: float, _dir: Vector3, _kind: String) -> void:
	pass


func stagger(_t := 1.0, _dir := Vector3.ZERO) -> void:
	pass


## Kusari grapple hit: yank toward the player and stagger.
func grappled(from: Vector3) -> void:
	if not alive or dormant:
		return
	var dir := from - global_position
	dir.y = 0
	dir = dir.normalized()
	velocity = dir * 9.0 + Vector3(0, 3.0, 0)
	stagger(1.0, dir)
	take_damage(6, -dir, "grapple")


func die(dir: Vector3) -> void:
	if not alive:
		return
	alive = false
	set_state("dead")
	on_die(dir)
	var c := center()
	for i in drop_count:
		G.fx.pickup(c, "hp" if randf() < 0.7 else "ki")
	mgr.on_death(self)


func on_die(_dir: Vector3) -> void:
	pass


func update_flash(dt: float) -> void:
	flash_t = max(0.0, flash_t - dt)
	var k := 2.5 if flash_t > 0.0 else 0.0
	for m in flash_mats:
		if m is ShaderMaterial:
			m.set_shader_parameter("flash", k)
		elif m is StandardMaterial3D:
			m.emission_energy_multiplier = k


func player_flat_dist() -> float:
	var p: Vector3 = G.player.global_position
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


## move_and_slide at world time scale (Kage Focus / hit-stop slow the world, not the player)
func slide(ws: float) -> void:
	if ws <= 0.0001:
		return
	var v := velocity
	velocity = v * ws
	move_and_slide()
	velocity /= ws


func push_from_player(min_d: float) -> void:
	var p: Vector3 = G.player.global_position
	var dx := global_position.x - p.x
	var dz := global_position.z - p.z
	var d := Vector2(dx, dz).length()
	if d < min_d and d > 0.001:
		global_position.x += dx / d * (min_d - d)
		global_position.z += dz / d * (min_d - d)


func dispose() -> void:
	queue_free()
