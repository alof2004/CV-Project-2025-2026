extends Node3D

@export_node_path("GridMap") var grid_path: NodePath
@export_node_path("Node3D") var box_template_path: NodePath
@export_node_path("SubViewport") var subviewport_path: NodePath

@export var spike_scene: PackedScene

# --- boxes BEFORE wall ---
@export var boxes_count: int = 3
@export var boxes_gap_cells: int = 2
@export var boxes_y_offset: int = 1

# --- spikes AFTER wall ---
@export var spike_after_wall_x_offset: int = 4
@export var spike_depth_cells: int = 5
@export var spikes_y_offset: int = 6
@export var spike_world_y_offset: float = -0.4
# --- remove GridMap blocks to create a pit (Mario hole) ---
@export var make_spike_pit: bool = true
@export var pit_clear_from_y: int = -5

# --- respawn BEHIND spikes (before them) ---
@export var respawn_before_spikes_cells: int = 2
@export var respawn_y_offset: int = 1

# --- wood tile BEFORE spikes ---
@export var wood_tile_scene: PackedScene
@export var wood_before_spikes_cells: int = 1
@export var wood_y_offset: int = 1
@export var wood_world_y_offset: float = 0.0
@export var wood_world_offset: Vector3 = Vector3(-3.0, 0.0, -4.0)
@export var wood_count: int = 2
@export var wood_between_offset: Vector3 = Vector3(3.0, 0.0, 0.0)
@export var wood_scale_mult: Vector3 = Vector3(5.0, 5.0, 5.0)
@export var spike_scale_mult: Vector3 = Vector3(1.1, 1.1, 1.1)

# (kept from your script)
@export var wood_world_scale: Vector3 = Vector3(10.5, 20.0, 30.5)

# --- gate AFTER spikes ---
@export var gate_scene: PackedScene
@export var gate_after_spikes_x_offset: int = 2
@export var gate_y_offset: int = -0.7
@export var gate_world_offset: Vector3 = Vector3.ZERO
@export var gate_rotation_y_degrees: float = 0.0
@export var gate_scale_mult: Vector3 = Vector3(0.007, 0.007, 0.007)
@export var debug_spawner: bool = true

@onready var grid := get_node(grid_path) as GridMap
@onready var box_template := get_node(box_template_path) as Node3D
@onready var viewport := get_node(subviewport_path) as SubViewport

var respawn_marker: Marker3D = null

func _dbg(s: String) -> void:
	if debug_spawner:
		print("[Spawner] ", s)

func _find_first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var m := _find_first_mesh(c)
		if m != null:
			return m
	return null

func _find_first_collision_shape(n: Node) -> CollisionShape3D:
	if n is CollisionShape3D and (n as CollisionShape3D).shape != null:
		return n as CollisionShape3D
	for c in n.get_children():
		var cs := _find_first_collision_shape(c)
		if cs != null:
			return cs
	return null

