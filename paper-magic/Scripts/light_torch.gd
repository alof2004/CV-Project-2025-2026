extends Node3D

signal torch_lit 

@onready var flame = $Flame 
var is_lit: bool = false

func _ready():
	flame.visible = false 
	
func ignite():
	if is_lit:
		return 	
	is_lit = true
	print("Torch burning") 
	flame.visible = true
	emit_signal("torch_lit")
