extends Node3D

# --- REQUIRED ---
@export var island_scene: PackedScene
@export var gate_scene: PackedScene
@export var portal_target_scene: PackedScene # drag LevelSelect.tscn (or whatever) here

@export_node_path("GridMap") var grid_path: NodePath
@export_node_path("SubViewport") var subviewport_path: NodePath

# Lamp -> spotlight (for your reveal shader system)
@export var lamp_node: Node3D
@export var spot_light_path: NodePath = NodePath("RigidBody3D/SpotLight3D")
@export var reveal_shader: Shader

# --- Offsets / difficulty tuning ---
@export var islands_y_offset: float = 2.0
@export var islands_x_pull: float = 1.2
@export var islands_scale_mul: float = 1.25
@export var islands_x_spacing_mul: float = 1.6

# --- Finish trigger tuning ---
@export var finish_area_size: Vector3 = Vector3(2.5, 3.0, 2.5) # box size around last island
@export var finish_area_y_offset: float = 1.5                 # lift trigger above island

# --- Gate placement (end of level) ---
@export var gate_after_islands_x_offset: int = 3
@export var gate_y_offset: float = -0.7
@export var gate_rotation_y_degrees: float = 0.0
@export var gate_scale_mult: Vector3 = Vector3(0.007, 0.007, 0.007)
@export var gate_world_offset: Vector3 = Vector3.ZERO

@export var islands := [
	{"pos": Vector3(7,  0.1,  0),  "scale": Vector3(2.2, 0.6, 2.2)},
	{"pos": Vector3(9,  0.8, -2),  "scale": Vector3(2.0, 0.6, 2.0)},
	{"pos": Vector3(11, 1.6,  1),  "scale": Vector3(2.2, 0.6, 2.2)},
	{"pos": Vector3(13, 2.0, -1),  "scale": Vector3(2.0, 1.0, 2.0)},
	{"pos": Vector3(15, 2.4,  2),  "scale": Vector3(2.2, 1.0, 2.2)},
	{"pos": Vector3(17, 2.0,  0),  "scale": Vector3(2.0, 1.0, 2.0)},
	{"pos": Vector3(19, 2.8, -2),  "scale": Vector3(2.2, 1.0, 2.2)},
	{"pos": Vector3(21, 3.2,  0),  "scale": Vector3(2.0, 1.0, 2.0)},
	{"pos": Vector3(23, 3.6, -1),  "scale": Vector3(2.2, 1.0, 2.2)},
	{"pos": Vector3(25, 3.0, -3),  "scale": Vector3(2.0, 1.0, 2.0)},
	{"pos": Vector3(27, 4.0, -1),  "scale": Vector3(2.2, 1.0, 2.2)},
]

@onready var grid := get_node_or_null(grid_path) as GridMap
@onready var viewport := get_node_or_null(subviewport_path) as SubViewport

var _spot: SpotLight3D
var _finish_area: Area3D
var _gate_spawned := false

func _ready() -> void:
	if island_scene == null:
		push_error("Assign island_scene.")
		return
	if viewport == null:
		push_error("Assign subviewport_path.")
		return

	_spawn_islands()
	_create_finish_area_on_last_island()

	_spot = _get_spotlight_from_lamp()

func _process(_dt: float) -> void:
	# Keep your reveal shader updated (optional)
	if reveal_shader == null:
		return

	if _spot == null:
		_spot = _get_spotlight_from_lamp()
	if _spot == null:
		return

	var pos: Vector3 = _spot.global_position
	var dir: Vector3 = (-_spot.global_transform.basis.z).normalized()
	var range: float = _spot.spot_range
	var outer_cos: float = cos(_spot.spot_angle)
	var inner_cos: float = cos(_spot.spot_angle * 0.7)

	for isl_node in get_tree().get_nodes_in_group("islands"):
		if isl_node is Node3D:
			_apply_reveal_to_island(isl_node as Node3D, pos, dir, range, inner_cos, outer_cos)

# -------------------- ISLANDS --------------------

func _spawn_islands() -> void:
	for data in islands:
		var isl := island_scene.instantiate() as Node3D
		viewport.add_child(isl)

		# no tilt
		isl.global_rotation = Vector3.ZERO

		var p: Vector3 = _apply_island_offsets(data["pos"])
		isl.global_position = p

		var base_scale: Vector3 = data.get("scale", Vector3.ONE)
		isl.scale = base_scale * islands_scale_mul

		isl.add_to_group("islands")

