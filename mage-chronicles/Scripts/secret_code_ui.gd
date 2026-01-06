extends Control

signal code_success
signal code_closed


const TARGET_CODE = "MAGIC"

@onready var box_container = $HBoxContainer


var current_input = "" 

func _ready():
	visible = false 

func open_ui():
	visible = true
	current_input = ""
	_update_display()
	set_process_input(true)

func close_ui():
	visible = false
	current_input = ""
	_update_display()
	emit_signal("code_closed")

func _input(event):
	if not visible: return

	if event is InputEventKey and event.pressed:
		var key_was_used = false
		
		
		if event.keycode == KEY_BACKSPACE:
			if current_input.length() > 0:
				current_input = current_input.left(current_input.length() - 1)
				_update_display()
			key_was_used = true
		
		
		elif event.keycode == KEY_ESCAPE:
			close_ui()
			key_was_used = true

		
		elif event.keycode >= KEY_A and event.keycode <= KEY_Z:
			if current_input.length() < 5:
				var char_str = OS.get_keycode_string(event.keycode).to_upper()
				current_input += char_str
				_update_display()
				_check_code()
			key_was_used = true

		
		
		if key_was_used:
			accept_event()

func _update_display():
	
	if box_container:
		for i in range(5):
			if i < box_container.get_child_count():
				var panel = box_container.get_child(i)
				var label = panel.get_child(0) 
				
				if i < current_input.length():
					label.text = current_input[i]
				else:
					label.text = "" 

func _check_code():
	if current_input == TARGET_CODE:
		print("CODE CORRECT!")
		emit_signal("code_success")
		close_ui()
	elif current_input.length() == 5:
		print("Wrong Code")
		
