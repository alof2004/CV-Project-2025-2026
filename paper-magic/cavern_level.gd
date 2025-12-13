extends Node3D

# Drag your floor.tscn here in the Inspector
@export var floor_scene: PackedScene 
# Drag your lighted_torch.tscn here in the Inspector
@export var torch_scene: PackedScene

@export var pathway_width: int = 5
@export var torch_spacing: int = 4
@export var number_of_torches: int = 4

func _ready():
	if not floor_scene or not torch_scene:
		print("Error: Please assign the Floor and Torch scenes in the Inspector!")
		return
		
	generate_cavern()

func generate_cavern():
	# Calculate total length based on torches needed
	# We add some padding at the end so the level doesn't stop abruptly at the last torch
	var total_length = (number_of_torches * torch_spacing) + 2
	
	# Loop through Depth (Z axis)
	for z in range(total_length):
		
		# Loop through Width (X axis) to build the floor
		for x in range(-pathway_width / 2, pathway_width / 2 + 1):
			spawn_object(floor_scene, Vector3(x, 0, z))
			
		# LOGIC: Place a torch every 'torch_spacing' blocks
		# We use modulo (%) to check if the current Z is a multiple of 4
		if z > 0 and z % torch_spacing == 0:
			# Only spawn up to the requested amount
			if (z / torch_spacing) <= number_of_torches:
				# Place torch on the left wall (edge of path)
				# We add + 0.5 to y to lift it slightly if needed
				var torch_pos = Vector3(-pathway_width / 2, 1.5, z) 
				spawn_object(torch_scene, torch_pos)

func spawn_object(scene_to_spawn, pos):
	var instance = scene_to_spawn.instantiate()
	add_child(instance)
	instance.position = pos
