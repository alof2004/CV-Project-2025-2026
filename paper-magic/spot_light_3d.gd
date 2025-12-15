extends SpotLight3D

@export var target_group: StringName = &"islands"
@export var margin_deg: float = 2.0

@export var fade_in_speed: float = 4.0
@export var fade_out_speed: float = 3.0
@export var show_collision_threshold: float = 0.4

var targets: Array[Node3D] = []
var reveal_values: Array[float] = []  # same index as targets

func _ready() -> void:
	targets.clear()
	reveal_values.clear()

	for n in get_tree().get_nodes_in_group(target_group):
		if n is Node3D:
			var t := n as Node3D
			targets.append(t)
			reveal_values.append(0.0)
			_apply_alpha(t, 0.0)
			_set_collision(t, false)

func _physics_process(dt: float) -> void:
	var pos: Vector3 = global_position
	var dir: Vector3 = (-global_transform.basis.z).normalized()
	var range: float = spot_range

	var outer_cos: float = cos(spot_angle + deg_to_rad(margin_deg))
	var inner_cos: float = cos(spot_angle * 0.7) # inner cone

	for i in range(targets.size()):
		var t: Node3D = targets[i]
		if !is_instance_valid(t):
			continue

		var v: Vector3 = t.global_position - pos
		var d: float = v.length()

		var target: float = 0.0

		if d > 0.001 and d <= range:
			var dotv: float = dir.dot(v / d)

			# cone falloff: 0 at edge -> 1 near center
			var cone_att: float = smoothstep(outer_cos, inner_cos, dotv)

			# distance falloff: 1 near lamp -> 0 at range
			var dist_att: float = clamp(1.0 - (d / range), 0.0, 1.0)

			target = cone_att * dist_att

		var cur: float = reveal_values[i]
		var speed: float = fade_in_speed if target > cur else fade_out_speed
		cur = move_toward(cur, target, speed * dt)
		reveal_values[i] = cur

		_apply_alpha(t, cur)
		_set_collision(t, cur >= show_collision_threshold)

func _apply_alpha(root: Node, a: float) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D

		# material override
		var mat := mi.material_override
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			var c: Color = sm.albedo_color
			c.a = a
			sm.albedo_color = c

		# surface materials
		if mi.mesh != null:
			var sc: int = mi.mesh.get_surface_count()
			for s in range(sc):
				var m2 := mi.get_active_material(s)
				if m2 is StandardMaterial3D:
					var sm2 := m2 as StandardMaterial3D
					var c2: Color = sm2.albedo_color
					c2.a = a
					sm2.albedo_color = c2

func _set_collision(root: Node, enabled: bool) -> void:
	for child in root.find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = !enabled
