extends Control

@export var level_btn_scene : PackedScene 

# --- FIX: Change Array[PackedScene] to Array[String] ---
# This stores the path "res://Level1.tscn" instead of the scene itself.
# The '*.tscn' part filters the file picker to only show scene files.
@export_file("*.tscn") var all_levels : Array[String] 
# -------------------------------------------------------

@onready var grid = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer

func _ready():
	for i in range(all_levels.size()):
		var btn = level_btn_scene.instantiate()
		
		btn.get_node("Label").text = "Level " + str(i + 1)
		
		# Now we assign the string directly, which is safe!
		if all_levels[i] != "":
			btn.level_path = all_levels[i]
			
		grid.add_child(btn)
