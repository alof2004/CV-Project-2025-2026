extends GridMap

@export var tile_name: String = "Cube"
@export var size_x: int = 40
@export var size_z: int = 5
@export var height_y: int = 0   # logical “ground level”; we’ll place cubes one below

var tile_id: int = 0

func _ready() -> void:
	clear() # removes all tiles from the GridMap

	var lib := mesh_library
	if lib == null:
		push_error("GridMap has no MeshLibrary assigned.")
		return

	tile_id = lib.find_item_by_name(tile_name)
	print("Tile id:", tile_id)
	print("Shape count:", mesh_library.get_item_shapes(tile_id).size())	
	if tile_id == -1:
		push_error("Tile '%s' not found in MeshLibrary." % tile_name)
		return

	_generate_floor()


func _generate_floor() -> void:
	for x in range(size_x):
		for z in range(size_z):
			# one level lower than height_y
			set_cell_item(Vector3i(x, height_y - 1, z), tile_id)
