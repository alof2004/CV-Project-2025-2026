extends Node3D

@onready var flame = $Flame 

func _ready():
	flame.visible = false 

func ignite():
	print("TORCH IGNITED!") # Check the 'Output' tab at the bottom of Godot
	flame.visible = true
