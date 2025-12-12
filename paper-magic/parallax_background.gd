extends ParallaxBackground

@export var camera_3d_path: NodePath
@export var parallax_strength: float = 80.0

@onready var cam: Camera3D = get_node_or_null(camera_3d_path)

var last_x: float = 0.0
var frame_counter: int = 0


func _ready() -> void:
	print("=== PARALLAX READY ===")
	print("Parallax node path:", get_path())
	print("camera_3d_path (export):", camera_3d_path)
	print("Camera node:", cam)

	if cam:
		last_x = cam.global_position.x
	else:
		push_error("Parallax: camera_3d_path NOT SET or wrong")

	print("Parallax initial visible =", visible)


func _process(_delta: float) -> void:
	if cam == null:
		return

	frame_counter += 1
	# scroll only if visible
	if not visible:
		return

	var cam_x: float = cam.global_position.x
	var dx: float = cam_x - last_x

	scroll_offset.x += dx * parallax_strength
	last_x = cam_x
