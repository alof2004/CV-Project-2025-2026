extends GridMap

@export_group("Tiles")
@export var dirt_tile_name: String = "Cube3"

@export_group("World Size")
@export var size_x: int = 40
@export var size_z: int = 5
@export var height_y: int = 0

@export_group("High Ground Puzzle")
@export var high_ground_start_x: int = 15
@export var high_ground_height: int = 3

var dirt_tile_id: int = 0

# -------------------- CRYSTAL SPAWNING --------------------
@export_group("Crystal Spawning")
@export var crystal_scene: PackedScene
@export var crystal_group_name: String = "beam_prism"
@export var crystal_height_above_ground: float = 1.0
@export var crystal_ior: float = 1.5

@export_enum("Manual", "ZigZag", "Waypoints")
var crystal_pattern: String = "ZigZag"

@export var manual_crystal_cells: Array[Vector3i] = []

@export_group("ZigZag Pattern")
@export var zig_start: Vector3i = Vector3i(0, 0, 0)
@export var zig_count: int = 6
@export var zig_step_x: int = 6
@export var zig_amplitude_z: int = 2
@export var zig_every: int = 1

@export_group("Waypoint Pattern")
@export var waypoint_cells: Array[Vector3i] = [
	Vector3i(2, 0, 0),
	Vector3i(12, 0, 0),
	Vector3i(12, 0, 3),
	Vector3i(22, 0, 3)
]
@export var waypoint_spacing: int = 5

@export_group("Jitter")
@export var add_small_jitter: bool = true
@export var jitter_world_amount: float = 0.15

@export_group("Crystal Transform")
@export var crystal_rotation_degrees: Vector3 = Vector3.ZERO
@export var crystal_scale: Vector3 = Vector3.ONE
# ----------------------------------------------------------

@export_group("Beam Emitter Block")
@export var beam_block_enabled: bool = false
@export var beam_block_cell: Vector3i = Vector3i.ZERO
@export var beam_block_tile_name: String = ""
@export var beam_emitter_path: NodePath
@export var beam_face_offset: float = 0.05

func _ready() -> void:
	clear()

	var lib := mesh_library
	if lib == null:
		push_error("GridMap has no MeshLibrary assigned.")
		return

	dirt_tile_id = lib.find_item_by_name(dirt_tile_name)
	if dirt_tile_id == -1:
		push_error("Tile '%s' not found in MeshLibrary." % dirt_tile_name)
		return

	_generate_floor()
	_place_beam_block_and_emitter()
	_clear_old_crystals()
	_spawn_crystal_puzzle()

func _generate_floor() -> void:
	for x in range(-30, size_x):
		var current_floor_y: int = _floor_y_at_x(x)
		for z in range(size_z):
			for y in range(-5, current_floor_y + 1):
				set_cell_item(Vector3i(x, y, -z), dirt_tile_id)

func _floor_y_at_x(x: int) -> int:
	var current_floor_y: int = height_y - 1
	if x >= high_ground_start_x:
		current_floor_y += high_ground_height
	return current_floor_y

func _place_beam_block_and_emitter() -> void:
	if not beam_block_enabled:
		return

	if mesh_library == null:
		push_warning("Beam block: GridMap has no MeshLibrary assigned.")
		return

	var tile_name: String = beam_block_tile_name
	if tile_name == "":
		tile_name = dirt_tile_name

	var tile_id: int = mesh_library.find_item_by_name(tile_name)
	if tile_id == -1:
		push_warning("Beam block: Tile '%s' not found in MeshLibrary." % tile_name)
		return

	set_cell_item(beam_block_cell, tile_id)

	var emitter: Node3D = get_node_or_null(beam_emitter_path) as Node3D
	if emitter == null:
		push_warning("Beam block: Beam emitter not found at path '%s'." % String(beam_emitter_path))
		return

	var cell_center: Vector3 = to_global(map_to_local(beam_block_cell))
	emitter.global_position = cell_center

	var dir: Vector3 = (-emitter.global_transform.basis.z).normalized()
	if dir.length() < 0.001:
		dir = Vector3(0, 0, -1)

	var half: Vector3 = cell_size * 0.5

	var ax: float = absf(dir.x)
	var ay: float = absf(dir.y)
	var az: float = absf(dir.z)

	var face_distance: float = ax * float(half.x) + ay * float(half.y) + az * float(half.z)

	var start_offset: float = 0.0
	if _node_has_property(emitter, "start_offset"):
		start_offset = float(emitter.get("start_offset"))

	var origin_offset: Vector3 = dir * (face_distance + beam_face_offset - start_offset)

	if _node_has_property(emitter, "origin_offset"):
		emitter.set("origin_offset", origin_offset)
	else:
		emitter.global_position = cell_center + origin_offset

