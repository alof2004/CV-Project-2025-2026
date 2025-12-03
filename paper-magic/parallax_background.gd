extends ParallaxBackground

@export var camera_3d_path: NodePath
@export var parallax_strength: float = 80.0  # tweak this value

@onready var cam: Camera3D = get_node(camera_3d_path)

var last_x: float = 0.0


func _ready() -> void:
	if cam:
		last_x = cam.global_position.x
	else:
		print("ERROR: Camera is NULL (check camera_3d_path!)")


func _process(_delta: float) -> void:
	if cam == null:
		return

	var cam_x: float = cam.global_position.x
	var dx: float = cam_x - last_x

	# multiply to convert world units → screen parallax
	scroll_offset.x += dx * parallax_strength

	last_x = cam_x
