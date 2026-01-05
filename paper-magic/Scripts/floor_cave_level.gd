extends GridMap

# --- Settings ---
@export var floor_tile_name: String = "Cube2"
@export var column_tile_name: String = "Cube4"
@export var torch_scene: PackedScene

# --- GATE SETTINGS ---
@export var gate_scene: PackedScene 
@export var gate_scale_mult: Vector3 = Vector3(0.007, 0.007, 0.007) 
@export var gate_y_offset: float = -0.7 

# --- BOX SETTINGS ---
@export var box_scene: PackedScene 

# --- DIMENSIONS ---
@export var level_length: int = 28   
@export var level_width: int = 5
@export var torch_interval: int = 6  
@export var height_y: int = 0

var floor_id: int = -1
var column_id: int = -1

# --- COUNTERS ---
var total_torches: int = 0
var lit_torches_count: int = 0

func _ready() -> void:
	clear()
	
	for child in get_children():
		if child.name.begins_with("Generated_"):
			child.queue_free()
	
	if box_scene == null:
		box_scene = load("res://mini_box.tscn")
	
	if mesh_library:
		floor_id = mesh_library.find_item_by_name(floor_tile_name)
		column_id = mesh_library.find_item_by_name(column_tile_name)

	generate_level()

func generate_level() -> void:
	total_torches = 0
	lit_torches_count = 0
	
	# 0. Backfill
	for x in range(-5, 0):
		for z in range(level_width):
			set_cell_item(Vector3i(x, height_y - 1, z), floor_id)

	# 1. Start Gate (0.0 rotation)
	spawn_gate(0, 2, 0.0, "Generated_StartGate") 

	# 2. Boxes (Spawning at x=3 and x=4, center z=2)
	for i in range(2):
		spawn_floating_box(3 + i)

	# 3. Main Level
	for x in range(level_length):
		for z in range(level_width):
			set_cell_item(Vector3i(x, height_y - 1, z), floor_id)

		if x > 0 and x % torch_interval == 0:
			var pillar_height = randi_range(1, 3)
			build_pillar(x, pillar_height, 1) 
			spawn_torch(x, pillar_height, 1)

	# 4. End Wall
	build_end_wall()
	
	print("Level Ready. Torches to light: ", total_torches)

# --- TORCH LOGIC ---

func spawn_torch(x: int, pillar_height: int, z: int):
	if torch_scene == null: return
	var torch = torch_scene.instantiate()
	torch.name = "Generated_Torch"
	add_child(torch)
	
	if torch.has_signal("torch_lit"):
		torch.connect("torch_lit", _on_torch_lit)
		total_torches += 1
	
	var top_block_y = height_y + pillar_height - 1
	var grid_pos = Vector3i(x, top_block_y, z)
	var world_pos = map_to_local(grid_pos)
	
	world_pos.z += 1.2
	world_pos.y -= 0.5
	torch.position = world_pos

func _on_torch_lit():
	lit_torches_count += 1
	print("Progress: ", lit_torches_count, " / ", total_torches)
	
	if lit_torches_count >= total_torches:
		print("ALL TORCHES LIT! OPENING GATE!")
		# We call call_deferred to ensure this runs safely on the main thread
		call_deferred("open_exit_gate")

func open_exit_gate():
	# 1. CLEAR THE AREA AGGRESSIVELY
	# We clear from (level_length - 1) to (level_length + 3) to make a big opening
	var start_clear = level_length - 1
	var end_clear = level_length + 3
	
	print("DEBUG: Clearing blocks from X=", start_clear, " to ", end_clear)
	
	for x in range(start_clear, end_clear):
		for y in range(height_y - 1, height_y + 10):
			for z in range(-1, level_width + 1):
				# Don't delete the floor under the gate!
				if y == height_y - 1 and x == (level_length - 1):
					continue 
				set_cell_item(Vector3i(x, y, z), -1) # Delete block

	# 2. SPAWN GATE
	# Spawns at level_length - 1 (The last valid floor tile)
	# Rotation 0.0 (Matches your start gate) or -90.0 if sideways
	spawn_gate(level_length - 1, 2, 0.0, "Generated_EndGate")

# --- SPAWNERS ---

func spawn_gate(x: int, z: int, rotation_deg: float, gate_name: String):
	if gate_scene == null: 
		print("ERROR: Gate Scene is missing!")
		return
	
	var g = gate_scene.instantiate()
	g.name = gate_name
	add_child(g)
	
	var grid_pos = Vector3i(x, height_y, z) 
	var world_pos = map_to_local(grid_pos)
	world_pos.y += gate_y_offset
	
	g.position = world_pos
	g.rotation_degrees.y = rotation_deg
	
	# HARDCODED TARGET SCENE
	var manual_scene = load("res://LevelSelect.tscn")
	if manual_scene:
		g.target_scene = manual_scene
	
	# SCALING FIX
	for child in g.get_children():
		if child is Node3D:
			child.scale = gate_scale_mult
			child.position *= gate_scale_mult
	
	print("DEBUG: Gate spawned at ", g.position)

func spawn_floating_box(x: int):
	if box_scene == null: return 
	var box = box_scene.instantiate()
	add_child(box)
	var grid_pos = Vector3i(x, height_y + 2, 2)
	box.position = map_to_local(grid_pos)
	
	var mini_scale = Vector3(0.4, 0.4, 0.4)
	for child in box.get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			child.scale = mini_scale
			if child is CollisionShape3D and child.shape is BoxShape3D:
				child.shape = child.shape.duplicate()

func build_pillar(x: int, height: int, z: int):
	for y in range(height_y, height_y + height):
		set_cell_item(Vector3i(x, y, z), column_id)

func build_end_wall():
	var start_x = level_length
	for x in range(start_x, start_x + 3):
		for y in range(height_y-1, height_y + 10):
			for z in range(-1, level_width + 1):
				set_cell_item(Vector3i(x, y, z), column_id)
