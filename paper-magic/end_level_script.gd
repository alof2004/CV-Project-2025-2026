extends Node3D

@export var target_scene : PackedScene 

func _on_area_3d_body_entered(body):
	print("--- DEBUG START ---")
	print("Body Name: ", body.name)
	print("Groups Found: ", body.get_groups()) # <--- This will likely be [] (empty)
	print(target_scene)
	# Check for "player" (lowercase) specifically
	if body.is_in_group("player"):
		print("RESULT: SUCCESS! Teleporting...")
		if target_scene:
			print("DEBUG: Teleporting (Deferred)...")
			# OLD WAY (Unsafe in physics callbacks)
			# get_tree().change_scene_to_packed(target_scene)
			
			# NEW WAY (Safe!)
			get_tree().call_deferred("change_scene_to_packed", target_scene)
		else:
			print("target scene")
	else:
		print("RESULT: FAIL. This object is NOT in the 'player' group.")
	print("--- DEBUG END ---")
