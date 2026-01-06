@tool
extends GridMap


@export_group("Terrain")
@export var tile_name: String = "Cube"
@export var dirt_tile_name: String = "Cube3"
@export var size_x: int = 85 
@export var size_z: int = 5
@export var height_y: int = 0   

@export_group("Puzzle Logic")
@export var platform_scene: PackedScene      
@export var wall_scene: PackedScene 
@export var bush_scene: PackedScene
@export var tree_scene: PackedScene    
@export var bridge_scene: PackedScene 
@export var computer_scene: PackedScene 

@export_group("Vegetation")
@export var grass_scene: PackedScene

@export_group("Gate Settings")
@export var gate_scene: PackedScene
@export var gate_y_offset: float = 0.5 
@export var gate_scale_mult: Vector3 = Vector3(1.0, 1.0, 1.0) 

@export_group("Randomness")
@export_tool_button("Re-Roll Seed") var reroll_action = func(): 
	if Engine.is_editor_hint(): 
		generation_seed = 0
		_ready() 
		notify_property_list_changed()

@export var generation_seed: int = 0 


var platform_start_x: float = 60.0
var platform_spacing: float = 1.0

var abyss_start_index: int = 0
var abyss_end_index: int = 0

var tile_id: int = 0
var dirt_tile_id: int = 0
const PASSWORD_LETTERS = ["M", "A", "G", "I", "C"]

var noise = FastNoiseLite.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		if platform_scene == null or wall_scene == null or bush_scene == null:
			return

	clear()
	
	
	for child in get_children():
		
		if child.name.begins_with("Platform_") or child.name.begins_with("Wall_") or \
		   child.name.begins_with("Bush_") or child.name.begins_with("Gate_") or \
		   child.name.begins_with("Bridge_") or child.name.begins_with("Tree_") or \
		   child.name.begins_with("Grass_") or child.name.begins_with("Computer_"):
			child.queue_free()

	if platform_scene == null:
		if ResourceLoader.exists("res://Letter_island.tscn"):
			platform_scene = load("res://Letter_island.tscn")

	var lib := mesh_library
	if lib == null: return

	tile_id = lib.find_item_by_name(tile_name)
	dirt_tile_id = lib.find_item_by_name(dirt_tile_name)
	
	
	var current_seed = 0
	if generation_seed == 0:
		randomize()
		current_seed = randi()
	else:
		current_seed = generation_seed
	
	seed(current_seed)
	noise.seed = current_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.2
	
	print("--- GENERATING WITH SEED: ", current_seed, " ---")

	
	var start_coords = local_to_map(Vector3(platform_start_x, 0, 0))
	var end_coords = local_to_map(Vector3(platform_start_x + (PASSWORD_LETTERS.size() * platform_spacing), 0, 0))
	
	abyss_start_index = start_coords.x - 1
	abyss_end_index = end_coords.x + 1

	
	_generate_floor()
	
	if Engine.is_editor_hint():
		
		_spawn_magic_platforms()
		_spawn_bridges(false) 
		_spawn_starting_walls()
		_spawn_gates()
		_spawn_computer()
		_spawn_trees()
		_spawn_bushes()
		_spawn_grass()
	else:
		
		call_deferred("_spawn_magic_platforms")
		call_deferred("_spawn_bridges", true) 
		call_deferred("_spawn_starting_walls")
		call_deferred("_spawn_gates")
		call_deferred("_spawn_computer")
		call_deferred("_spawn_trees")
		call_deferred("_spawn_bushes")
		call_deferred("_spawn_grass")

func _generate_floor() -> void:
	for x in range(size_x):
		if x >= abyss_start_index and x <= abyss_end_index: 
			continue 
		
		var current_floor_y = height_y - 1
			
		for z in range(size_z):
			for y in range(-5, current_floor_y + 1):
				var tid = tile_id if y == current_floor_y else dirt_tile_id
				set_cell_item(Vector3i(x, y, -z), tid)


func _spawn_computer():
	if computer_scene == null: 
		print("Computer Scene not assigned!")
		return
	
	var c = computer_scene.instantiate()
	c.name = "Computer_Decoder"
	add_child(c)
	
	
	
	
	var x_pos = abyss_start_index - 1
	
	
	
	var z_pos = -3
	
	var grid_pos = Vector3i(x_pos, height_y, z_pos)
	var world_pos = map_to_local(grid_pos)
	
	
	world_pos.y -= 1
	
	c.position = world_pos
	
	c.rotation_degrees.y = -90.0
	
	
	
	if c.has_signal("puzzle_solved"):
		c.puzzle_solved.connect(_on_puzzle_solved)

