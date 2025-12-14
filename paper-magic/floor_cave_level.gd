extends GridMap

# --- Settings ---
@export var floor_tile_name: String = "Cube2"
@export var column_tile_name: String = "Cube4"
@export var torch_scene: PackedScene   # Drag lighted_torch.tscn here

# --- AUTO-LOAD BOX (No dragging needed) ---
# Make sure your file is named exactly "box.tscn" in the FileSystem!
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
	
	generate_level()

func generate_level() -> void:
	
	# --- 1. SPAWN FLOATING BOXES AT START ---
	# Spawns 2 boxes at x=2, x=4
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

	# --- 3. END WALL ---
	build_end_wall()

func spawn_floating_box(x: int):
	# 1. Instantiate the box directly
	var box = BOX_SCENE.instantiate()
	add_child(box)
	
	# 2. Position the box
	var grid_pos = Vector3i(x, height_y + 2, 1)
	var world_pos = map_to_local(grid_pos)
	box.position = world_pos
	
	# 3. FORCE SCALE THE INSIDES
	# We cannot scale 'box' (the RigidBody). We must scale its children.
	var mini_scale = Vector3(0.4, 0.4, 0.4)
	
	for child in box.get_children():
		# Check if it is a visual mesh or a collision shape
		if child is MeshInstance3D or child is CollisionShape3D:
			child.scale = mini_scale
			
			var new_shape = child.shape.duplicate()
			if new_shape is BoxShape3D:
				new_shape.size *= 0.1
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
