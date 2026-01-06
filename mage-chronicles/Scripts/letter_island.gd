extends StaticBody3D

@onready var letter_mesh = $LetterMesh

func set_letter(character: String):
	
	if letter_mesh and letter_mesh.mesh is TextMesh:
		
		
		
		letter_mesh.mesh = letter_mesh.mesh.duplicate()
		
		
		letter_mesh.mesh.text = character
		
		
		
		letter_mesh.scale.x = -1 
		
		
		