func _on_puzzle_solved():
	print("GridMap: Puzzle Solved! Revealing Bridge...")
	
	for child in get_children():
		if child.name.begins_with("Bridge_"):
			child.visible = true
			child.process_mode = Node.PROCESS_MODE_INHERIT



func _spawn_bridges(start_hidden: bool = false):
	if bridge_scene == null:
		print("Bridge Scene not assigned!")
		return
		
	print("--- SPAWNING BRIDGES ---")
	
	for x in range(abyss_start_index, abyss_end_index + 1):
		var b = bridge_scene.instantiate()
		b.name = "Bridge_" + str(x)
		add_child(b)
		
		
		if start_hidden:
			b.visible = false
			b.process_mode = Node.PROCESS_MODE_DISABLED
		
		var center_z = -2
		var grid_pos = Vector3i(x, height_y, center_z)
		var world_pos = map_to_local(grid_pos)
		
		world_pos.y -= 1
		
		b.position = world_pos 
		b.rotation_degrees.y = 90.0
		b.scale = Vector3(5.0, 3.0, 3.0)



func _spawn_grass():
	if grass_scene == null: return
	var grass_count = 0
	var wall_gap_idx = local_to_map(Vector3(15.0, 0, 0)).x
	var wall_big_idx = local_to_map(Vector3(25.0, 0, 0)).x
	var wall_last_idx = local_to_map(Vector3(35.0, 0, 0)).x
	for x in range(size_x):
		for z in range(size_z):
			if x >= (abyss_start_index - 2) and x <= (abyss_end_index + 2): continue
			if x >= wall_gap_idx - 2 and x <= wall_gap_idx + 2: continue 
			if x >= wall_big_idx - 2 and x <= wall_big_idx + 2: continue
			if x >= wall_last_idx - 2 and x <= wall_last_idx + 2: continue
			if x <= 2: continue 
			if x >= size_x - 3: continue
			var noise_val = noise.get_noise_2d(x, z * 10) 
			if noise_val > -0.3:
				if randf() > 0.3: 
					var g = grass_scene.instantiate()
					g.name = "Grass_" + str(x) + "_" + str(z)
					add_child(g)
					var grid_pos = Vector3i(x, height_y, -z)
					var world_pos = map_to_local(grid_pos)

					
					
					g.global_position = Vector3(world_pos.x, world_pos.y -1, world_pos.z)

					g.rotation_degrees.y = randf_range(0, 360)
					var scale_mod = randf_range(0.8, 1.3)
					g.scale = Vector3(scale_mod, scale_mod, scale_mod)
					grass_count += 1
	print("--- SPAWNED ", grass_count, " GRASS ---")

func _spawn_trees():
	if tree_scene == null: return
	var tree_count = 0
	
	
	var wall_gap_idx = local_to_map(Vector3(15.0, 0, 0)).x
	var wall_big_idx = local_to_map(Vector3(25.0, 0, 0)).x
	var wall_last_idx = local_to_map(Vector3(35.0, 0, 0)).x
	
	for x in range(size_x):
		for z in range(size_z):
			
			if x <= wall_gap_idx + 2: continue 

			
			if x >= (abyss_start_index - 2) and x <= (abyss_end_index + 2): continue
			
			
			if x >= wall_big_idx - 2 and x <= wall_big_idx + 2: continue
			if x >= wall_last_idx - 2 and x <= wall_last_idx + 2: continue
			if x >= size_x - 3: continue

			var noise_val = noise.get_noise_2d(x, z * 10) 
			if noise_val > 0.15:
				if randf() > 0.75: 
					var t = tree_scene.instantiate()
					t.name = "Tree_" + str(x) + "_" + str(z)
					add_child(t)
					var grid_pos = Vector3i(x, height_y, -z)
					var world_pos = map_to_local(grid_pos)
					t.global_position = Vector3(world_pos.x, float(height_y) + 0.1, world_pos.z)
					t.rotation_degrees.y = randf_range(0, 360)
					var scale_mod = randf_range(2.5, 4.0)
					t.scale = Vector3(scale_mod, scale_mod, scale_mod)
					tree_count += 1
	print("--- SPAWNED ", tree_count, " TREES ---")

