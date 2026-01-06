extends Node3D

@export var gate_scene: PackedScene
@export var target_scene: PackedScene
@export var gate_spawn_path: NodePath = NodePath("GateSpawn")
@export var gate_rotation_y_degrees: float = 0.0
@export var gate_scale_mult: Vector3 = Vector3(0.007, 0.007, 0.007)
@export var gate_world_offset: Vector3 = Vector3.ZERO
@export var trigger_once: bool = false

@export_group("Beam Requirement")
@export var require_all_prisms: bool = false
@export var prism_group_name: StringName = &"beam_prism"
@export var beam_emitter_path: NodePath

var _gate_instance: Node3D = null

func on_beam_hit(_hit_pos: Vector3, _hit_normal: Vector3, _segment: int) -> void:
	if require_all_prisms and not _all_prisms_hit():
		_set_gate_active(false)
		return
	_ensure_gate()
	_set_gate_active(true)

func on_beam_clear() -> void:
	_set_gate_active(false)

func _ensure_gate() -> void:
	if _gate_instance != null:
		return
	if gate_scene == null:
		push_warning("Cube gate: gate_scene not assigned.")
		return

	_gate_instance = gate_scene.instantiate() as Node3D
	if _gate_instance == null:
		return

	var spawn := get_node_or_null(gate_spawn_path) as Node3D
	var pos := global_position
	if spawn != null:
		pos = spawn.global_position

	_gate_instance.global_position = pos + gate_world_offset
	_gate_instance.rotation.y = deg_to_rad(gate_rotation_y_degrees)

	if target_scene != null and _node_has_property(_gate_instance, "target_scene"):
		_gate_instance.set("target_scene", target_scene)

	for child in _gate_instance.get_children():
		if child is Node3D:
			var n3 := child as Node3D
			n3.scale = gate_scale_mult
			n3.position *= gate_scale_mult

	var parent := get_parent()
	if parent != null:
		parent.add_child(_gate_instance)
	else:
		add_child(_gate_instance)

	if trigger_once:
		return
	_set_gate_active(false)

func _set_gate_active(active: bool) -> void:
	if _gate_instance == null:
		return

	_gate_instance.visible = active

	for shape in _gate_instance.find_children("", "CollisionShape3D", true, false):
		if shape is CollisionShape3D:
			(shape as CollisionShape3D).disabled = not active

func _node_has_property(n: Object, prop_name: String) -> bool:
	for p in n.get_property_list():
		if String(p.name) == prop_name:
			return true
	return false

func _all_prisms_hit() -> bool:
	var prisms := get_tree().get_nodes_in_group(prism_group_name)
	if prisms.is_empty():
		return true

	var emitter := get_node_or_null(beam_emitter_path) as Node
	if emitter == null:
		push_warning("Cube gate: beam_emitter_path not set.")
		return false

	if not emitter.has_method("get_last_prisms_hit"):
		push_warning("Cube gate: beam emitter missing get_last_prisms_hit().")
		return false

	var hit_list: Array = emitter.call("get_last_prisms_hit")
	for prism in prisms:
		if not hit_list.has(prism):
			return false
	return true
