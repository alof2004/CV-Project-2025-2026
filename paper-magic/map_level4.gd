extends GridMap

# --- Settings ---
@export_group("Terrain")
@export var tile_name: String = "Cube"
@export var dirt_tile_name: String = "Cube3"
@export var size_x: int = 85 # Made slightly larger to fit everything
@export var size_z: int = 5
@export var height_y: int = 0   

@export_group("Puzzle Logic")
@export var high_ground_start_x: int = 15   
@export var high_ground_height: int = 3     
@export var platform_scene: PackedScene     

# --- DYNAMIC ABYSS VARIABLES ---
# These determine where the platforms start and how far apart they are
var platform_start_x: float = 60.0
var platform_spacing: float = 4.0

# Calculated automatically in _ready()
var abyss_start_x: int = 0
var abyss_end_x: int = 0

var tile_id: int = 0
var dirt_tile_id: int = 0
const PASSWORD_LETTERS = ["M", "A", "G", "I", "C"]

func _ready() -> void:
	clear()
	
	# Cleanup old platforms
	for child in get_children():
		if child.name.begins_with("Platform_"):
			child.queue_free()

	# Failsafe Load
	if platform_scene == null:
		if ResourceLoader.exists("res://Letter_island.tscn"):
			platform_scene = load("res://Letter_island.tscn")
		else:
			print("CRITICAL ERROR: 'res://Letter_island.tscn' not found.")
			return

	var lib := mesh_library
	if lib == null:
		push_error("GridMap has no MeshLibrary assigned.")
		return

	tile_id = lib.find_item_by_name(tile_name)
	dirt_tile_id = lib.find_item_by_name(dirt_tile_name)

	# --- 1. CALCULATE ABYSS ZONE ---
	# We calculate where the hole needs to be BEFORE generating the floor.
	# Formula: Start - 1 block padding
	abyss_start_x = int(platform_start_x) - 1
	
	# Formula: Start + (Number of letters * Spacing) + 1 block padding
	var total_platform_width = (PASSWORD_LETTERS.size() * platform_spacing)
	abyss_end_x = int(platform_start_x + total_platform_width) + 1
	
	print("Calculated Abyss Gap: X=", abyss_start_x, " to X=", abyss_end_x)

	# --- 2. GENERATE FLOOR (Skipping the gap) ---
	_generate_floor()
	
	# --- 3. SPAWN PLATFORMS (In the gap) ---
	call_deferred("_spawn_magic_platforms")

func _generate_floor() -> void:
	for x in range(size_x):
		
		# --- SKIP ABYSS ZONE ---
		# If the current X is inside our calculated gap, DO NOT place a block.
		if x >= abyss_start_x and x <= abyss_end_x:
			continue 
		# -----------------------

		var current_floor_y = height_y - 1
		if x >= high_ground_start_x:
			current_floor_y += high_ground_height
			
		for z in range(size_z):
			for y in range(-5, current_floor_y + 1):
				var tid = tile_id if y == current_floor_y else dirt_tile_id
				set_cell_item(Vector3i(x, y, -z), tid)

func _spawn_magic_platforms():
	if platform_scene == null: return
	
	print("--- SPAWNING PLATFORMS ---")
	
	for i in range(PASSWORD_LETTERS.size()):
		var letter = PASSWORD_LETTERS[i]
		var platform = platform_scene.instantiate()
		platform.name = "Platform_" + letter
		add_child(platform)
		
		# --- POSITION LOGIC ---
		# Use the EXACT same variables we used to calculate the gap
		# Logic: Start + (Index * Spacing) + RandomJitter
		var pos_x = platform_start_x + (i * platform_spacing) + randf_range(0.0, 1.0)
		
		var pos_y = 6.0 + randf_range(-1.0, 1.0)
		var pos_z = randf_range(0.0, -5.0)
		
		platform.global_position = Vector3(pos_x, pos_y, pos_z)
		platform.rotation_degrees.y = 180.0

		if not platform.is_in_group("wand_target"):
			platform.add_to_group("wand_target")

		if platform.has_method("set_letter"):
			platform.set_letter(letter)
		
		print("Spawned [", letter, "] at ", platform.global_position)
