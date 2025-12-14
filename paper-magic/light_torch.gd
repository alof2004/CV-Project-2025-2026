extends Node3D

# 1. NEW: The signal that tells the level "I am burning!"
signal torch_lit 

@onready var flame = $Flame 

# 2. NEW: A flag to make sure we don't count the same torch twice
var is_lit: bool = false

func _ready():
	flame.visible = false 

func ignite():
	# 3. VERIFICATION: If this torch is already lit, stop here.
	if is_lit:
		return 
	
	# 4. Mark it as lit so this code never runs again for this torch
	is_lit = true
	
	print("TORCH IGNITED!") 
	
	# 5. YOUR ORIGINAL LOGIC (Visuals)
	flame.visible = true
	
	# 6. NEW: Send the message to the Level Generator
	emit_signal("torch_lit")
