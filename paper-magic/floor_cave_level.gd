extends GridMap

# --- Settings ---
@export var floor_tile_name: String = "Cube2"
@export var column_tile_name: String = "Cube4"
@export var torch_scene: PackedScene

# --- NEW GATE SETTINGS ---
@export var gate_scene: PackedScene # Drag GateWithPortal.tscn here
@export var gate_scale_mult: Vector3 = Vector3(0.007, 0.007, 0.007) # Copied from level 1
@export var gate_y_offset: float = -0.7 # Adjust this if it sits too high/low
# -------------------------

# --- AUTO-LOAD BOX (No dragging needed) ---
const BOX_SCENE = preload("res://mini_box.tscn")

@export var level_length: int = 40
@export var level_width: int = 5
@export var torch_interval: int = 8
@export var height_y: int = 0

var floor_id: int = -1
var column_id: int = -1

func _ready() -> void:
	clear()
	
	if mesh_library == null:
		push_error("CRITICAL: GridMap has no MeshLibrary assigned.")
		return

	floor_id = mesh_library.find_item_by_name(floor_tile_name)
	column_id = mesh_library.find_item_by_name(column_tile_name)

	if floor_id == -1 or column_id == -1:
		push_error("CRITICAL: Could not find tile names.")
		return

	if torch_scene == null:
		push_error("ERROR: Torch Scene is empty.")
		
	if gate_scene == null:
		push_warning("WARNING: Gate Scene is not assigned.")
	
	generate_level()

func generate_level() -> void:
	
	# --- 0. SPAWN START GATE ---
	# Changed rotation from 90.0 to 0.0 so it faces the correct way
	spawn_gate(0, 2, 0.0) 

	# --- 1. SPAWN FLOATING BOXES AT START ---
	for i in range(2):
		var box_x = 2 + (i * 2)
		spawn_floating_box(box_x)

	# --- 2. MAIN LEVEL LOOP ---
	for x in range(level_length):
		
		# A. Generate Floor
		for z in range(level_width):
			set_cell_item(Vector3i(x, height_y - 1, z), floor_id)

		# B. Generate Pillars & Torches
		if x > 0 and x % torch_interval == 0:
			var pillar_height = randi_range(1, 3)
			build_pillar(x, pillar_height, 0)
			spawn_torch(x, pillar_height, 0)

	# --- 3. END WALL & END GATE ---
	build_end_wall()
	
	# Spawn End Gate at the very end
	# Changed rotation from 90.0 to 0.0 (Try 180.0 if it faces backwards)
	spawn_gate(level_length - 1, 2, 0.0)
	
# --- NEW FUNCTION: GATE SPAWNER (From Level 1 logic) ---
func spawn_gate(x: int, z: int, rotation_deg: float):
	if gate_scene == null: return
	
	var g = gate_scene.instantiate()
	add_child(g)
	
	# Position logic using GridMap coordinates
	var grid_pos = Vector3i(x, height_y, z) # Gate sits at player height
	var world_pos = map_to_local(grid_pos)
	
	# Apply manual adjustments
	world_pos.y += gate_y_offset
	
	g.position = world_pos
	g.rotation_degrees.y = rotation_deg

	# 1. HARDCODED TARGET SCENE (Fixes the "Portal not working" bug)
	var manual_scene = load("res://LevelSelect.tscn")
	if manual_scene:
		g.target_scene = manual_scene
	else:
		print("ERROR: Could not find LevelSelect.tscn")

	# 2. MANUAL SCALING (Fixes the "Giant Gate" bug)
	# This scales the children specifically, just like your Level 1 script
	for child in g.get_children():
		if child is Node3D:
			child.scale = gate_scale_mult
			child.position *= gate_scale_mult

# --- Existing Helper Functions ---

func spawn_floating_box(x: int):
	var box = BOX_SCENE.instantiate()
	add_child(box)
	
	var grid_pos = Vector3i(x, height_y + 2, 1)
	var world_pos = map_to_local(grid_pos)
	box.position = world_pos
	
	# Only needed if you aren't using the mini_box.tscn directly
	# (But since we loaded mini_box.tscn above, this is just a safeguard)
	var mini_scale = Vector3(0.4, 0.4, 0.4)
	for child in box.get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			child.scale = mini_scale
			var new_shape = child.shape.duplicate()
			if new_shape is BoxShape3D:
				new_shape.size *= 0.1 # This was 0.1 in your snippet, keeping it safe
			child.shape = new_shape

func build_pillar(x: int, height: int, z: int):
	for y in range(height_y, height_y + height):
		set_cell_item(Vector3i(x, y, z), column_id)

func spawn_torch(x: int, pillar_height: int, z: int):
	if torch_scene == null: return
	var torch = torch_scene.instantiate()
	add_child(torch)
	
	var top_block_y = height_y + pillar_height - 1
	var grid_pos = Vector3i(x, top_block_y, z)
	var world_pos = map_to_local(grid_pos)
	
	world_pos.z += 1.2
	world_pos.y -= 0.5
	
	torch.position = world_pos
	torch.rotation_degrees.y = 0

func build_end_wall():
	var start_x = level_length
	for x in range(start_x, start_x + 3):
		for y in range(height_y, height_y + 10):
			for z in range(-1, level_width + 1):
				set_cell_item(Vector3i(x, y, z), column_id)