func _spawn_bushes():
	if bush_scene == null: return
	var bush_count = 0
	
	
	var wall_gap_idx = local_to_map(Vector3(15.0, 0, 0)).x
	var wall_big_idx = local_to_map(Vector3(25.0, 0, 0)).x
	var wall_last_idx = local_to_map(Vector3(35.0, 0, 0)).x
	
	for x in range(size_x):
		for z in range(size_z):
			
			if x <= wall_gap_idx + 2: continue

			
			if x >= (abyss_start_index - 2) and x <= (abyss_end_index + 2): continue
			
			
			if x >= wall_big_idx - 2 and x <= wall_big_idx + 2: continue
			if x >= wall_last_idx - 2 and x <= wall_last_idx + 2: continue
			if x >= size_x - 3: continue

			var noise_val = noise.get_noise_2d(x, z * 10) 
			if noise_val > -0.1:
				if randf() > 0.4: 
					var bush = bush_scene.instantiate()
					bush.name = "Bush_" + str(x) + "_" + str(z)
					add_child(bush)
					var grid_pos = Vector3i(x, height_y, -z)
					var world_pos = map_to_local(grid_pos)
					bush.global_position = Vector3(world_pos.x, float(height_y) + 0.1, world_pos.z)
					bush.rotation_degrees.y = randf_range(0, 360)
					var scale_mod = randf_range(0.8, 1.2)
					bush.scale = Vector3(scale_mod, scale_mod, scale_mod)
					bush_count += 1
	print("--- SPAWNED ", bush_count, " BUSHES ---")

func _spawn_gates():
	spawn_gate(0, -2, 90.0, "Gate_Start")
	spawn_gate(size_x - 1, -2, -90.0, "Gate_End")

func spawn_gate(x: int, z: int, rotation_deg: float, gate_name: String):
	if gate_scene == null: return
	var g = gate_scene.instantiate()
	g.name = gate_name
	add_child(g)
	var grid_pos = Vector3i(x, height_y, z) 
	var world_pos = map_to_local(grid_pos)
	world_pos.y -= gate_y_offset
	g.position = world_pos
	g.rotation_degrees.y = rotation_deg + 90.0
	if ResourceLoader.exists("res://LevelSelect.tscn"):
		var manual_scene = load("res://LevelSelect.tscn")
		if "target_scene" in g: g.target_scene = manual_scene
	for child in g.get_children():
		if child is Node3D:
			child.scale = gate_scale_mult
			child.position *= gate_scale_mult

func _spawn_magic_platforms():
	if platform_scene == null: return
	seed(noise.seed + 100)
	for i in range(PASSWORD_LETTERS.size()):
		var letter = PASSWORD_LETTERS[i]
		var platform = platform_scene.instantiate()
		platform.name = "Platform_" + letter
		add_child(platform)
		var pos_x = platform_start_x + (i * platform_spacing) + randf_range(0.0, 1.0)
		var pos_y = 4.0 + randf_range(-2.0, 2.0)
		var pos_z = randf_range(0.0, -5.0)
		platform.global_position = Vector3(pos_x, pos_y, pos_z)
		platform.rotation_degrees.y = 180.0 + randf_range(-5.0, 5.0)
		if not platform.is_in_group("wand_target"): platform.add_to_group("wand_target")
		if platform.has_method("set_letter"): platform.set_letter(letter)

func _spawn_starting_walls():
	if wall_scene == null: return
	var gap_x = 15.0
	var w1 = wall_scene.instantiate()
	add_child(w1)
	w1.scale = Vector3(2.0, 2.0, 2.0) 
	w1.global_position = Vector3(gap_x, float(height_y), 0.5)
	w1.rotation_degrees.y = 90.0
	var w2 = wall_scene.instantiate()
	add_child(w2)
	w2.scale = Vector3(2.0, 2.0, 2.0) 
	w2.global_position = Vector3(gap_x, float(height_y), -5.5)
	w2.rotation_degrees.y = 90.0
	var big_x = 25.0
	var w3 = wall_scene.instantiate()
	add_child(w3)
	w3.scale = Vector3(4.0, 2.0, 2.0)
	w3.global_position = Vector3(big_x, float(height_y), -1)
	w3.rotation_degrees.y = 90.0
	var last_x = 35.0
	var w4 = wall_scene.instantiate()
	add_child(w4)
	w4.scale = Vector3(4.8, 2.0, 2.0)
	w4.global_position = Vector3(last_x, float(height_y), -2)
	w4.rotation_degrees.y = 90.0
