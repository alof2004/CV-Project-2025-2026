extends Button

signal level_chosen(level_path: String)

@export var level_path: String
@export var level_number: int

var original_scale := Vector2(1, 1)
var grow_scale := Vector2(1.1, 1.1)

func _ready() -> void:
	resized.connect(_on_resized)
	_on_resized()

	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)
	pressed.connect(_on_pressed)

func _on_resized() -> void:
	pivot_offset = size / 2

func _on_hover() -> void:
	z_index = 1
	create_tween().tween_property(self, "scale", grow_scale, 0.1)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_exit() -> void:
	z_index = 0
	create_tween().tween_property(self, "scale", original_scale, 0.1)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_pressed() -> void:
	print("Button pressed, level_path =", level_path)
	if level_path != "":
		emit_signal("level_chosen", level_path)
