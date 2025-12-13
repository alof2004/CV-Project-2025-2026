extends Node3D

@export_node_path("GridMap") var grid_path: NodePath
@export_node_path("Node3D") var box_template_path: NodePath
@export_node_path("SubViewport") var subviewport_path: NodePath

@export var spike_scene: PackedScene

# --- boxes BEFORE wall ---
@export var boxes_count: int = 3
@export var boxes_gap_cells: int = 2        # 1 adjacent, 2 one empty cell between, etc.
@export var boxes_y_offset: int = 1         # 1 = sit on top of floor cell

# --- spikes AFTER wall ---
@export var spike_after_wall_x_offset: int = 4
@export var spike_width_cells: int = 3
@export var spikes_y_offset: int = 1

# --- respawn BEHIND spikes (before them) ---
@export var respawn_before_spikes_cells: int = 2  # how many cells before first spike
@export var respawn_y_offset: int = 1

@onready var grid := get_node(grid_path) as GridMap
@onready var box_template := get_node(box_template_path) as Node3D
@onready var viewport := get_node(subviewport_path) as SubViewport

var respawn_marker: Marker3D = null

func _ready() -> void:
	if grid == null or box_template == null or viewport == null:
		push_error("Assign grid_path, box_template_path, subviewport_path in the Inspector.")
		return
	if spike_scene == null:
		push_error("Assign spike_scene (SpikePlatform.tscn) in the Inspector.")
		return

	box_template.visible = false

	var start_x: int = int(grid.get("high_ground_start_x"))
	var high_h: int = int(grid.get("high_ground_height"))
	var base_y: int = int(grid.get("height_y")) - 1
	var size_z: int = int(grid.get("size_z"))
	var mid_z: int = -int(size_z / 2)

	var low_floor_y: int = base_y
	var high_floor_y: int = base_y + high_h

	# -----------------------------
	# 1) PLOT BOXES (unchanged idea)
	# -----------------------------
	for i in range(boxes_count):
		var x := start_x - 1 - i * boxes_gap_cells
		var cell := Vector3i(x, low_floor_y + boxes_y_offset, mid_z)
		var world_pos := grid.to_global(grid.map_to_local(cell))
		spawn_box(world_pos)

	# -----------------------------
	# 2) CREATE RESPAWN POINT (behind spikes)
	# -----------------------------
	var spike_x := start_x + spike_after_wall_x_offset
	var respawn_x := spike_x - respawn_before_spikes_cells

	respawn_marker = Marker3D.new()
	respawn_marker.name = "RespawnPoint"
	viewport.add_child(respawn_marker)

	var respawn_cell := Vector3i(respawn_x, high_floor_y + respawn_y_offset, mid_z)
	respawn_marker.global_position = grid.to_global(grid.map_to_local(respawn_cell))

	# -----------------------------
	# 3) PLOT SPIKES (after wall)
	# -----------------------------
	for i in range(spike_width_cells):
		var x2 := spike_x + i
		var spike_cell := Vector3i(x2, high_floor_y + spikes_y_offset, mid_z)
		var pos := grid.to_global(grid.map_to_local(spike_cell))
		spawn_spike(pos)

func spawn_box(world_pos: Vector3) -> Node3D:
	var b := box_template.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	b.name = "Box_%d" % Time.get_ticks_msec()
	viewport.add_child(b)
	b.visible = true
	b.global_position = world_pos
	return b

func spawn_spike(world_pos: Vector3) -> Node3D:
	var s := spike_scene.instantiate() as Node3D
	viewport.add_child(s)
	s.global_position = world_pos

	# Wire respawn into the spike's KillArea script
	var kill := s.get_node_or_null("KillArea")
	if kill and kill.has_method("set_respawn_target"):
		kill.call("set_respawn_target", respawn_marker)

	return s
