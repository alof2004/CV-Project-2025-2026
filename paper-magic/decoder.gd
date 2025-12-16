extends Node3D

# Signal sent to the GridMap when code is correct
signal puzzle_solved

# Ensure this matches your file name exactly in the FileSystem!
var ui_scene = preload("res://SecretCodeUI.tscn") 

var ui_instance = null
var is_player_near = false
var is_solved = false

@onready var prompt_label = $Label3D 

func _ready():
	# Instance the UI and hide it
	if ui_scene:
		ui_instance = ui_scene.instantiate()
		add_child(ui_instance)
		ui_instance.visible = false
		
		if ui_instance.has_signal("code_success"):
			ui_instance.code_success.connect(_on_success)
		if ui_instance.has_signal("code_closed"):
			ui_instance.code_closed.connect(_on_ui_closed)
	else:
		print("ERROR: UI Scene failed to load. Check the file path.")

	# Setup Area detection
	var area = $Area3D 
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	else:
		print("ERROR: Area3D node is missing in Decoder scene.")
	
	if prompt_label: prompt_label.visible = false

func _input(event):
	# "Interact" must match your Input Map exactly (Capital I)
	if is_player_near and not is_solved and Input.is_action_just_pressed("Interact"):
		open_computer()

func open_computer():
	if prompt_label: prompt_label.visible = false
	if ui_instance: ui_instance.open_ui()

func _on_success():
	is_solved = true
	emit_signal("puzzle_solved") 
	if prompt_label: prompt_label.text = "ACTIVE"

func _on_ui_closed():
	if is_player_near and not is_solved and prompt_label:
		prompt_label.visible = true

func _on_body_entered(body):
	# Check if the object has the correct group
	if body.is_in_group("player"):
		if not is_solved:
			is_player_near = true
			if prompt_label: prompt_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		is_player_near = false
		if prompt_label: prompt_label.visible = false
		if ui_instance: ui_instance.close_ui()
