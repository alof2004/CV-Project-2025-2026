extends StaticBody3D

@onready var letter_mesh = $LetterMesh

func set_letter(character: String):
	# Check if the node exists and has a TextMesh
	if letter_mesh and letter_mesh.mesh is TextMesh:
		
		# 1. CRITICAL FIX: Make this text resource unique
		# Without this, changing one changes ALL of them to "C"
		letter_mesh.mesh = letter_mesh.mesh.duplicate()
		
		# 2. Set the Text
		letter_mesh.mesh.text = character
		
		# 3. MIRROR THE LETTER
		# If the text appears backwards, scaling X by -1 flips it
		letter_mesh.scale.x = -1 
		
		# OPTIONAL: If it's dark, rotate it 180 instead of scaling
		# letter_mesh.rotation_degrees.y = 180
