extends GridMap

# --- Settings ---
@export var tile_name: String = "Cube2"
@export var torch_scene: PackedScene  # <--- Make sure you drag lighted_torch.tscn here!

@export var level_length: int = 20
@export var level_width: int = 5
@export var torch_interval: int = 4
@export var height_y: int = 0

var tile_id: int = 0

func _ready() -> void:
	clear() 
	
	if mesh_library == null:
		push_error("CRITICAL: GridMap has no MeshLibrary assigned.")
		return

	# 2. Find the Tile ID
	tile_id = mesh_library.find_item_by_name(tile_name)
	if tile_id == -1:
		push_error("CRITICAL: Tile '%s' not found. Check the name!" % tile_name)
		return

	# 3. Check Torch Scene (Critical for torches!)
	if torch_scene == null:
		push_error("ERROR: Torch Scene is [empty]. You must drag lighted_torch.tscn to the Inspector!")
	
	generate_level()

func generate_level() -> void:
	# --- GROUND GENERATION (Unchanged) ---
	for x in range(level_length):
		for z in range(level_width):
			set_cell_item(Vector3i(x, height_y - 1, z), tile_id)

		# --- TORCH GENERATION (Fixed) ---
		# We check if x > 0 to avoid putting a torch on the player's start position
		if x > 0 and x % torch_interval == 0:
			spawn_torch(x)

func spawn_torch(x_coord: int):
	# Safety Check: If the user forgot to drag the file, stop here so we don't crash
	if torch_scene == null:
		return 

	var torch = torch_scene.instantiate()
	add_child(torch)
	
	# We place the torch at the current X, at ground height, and at Z=0 (left edge)
	var grid_pos = Vector3i(x_coord, height_y, 0)
	
	# map_to_local converts the grid coordinate to real world coordinates (e.g. 5 meters)
	var world_pos = map_to_local(grid_pos)
	
	# Adjust Height:
	# map_to_local gives the center of the cell. 
	# If your torch floats too high, lower this number (e.g., to 0.5 or 0.0)
	world_pos.y += 0.5 
	
	torch.position = world_pos
	
	# DEBUG: This prints to the console so you know it worked!
	print("Torch spawned at: ", world_pos)
