extends Control

signal code_success
signal code_closed

# The secret word to match
const TARGET_CODE = "MAGIC"

@onready var box_container = $HBoxContainer
var current_input = ""

func _ready():
	visible = false # Hide by default

func open_ui():
	visible = true
	current_input = ""
	_update_display()
	# Pause game logic if needed, or just capture input
	set_process_input(true)

func close_ui():
	visible = false
	current_input = ""
	_update_display()
	emit_signal("code_closed")

func _input(event):
	if not visible: return

	if event is InputEventKey and event.pressed:
		
		# 1. Handle Backspace
		if event.keycode == KEY_BACKSPACE:
			if current_input.length() > 0:
				current_input = current_input.left(current_input.length() - 1)
				_update_display()
		
		# 2. Handle Escape (Close)
		elif event.keycode == KEY_ESCAPE:
			close_ui()

		# 3. Handle Typing (A-Z only)
		elif event.keycode >= KEY_A and event.keycode <= KEY_Z:
			if current_input.length() < 5:
				var char_str = OS.get_keycode_string(event.keycode).to_upper()
				current_input += char_str
				_update_display()
				_check_code()

func _update_display():
	# Loop through the 5 panels and set their label text
	for i in range(5):
		var panel = box_container.get_child(i)
		var label = panel.get_child(0) # Assuming Label is the first child
		
		if i < current_input.length():
			label.text = current_input[i]
		else:
			label.text = "" # Empty box

func _check_code():
	if current_input == TARGET_CODE:
		print("CODE CORRECT!")
		emit_signal("code_success")
		close_ui()
	elif current_input.length() == 5:
		# Wrong code visual feedback could go here
		print("Wrong Code")
