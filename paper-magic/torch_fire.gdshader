extends GridMap

# --- Settings ---
@export var tile_name: String = "Cube2" # We will double check this name!
@export var torch_scene: PackedScene 

@export var level_length: int = 20
@export var level_width: int = 5
@export var torch_interval: int = 4
@export var height_y: int = 0

var tile_id: int = 0

func _ready() -> void:
	clear() 
	
	if mesh_library == null:
		push_error("CRITICAL: No MeshLibrary assigned.")
		return

	# --- DEBUG SECTION: PRINT ALL TILE NAMES ---
	print("--- LIST OF AVAILABLE TILES ---")
	for id in mesh_library.get_item_list():
		var name = mesh_library.get_item_name(id)
		print("ID: ", id, " | Name: ", name)
	print("-------------------------------")
	# -------------------------------------------

	# Try to find the tile
	tile_id = mesh_library.find_item_by_name(tile_name)
	
	if tile_id == -1:
		push_error("CRITICAL ERROR: Could not find a tile named '" + tile_name + "'. Check the list above for the correct spelling!")
		return # Stop here because we can't draw the floor

	generate_level()

func generate_level() -> void:
	for x in range(level_length):
		for z in range(level_width):
			set_cell_item(Vector3i(x, height_y - 1, z), tile_id)

		if torch_scene != null and x > 0 and x % torch_interval == 0:
			spawn_torch(x)

func spawn_torch(x_coord: int):
	var torch = torch_scene.instantiate()
	add_child(torch)
	var world_pos = map_to_local(Vector3i(x_coord, height_y, 0))
	world_pos.y += 1.0 
	torch.position = world_pos