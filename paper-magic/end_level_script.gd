extends Node3D

# Drag your Level Select scene file from the FileSystem into this slot in the Inspector
@export var target_scene : PackedScene 

func _on_area_3d_body_entered(body):
	# 1. Confirm the signal is actually working
	print("DEBUG: Something entered the portal! Body Name: ", body.name)
	
	# Check if the object entering is the Player
	if body.name == "Player" or body.is_in_group("player"):
		print("DEBUG: Success! The object IS the Player.")
		
		if target_scene:
			print("DEBUG: Target scene is assigned. Teleporting now...")
			get_tree().change_scene_to_packed(target_scene)
		else:
			print("ERROR: You forgot to drag the LevelSelect.tscn into the 'Target Scene' slot in the Inspector!")
			
	else:
		# This tells you why it failed
		print("DEBUG: Object ignored. It was not the player.") 
		print("      - Object Name: ", body.name)
		print("      - Object Groups: ", body.get_groups())