func _clear_old_crystals() -> void:
	for child in get_children():
		if child is Node3D and child.is_in_group(crystal_group_name):
			child.queue_free()

func _spawn_crystal_puzzle() -> void:
	if crystal_scene == null:
		push_warning("Crystal scene not assigned.")
		return

	var cells: Array[Vector3i] = []

	match crystal_pattern:
		"Manual":
			cells = manual_crystal_cells.duplicate()
		"ZigZag":
			cells = _make_zigzag_cells()
		"Waypoints":
			cells = _make_waypoint_cells()
		_:
			cells = manual_crystal_cells.duplicate()

	for c in cells:
		_spawn_one_crystal(c)

func _make_zigzag_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var base: Vector3i = zig_start

	var every: int = max(zig_every, 1)

	for i in range(max(zig_count, 0)):
		var x: int = base.x + i * zig_step_x

		# flip left/right
		var bucket: int = i / every
		var flip: bool = (bucket % 2) == 0

		var z: int = base.z + (zig_amplitude_z if flip else -zig_amplitude_z)
		out.append(Vector3i(x, base.y, z))

	return out

func _make_waypoint_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if waypoint_cells.size() < 2:
		return waypoint_cells.duplicate()

	var spacing: int = max(1, waypoint_spacing)

	for i in range(waypoint_cells.size() - 1):
		var a: Vector3i = waypoint_cells[i]
		var b: Vector3i = waypoint_cells[i + 1]

		var dx: int = b.x - a.x
		var dz: int = b.z - a.z

		# Only orthogonal segments
		if dx != 0 and dz != 0:
			push_warning("Waypoints segment %d->%d is diagonal. Use X-only or Z-only." % [i, i + 1])
			continue

		var steps: int = abs(dx) + abs(dz)

		var sx: int = 0
		var sz: int = 0
		if dx != 0:
			sx = 1 if dx > 0 else -1
		if dz != 0:
			sz = 1 if dz > 0 else -1

		var step_dir: Vector3i = Vector3i(sx, 0, sz)

		var t: int = 0
		while t <= steps:
			if (t % spacing) == 0:
				out.append(a + step_dir * t)
			t += 1

	out.append(waypoint_cells[-1])
	return out

func _spawn_one_crystal(cell: Vector3i) -> void:
	var spawn_cell: Vector3i = cell

	var ground_y: int = _floor_y_at_x(spawn_cell.x)
	spawn_cell.y = ground_y

	var world_pos: Vector3 = to_global(map_to_local(spawn_cell))
	world_pos.y += crystal_height_above_ground

	var inst: Node = crystal_scene.instantiate()
	if inst is Node3D:
		var n3: Node3D = inst as Node3D
		n3.global_position = world_pos
		n3.rotation_degrees = crystal_rotation_degrees
		n3.scale = crystal_scale
		n3.add_to_group(crystal_group_name)

		if add_small_jitter:
			var jx: float = randf_range(-jitter_world_amount, jitter_world_amount)
			var jz: float = randf_range(-jitter_world_amount, jitter_world_amount)
			n3.global_position += Vector3(jx, 0.0, jz)

		if _node_has_property(n3, "ior"):
			n3.set("ior", crystal_ior)

	add_child(inst)

func _node_has_property(n: Object, prop_name: String) -> bool:
	for p in n.get_property_list():
		if String(p.name) == prop_name:
			return true
	return false
