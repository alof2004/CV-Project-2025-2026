extends Node3D

# Signal sent to the GridMap when code is correct
signal puzzle_solved

# --- FIX: Load the .tscn file, NOT the .gd file ---
var ui_scene = preload("res://SecretCodeUi.tscn") 

var ui_instance = null
var is_player_near = false
var is_solved = false

# Ensure your Decoder scene actually has a Label3D child named "Label3D"
@onready var prompt_label = $Label3D 

func _ready():
	# Instance the UI and hide it
	if ui_scene:
		ui_instance = ui_scene.instantiate()
		add_child(ui_instance)
		ui_instance.visible = false
		
		# Connect UI signals
		if ui_instance.has_signal("code_success"):
			ui_instance.code_success.connect(_on_success)
		if ui_instance.has_signal("code_closed"):
			ui_instance.code_closed.connect(_on_ui_closed)
	else:
		print("ERROR: Could not load UI scene. Check the filename.")

	# Setup Area detection
	# Ensure your Decoder scene has an Area3D child named "Area3D"
	var area = $Area3D 
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	
	if prompt_label: 
		prompt_label.visible = false

func _input(event):
	if is_player_near and not is_solved and Input.is_action_just_pressed("interact"):
		open_computer()

func open_computer():
	if prompt_label: prompt_label.visible = false
	if ui_instance: ui_instance.open_ui()

func _on_success():
	is_solved = true
	print("Computer: Access Granted. Bridge Activating...")
	emit_signal("puzzle_solved") 
	if prompt_label: prompt_label.text = "ACTIVE"

func _on_ui_closed():
	if is_player_near and not is_solved and prompt_label:
		prompt_label.visible = true

func _on_body_entered(body):
	if body.is_in_group("player") and not is_solved:
		is_player_near = true
		if prompt_label: prompt_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		is_player_near = false
		if prompt_label: prompt_label.visible = false
		if ui_instance: ui_instance.close_ui()
