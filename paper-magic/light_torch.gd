extends Node3D

@onready var flame = $Flame # Points to the MeshInstance3D you just named "Flame"

func _ready():
	flame.visible = false # Starts unlit

func ignite():
	flame.visible = true # Lights up
