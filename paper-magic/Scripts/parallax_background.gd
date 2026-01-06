extends ParallaxBackground

@export var camera_3d_path: NodePath
@export var parallax_strength: float = 80.0   
@export var parallax_strength_y: float = 20.0 

@onready var cam: Camera3D = get_node_or_null(camera_3d_path)

var last_x: float = 0.0
var last_y: float = 0.0  
var frame_counter: int = 0


func _ready() -> void:
	print("=== PARALLAX READY ===")
	if cam:
		last_x = cam.global_position.x
		last_y = cam.global_position.y 
	else:
		push_error("Parallax: camera_3d_path NOT SET or wrong")


func _process(_delta: float) -> void:
	if cam == null:
		return

	
	if not visible:
		return

	var cam_pos = cam.global_position
	
	
	var dx: float = cam_pos.x - last_x
	var dy: float = cam_pos.y - last_y 

	
	scroll_offset.x += dx * parallax_strength
	scroll_offset.y += dy * parallax_strength_y 

	
	last_x = cam_pos.x
	last_y = cam_pos.y
