extends GridMap

@export var tile_name: String = "Cube"       
@export var dirt_tile_name: String = "Cube3" 

@export var size_x: int = 40
@export var size_z: int = 5
@export var height_y: int = 0   


@export var high_ground_start_x: int = 15   
@export var high_ground_height: int = 3     


var tile_id: int = 0
var dirt_tile_id: int = 0

func _ready() -> void:
	clear()

	var lib := mesh_library
	if lib == null:
		push_error("GridMap has no MeshLibrary assigned.")
		return

	
	tile_id = lib.find_item_by_name(tile_name)
	if tile_id == -1:
		push_error("Tile '%s' not found in MeshLibrary." % tile_name)
		return

	
	dirt_tile_id = lib.find_item_by_name(dirt_tile_name)
	if dirt_tile_id == -1:
		push_error("Tile '%s' not found in MeshLibrary." % dirt_tile_name)
		return

	_generate_floor()

func _generate_floor() -> void:
	for x in range(-30,size_x):
		
		var current_floor_y = height_y - 1
		
		
		if x >= high_ground_start_x:
			current_floor_y += high_ground_height

		for z in range(size_z):
			
			for y in range(-5, current_floor_y + 1):
				
				
				if y == current_floor_y:
					set_cell_item(Vector3i(x, y, -z), tile_id)
				
				else:
					set_cell_item(Vector3i(x, y, -z), dirt_tile_id)
