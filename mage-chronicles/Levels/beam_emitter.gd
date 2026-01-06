# BeamEmitter.gd (Godot 4) - "enter prism -> exit at marker -> continue"
extends Node3D

@export_flags_3d_physics var collision_mask: int = 1
@export var max_segments: int = 30
@export var max_distance: float = 100.0
@export var start_offset: float = 0.2

@export var beam_color: Color = Color(0.939, 0.575, 1.0, 1.0)
@export var beam_radius: float = 0.06
@export var use_thick_beam: bool = true

@export_group("Light")
@export var beam_light_enabled: bool = true
@export var beam_light_energy: float = 4.0
@export var beam_light_range: float = 12.0
@export var beam_light_color: Color = Color(0.939, 0.575, 1.0, 1.0)
@export var beam_light_offset: Vector3 = Vector3.ZERO

@export_group("Behavior")
@export var keep_horizontal_only: bool = false # set true if you want XZ-only beams

@export_group("Debug")
@export var debug_print_hits: bool = false

@onready var beam_mesh_instance: MeshInstance3D = $BeamMesh

var _mesh: ImmediateMesh = ImmediateMesh.new()
var _mat: StandardMaterial3D = StandardMaterial3D.new()
var _thick_parent: Node3D
var _thick_segments: Array[MeshInstance3D] = []
var _last_receiver: Node = null
var _last_prisms_hit: Array[Node] = []
var _beam_light: OmniLight3D = null

func _ready() -> void:
	beam_mesh_instance.mesh = _mesh
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = beam_color
	_mat.emission_enabled = true
	_mat.emission = beam_color * 3.0
	beam_mesh_instance.material_override = _mat

	_thick_parent = Node3D.new()
	_thick_parent.name = "BeamThick"
	add_child(_thick_parent)

	if beam_light_enabled:
		_beam_light = OmniLight3D.new()
		_beam_light.name = "BeamLight"
		_beam_light.light_color = beam_light_color
		_beam_light.light_energy = beam_light_energy
		_beam_light.omni_range = beam_light_range
		_beam_light.shadow_enabled = false
		add_child(_beam_light)

func _process(_delta: float) -> void:
	_update_beam()

func _update_beam() -> void:
	var points: PackedVector3Array = PackedVector3Array()
	var hit_receiver: Node = null
	var prisms_hit: Array[Node] = []

	var dir: Vector3 = (-global_transform.basis.z).normalized()
	if keep_horizontal_only:
		dir.y = 0.0
		dir = dir.normalized()

	var origin: Vector3 = global_position + dir * start_offset
	points.append(origin)

	# We keep excluding the last prism we used so we don't instantly re-hit it when exiting.
	var exclude_rids: Array[RID] = []

	for seg in range(max_segments):
		var hit: Dictionary = _raycast(origin, origin + dir * max_distance, exclude_rids)
		if hit.is_empty():
			points.append(origin + dir * max_distance)
			break

		var hit_pos: Vector3 = hit["position"]
		points.append(hit_pos)

		var collider_obj: Object = hit["collider"]
		var collider_node: Node = collider_obj as Node
		if collider_node == null:
			break

		if debug_print_hits:
			print("Hit: ", collider_node.name, " seg=", seg, " pos=", hit_pos)

		# Stop if it isn't a prism (but allow receivers to react)
		if not collider_node.is_in_group("beam_prism"):
			_last_prisms_hit = prisms_hit
			hit_receiver = _notify_beam_hit(collider_node, hit_pos, hit.get("normal", Vector3.ZERO), seg)
			break

		if not prisms_hit.has(collider_node):
			prisms_hit.append(collider_node)

		# Ask prism for exit point + exit direction
		var exit_pos: Vector3 = hit_pos
		var exit_dir: Vector3 = dir

		if collider_node.has_method("get_exit_position"):
			exit_pos = collider_node.call("get_exit_position")
		if collider_node.has_method("get_exit_direction"):
			exit_dir = collider_node.call("get_exit_direction")

		if keep_horizontal_only:
			exit_dir.y = 0.0
			if exit_dir.length() < 0.001:
				exit_dir = Vector3(0, 0, -1)
			exit_dir = exit_dir.normalized()

		# Draw the "inside the prism" segment (hit -> exit tip)
		points.append(exit_pos)

		# Continue from the exit tip
		dir = exit_dir
		origin = exit_pos + dir * start_offset
		points.append(origin)

		# Exclude this prism on next raycast so we don't immediately collide again on the exit
		if collider_obj is CollisionObject3D:
			exclude_rids = [(collider_obj as CollisionObject3D).get_rid()]
		else:
			exclude_rids = []

	_draw_polyline(points)
	if use_thick_beam:
		_draw_thick_beam(points)
	if hit_receiver != _last_receiver:
		_notify_beam_clear(_last_receiver)
		_last_receiver = hit_receiver
	if _beam_light != null:
		var light_pos := global_position
		if points.size() >= 2:
			light_pos = (points[0] + points[1]) * 0.5
		_beam_light.global_position = light_pos + beam_light_offset
		_beam_light.light_color = beam_light_color
		_beam_light.light_energy = beam_light_energy
		_beam_light.omni_range = beam_light_range

	_last_prisms_hit = prisms_hit

func get_last_prisms_hit() -> Array[Node]:
	return _last_prisms_hit.duplicate()

func _notify_beam_hit(collider_node: Node, hit_pos: Vector3, hit_normal: Vector3, seg: int) -> Node:
	if collider_node == null:
		return null
	if collider_node.has_method("on_beam_hit"):
		collider_node.call("on_beam_hit", hit_pos, hit_normal, seg)
		return collider_node
	var parent := collider_node.get_parent()
	if parent != null and parent.has_method("on_beam_hit"):
		parent.call("on_beam_hit", hit_pos, hit_normal, seg)
		return parent
	return null

func _notify_beam_clear(prev_receiver: Node) -> void:
	if prev_receiver == null:
		return
	if prev_receiver.has_method("on_beam_clear"):
		prev_receiver.call("on_beam_clear")

func _raycast(from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = collision_mask
	q.exclude = exclude
	return space_state.intersect_ray(q)

func _draw_polyline(points: PackedVector3Array) -> void:
	_mesh.clear_surfaces()
	if points.size() < 2:
		return

	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _mat)
	for p: Vector3 in points:
		_mesh.surface_add_vertex(beam_mesh_instance.to_local(p))
	_mesh.surface_end()

func _clear_thick() -> void:
	for s in _thick_segments:
		if is_instance_valid(s):
			s.queue_free()
	_thick_segments.clear()

func _draw_thick_beam(points: PackedVector3Array) -> void:
	if _thick_parent == null:
		return

	_clear_thick()
	if points.size() < 2:
		return

	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var len: float = a.distance_to(b)
		if len < 0.02:
			continue

		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = beam_radius
		cyl.bottom_radius = beam_radius
		cyl.height = len
		mi.mesh = cyl

		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = beam_color * 4.0
		m.albedo_color = beam_color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m

		_thick_parent.add_child(mi)
		_thick_segments.append(mi)

		var mid: Vector3 = (a + b) * 0.5
		mi.global_position = mid

		mi.look_at(b, Vector3.UP)
		# Cylinder axis is Y; rotate so Y aligns with forward
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
