extends Button

@export var level_path : String
@export var level_number : int

var original_scale := Vector2(1, 1)
var grow_scale := Vector2(1.1, 1.1)

func _ready():
	# 1. Listen for when the Grid resizes this button
	resized.connect(_on_resized)
	
	# 2. Force an update right now
	_on_resized()
	
	# Connect signals for animation
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)
	pressed.connect(_on_pressed)

# This function runs automatically whenever the button size changes
func _on_resized():
	pivot_offset = size / 2

func _on_hover():
	# Bring to front so it doesn't get covered by neighbors
	z_index = 1
	var tween = create_tween()
	# Use ease_out for a snappier feel
	tween.tween_property(self, "scale", grow_scale, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_exit():
	z_index = 0
	var tween = create_tween()
	tween.tween_property(self, "scale", original_scale, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_pressed():
	if level_path:
		get_tree().change_scene_to_file(level_path)
