extends Control

@export var level_btn_scene : PackedScene 
# This line creates a list in the Inspector
@export var all_levels : Array[PackedScene] 

@onready var grid = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer

func _ready():
	# Loop through your Array of levels
	for i in range(all_levels.size()):
		var btn = level_btn_scene.instantiate()
		
		# --- CHANGE THIS LINE ---
		# Old: btn.get_node("Label").text = str(i + 1)
		
		# New: Add "Level " + the number
		btn.get_node("Label").text = "Level " + str(i + 1)
		# ------------------------
		
		# Assign the scene path from the array
		if all_levels[i]:
			btn.level_path = all_levels[i].resource_path
			
		grid.add_child(btn)
