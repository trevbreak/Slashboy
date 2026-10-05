class_name IKLeg
extends RefCounted
## Two-bone IK leg with foot planting: feet stick to the floor and step when stretched.

var body: Node3D
var hip: Vector3
var rest: Vector3
var a: float
var b: float
var group := 0
var hip_g: Node3D
var femur_g: Node3D
var knee_g: Node3D
var foot := Vector3.ZERO
var from := Vector3.ZERO
var to := Vector3.ZERO
var step_t := 1.0
var stepping := false
var inited := false


func _init(p_body: Node3D, p_hip: Vector3, p_rest: Vector3, p_a: float, p_b: float, mats: Dictionary, r0: float, p_group: int) -> void:
	body = p_body; hip = p_hip; rest = p_rest; a = p_a; b = p_b; group = p_group
	hip_g = Node3D.new(); hip_g.position = hip; body.add_child(hip_g)
	femur_g = Node3D.new(); hip_g.add_child(femur_g)
	_sphere(hip_g, r0 * 1.35, mats.joint)
	femur_g.add_child(Creatures.limb(a, r0, r0 * 0.7, mats.limb))
	knee_g = Node3D.new(); knee_g.position.x = a; femur_g.add_child(knee_g)
	_sphere(knee_g, r0 * 0.95, mats.joint)
	var spike := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = r0 * 0.5; cm.height = r0 * 4.0; cm.radial_segments = 5
	spike.mesh = cm; spike.material_override = mats.limb
	spike.position = Vector3(0, r0 * 1.8, 0); spike.rotation.z = 0.3
	knee_g.add_child(spike)
	knee_g.add_child(Creatures.limb(b * 0.85, r0 * 0.75, r0 * 0.35, mats.limb))
	var claw := MeshInstance3D.new()
	var cc := CylinderMesh.new(); cc.top_radius = 0.0; cc.bottom_radius = r0 * 0.35; cc.height = b * 0.2; cc.radial_segments = 5
	claw.mesh = cc; claw.material_override = mats.claw
	claw.rotation.z = -PI / 2; claw.position.x = b * 0.95
	knee_g.add_child(claw)


func _sphere(parent: Node3D, r: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2; sm.radial_segments = 10; sm.rings = 6
	mi.mesh = sm; mi.material_override = mat
	parent.add_child(mi)


func desired(ground_y: float, lead: Vector3) -> Vector3:
	var w := body.to_global(rest) + lead
	w.y = ground_y
	return w


func update(dt: float, ground_y: float, vel: Vector3, planted: bool, other_stepping: bool, tuck := 0.0) -> void:
	if not inited:
		foot = desired(ground_y, Vector3.ZERO)
		inited = true
	if not planted:
		var t := rest
		t.y += tuck; t.x *= 1.0 - tuck * 0.4; t.z *= 1.0 - tuck * 0.2
		foot = foot.lerp(body.to_global(t), min(1.0, dt * 14.0))
		stepping = false
		step_t = 1.0
	else:
		var speed := Vector2(vel.x, vel.z).length()
		var want := desired(ground_y, Vector3(vel.x, 0, vel.z) * 0.12)
		if stepping:
			step_t = min(1.0, step_t + dt / max(0.07, 0.13 - speed * 0.006))
			foot = from.lerp(to, step_t)
			foot.y += sin(step_t * PI) * (0.14 + speed * 0.012)
			if step_t >= 1.0:
				stepping = false
		elif not other_stepping and foot.distance_to(want) > 0.32 + speed * 0.05:
			stepping = true
			step_t = 0.0
			from = foot
			to = want
	solve()


func solve() -> void:
	var t := body.to_local(foot) - hip
	hip_g.rotation.y = atan2(-t.z, t.x)
	var h := Vector2(t.x, t.z).length()
	var d: float = clamp(Vector2(h, t.y).length(), 0.05, a + b - 0.001)
	var ang := atan2(t.y, h)
	var alpha := acos(clamp((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var beta := acos(clamp((a * a + b * b - d * d) / (2.0 * a * b), -1.0, 1.0))
	femur_g.rotation.z = ang + alpha
	knee_g.rotation.z = -(PI - beta)