func _ready() -> void:
	if grid == null or box_template == null or viewport == null:
		push_error("Assign grid_path, box_template_path, subviewport_path in the Inspector.")
		return
	if spike_scene == null:
		push_error("Assign spike_scene (SpikePlatform.tscn) in the Inspector.")
		return
	if gate_scene == null:
		push_warning("Assign gate_scene (GateWithPortal.tscn) in the Inspector to spawn the portal gate.")

	box_template.visible = false

	var start_x: int = int(grid.get("high_ground_start_x"))
	var high_h: int = int(grid.get("high_ground_height"))
	var base_y: int = int(grid.get("height_y")) - 1
	var size_z: int = int(grid.get("size_z"))
	var mid_z: int = -int(size_z / 2)

	var low_floor_y: int = base_y
	var high_floor_y: int = base_y + high_h

	# 1) BOXES
	for i in range(boxes_count):
		var x := start_x - 1 - i * boxes_gap_cells
		var cell := Vector3i(x, low_floor_y + boxes_y_offset, mid_z)
		var world_pos := grid.to_global(grid.map_to_local(cell))
		spawn_box(world_pos)

	# 2) RESPAWN
	var spike_x := start_x + spike_after_wall_x_offset
	var respawn_x := spike_x - respawn_before_spikes_cells

	respawn_marker = Marker3D.new()
	respawn_marker.name = "RespawnPoint"
	viewport.add_child(respawn_marker)

	var respawn_cell := Vector3i(respawn_x, high_floor_y + respawn_y_offset, mid_z)
	respawn_marker.global_position = grid.to_global(grid.map_to_local(respawn_cell))

	# 3) WOOD TILE(S)
	if wood_tile_scene != null:
		var wood_x := spike_x - wood_before_spikes_cells
		var wood_cell := Vector3i(wood_x, high_floor_y + wood_y_offset, mid_z)
		var base_wood_pos := grid.to_global(grid.map_to_local(wood_cell))

		base_wood_pos.y += wood_world_y_offset
		base_wood_pos += wood_world_offset

		for i in range(wood_count):
			var pos := base_wood_pos + wood_between_offset * float(i)

			var wood := spawn_wood_tile(pos)
			wood.name = "WoodTile_%d" % i

			# scale EVERYTHING under StaticBody3D2 (mesh + collision + aura)
			scale_wood_tile_everything(wood, wood_scale_mult)

			# (optional) ensure it can be selected
			var body := wood.get_node_or_null("StaticBody3D2") as Node3D
			if body and not body.is_in_group("wand_target"):
				body.add_to_group("wand_target")
	else:
		push_warning("[Spawner] Assign wood_tile_scene in the Inspector.")

	# 4) SPIKES + PIT
	for dx in range(spike_depth_cells):
		var x2 := spike_x + dx
		for zi in range(size_z):
			var z2 := -zi

			if make_spike_pit:
				for y in range(pit_clear_from_y, high_floor_y + 1):
					grid.set_cell_item(Vector3i(x2, y, z2), -1)

			var pit_bottom_y: int = pit_clear_from_y + 1
			var spike_cell := Vector3i(x2, pit_bottom_y + spikes_y_offset, z2)
			var pos := grid.to_global(grid.map_to_local(spike_cell))
			pos.y += spike_world_y_offset
			spawn_spike(pos)

	# 5) GATE WITH PORTAL (after spikes)
	if gate_scene != null:
		var gate_x := spike_x + spike_depth_cells + gate_after_spikes_x_offset
		var gate_cell := Vector3i(gate_x, high_floor_y + gate_y_offset, mid_z)
		var gate_pos := grid.to_global(grid.map_to_local(gate_cell))
		gate_pos += gate_world_offset
		spawn_gate(gate_pos)

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

	# scale the whole spike scene
	s.scale *= spike_scale_mult

	var kill := s.find_child("KillArea", true, false)
	if kill != null and kill.has_method("set_respawn_target"):
		kill.call("set_respawn_target", respawn_marker)
	else:
		push_warning("[Spawner] KillArea not found or has no set_respawn_target() in spike scene.")

	return s

func spawn_wood_tile(world_pos: Vector3) -> Node3D:
	var w := wood_tile_scene.instantiate() as Node3D
	viewport.add_child(w)
	w.global_position = world_pos
	return w

func spawn_gate(world_pos: Vector3) -> Node3D:
	var g := gate_scene.instantiate() as Node3D
	viewport.add_child(g)
	g.global_position = world_pos
	g.rotation.y = deg_to_rad(gate_rotation_y_degrees)
	
	# --- HARDCODED LOAD ---
	# We force the script to load the file directly by name.
	# MAKE SURE THE PATH MATCHES YOUR FILE EXACTLY!
	var manual_scene = load("res://LevelSelect.tscn")
	
	if manual_scene:
		print("[Spawner] Loaded LevelSelect.tscn manually. Assigning to Gate...")
		g.target_scene = manual_scene
	else:
		print("[Spawner] CRITICAL ERROR: Could not find 'res://LevelSelect.tscn'. Check spelling!")
	# ----------------------

	# ... existing scaling code ...
	for child in g.get_children():
		if child is Node3D:
			child.scale = gate_scale_mult
			child.position *= gate_scale_mult
			
	return g
func scale_wood_tile_everything(wood_root: Node3D, scale_mult: Vector3) -> void:
	var body := wood_root.get_node_or_null("StaticBody3D2") as Node3D
	if body == null:
		body = wood_root

	# scale visual mesh
	var mesh := _find_first_mesh(body)
	if mesh:
		mesh.scale *= scale_mult

	# scale collision
	var cs := _find_first_collision_shape(body)
	if cs:
		cs.scale *= scale_mult

	# scale aura too
	var aura := body.get_node_or_null("SelectionAura") as Node3D
	if aura:
		aura.top_level = false
		aura.scale *= scale_mult