func _create_finish_area_on_last_island() -> void:
	if islands.is_empty():
		return

	# Use last island final position (after offsets)
	var last_data = islands[islands.size() - 1]
	var p: Vector3 = _apply_island_offsets(last_data["pos"])

	_finish_area = Area3D.new()
	_finish_area.name = "FinishArea"
	viewport.add_child(_finish_area)
	_finish_area.global_position = p + Vector3(0, finish_area_y_offset, 0)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = finish_area_size
	cs.shape = box
	_finish_area.add_child(cs)

	_finish_area.body_entered.connect(_on_finish_body_entered)

func _on_finish_body_entered(body: Node) -> void:
	if _gate_spawned:
		return

	# handle collider child -> player parent
	var p: Node = body
	if !(p is Node3D and (p as Node3D).is_in_group("player")):
		p = body.get_parent()

	if !(p is Node3D and (p as Node3D).is_in_group("player")):
		return

	_gate_spawned = true
	if is_instance_valid(_finish_area):
		_finish_area.queue_free()

	_spawn_gate_at_end()

# -------------------- GATE / PORTAL --------------------

func _spawn_gate_at_end() -> void:
	if gate_scene == null:
		push_warning("Assign gate_scene to spawn portal gate.")
		return

	var gate_pos := _compute_gate_position()

	var g := gate_scene.instantiate() as Node3D
	viewport.add_child(g)
	g.global_position = gate_pos + gate_world_offset
	g.rotation.y = deg_to_rad(gate_rotation_y_degrees)

	# Assign target scene if gate has property "target_scene"
	if portal_target_scene != null and _node_has_property(g, "target_scene"):
		g.set("target_scene", portal_target_scene)

	# Scale children like your Level1 code
	for child in g.get_children():
		if child is Node3D:
			(child as Node3D).scale = gate_scale_mult
			(child as Node3D).position *= gate_scale_mult

func _compute_gate_position() -> Vector3:
	# If we have GridMap, place it on the high ground after the gap.
	if grid != null:
		var base_y: int = int(grid.get("height_y")) - 1
		var high_h: int = int(grid.get("high_ground_height"))
		var size_z: int = int(grid.get("size_z"))
		var mid_z: int = -int(size_z / 2)

		var high_floor_y: int = base_y + high_h
		var start_x: int = int(grid.get("high_ground_start_x"))

		var gate_x := start_x + gate_after_islands_x_offset
		var cell := Vector3i(gate_x, high_floor_y + int(gate_y_offset), mid_z)
		return grid.to_global(grid.map_to_local(cell))

	# Fallback: after last island
	var last_data = islands[islands.size() - 1]
	var p: Vector3 = _apply_island_offsets(last_data["pos"])
	return p + Vector3(4, 1, 0)

func _apply_island_offsets(pos: Vector3) -> Vector3:
	var p := pos
	p.y -= islands_y_offset

	var base_x: float = 0.0
	if not islands.is_empty():
		base_x = islands[0]["pos"].x

	var rel_x := pos.x - base_x
	p.x = (base_x + rel_x * islands_x_spacing_mul) - islands_x_pull
	return p

func _node_has_property(n: Object, prop_name: String) -> bool:
	for p in n.get_property_list():
		if String(p.name) == prop_name:
			return true
	return false

# -------------------- REVEAL SHADER (same as before) --------------------

func _apply_reveal_to_island(isl: Node3D, pos: Vector3, dir: Vector3, range: float, inner_cos: float, outer_cos: float) -> void:
	var mi := isl.get_node_or_null("Island03_Cylinder") as MeshInstance3D
	if mi == null:
		var arr := isl.find_children("*", "MeshInstance3D", true, false)
		if arr.size() > 0 and arr[0] is MeshInstance3D:
			mi = arr[0] as MeshInstance3D
	if mi == null or mi.mesh == null:
		return

	var surface_count := mi.mesh.get_surface_count()

	for s in range(surface_count):
		var m := mi.get_surface_override_material(s)
		var sm: ShaderMaterial

		if m is ShaderMaterial:
			sm = m as ShaderMaterial
		else:
			sm = ShaderMaterial.new()
			mi.set_surface_override_material(s, sm)

		if sm.shader != reveal_shader:
			sm.shader = reveal_shader

		sm.set_shader_parameter("lamp_pos", pos)
		sm.set_shader_parameter("lamp_dir", dir)
		sm.set_shader_parameter("lamp_range", range)
		sm.set_shader_parameter("inner_cos", inner_cos)
		sm.set_shader_parameter("outer_cos", outer_cos)

func _get_spotlight_from_lamp() -> SpotLight3D:
	if lamp_node == null:
		return null

	var n := lamp_node.get_node_or_null(spot_light_path)
	if n is SpotLight3D:
		return n as SpotLight3D

	var arr := lamp_node.find_children("*", "SpotLight3D", true, false)
	if arr.size() > 0 and arr[0] is SpotLight3D:
		return arr[0] as SpotLight3D

	return null
