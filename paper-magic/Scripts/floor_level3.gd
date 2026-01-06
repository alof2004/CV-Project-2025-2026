extends GridMap

@export var tile_name: String = "Cube"
@export var dirt_tile_name: String = "Cube3"

@export var size_x: int = 40
@export var size_z: int = 5
@export var height_y: int = 0


@export var runway_length: int = 4


@export var gap_start_x: int = 4
@export var gap_end_x: int = 14  


@export var high_ground_start_x: int = 14
@export var high_ground_height: int = 2


@export var lamp_support_enabled: bool = true
@export var lamp_x: int = 2
@export var lamp_z: int = 0

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
	for x in range(size_x):
		for z in range(size_z):

			
			if lamp_support_enabled and x == lamp_x and z == lamp_z:
				_fill_column(x, z, height_y - 1)
				continue

			
			if x >= gap_start_x and x < gap_end_x:
				continue

			
			var floor_y := height_y - 1

			
			if x >= high_ground_start_x:
				floor_y += high_ground_height

			_fill_column(x, z, floor_y)

func _fill_column(x: int, z: int, floor_y: int) -> void:
	for y in range(-5, floor_y + 1):
		if y == floor_y:
			set_cell_item(Vector3i(x, y, -z), tile_id)
		else:
			set_cell_item(Vector3i(x, y, -z), dirt_tile_id)
