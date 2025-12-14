extends Camera3D

@export var player_path: NodePath
@export var parallax_2d_path: NodePath
@export var subviewport_path: NodePath

# --- NEW SETTING ---
# This is the "Track" the camera rides on.
# Set this to the center of your level's Z-axis (e.g., 0.0 or -2.0)
@export var fixed_z_rail: float = 0.0 
# -------------------

# 2D (side) view
@export var height_2d: float = 10
@export var distance_z_2d: float = 9.0
@export var x_offset_2d: float = -3.0
@export var fov_2d: float = 55.0

# 3D view (left-side)
@export var height_3d: float = 1.5
@export var side_distance_3d: float = 6.0
@export var min_distance_3d: float = 6.0
@export var fov_3d: float = 80.0

@export var follow_speed: float = 5.0
@export var rotation_speed: float = 5.0

@onready var player: CharacterBody3D = get_node(player_path) as CharacterBody3D
@onready var parallax_2d := get_node_or_null(parallax_2d_path)
@onready var game_viewport: SubViewport = get_node_or_null(subviewport_path) as SubViewport

var is_side: bool = true

func _ready() -> void:
	if player == null:
		push_error("Camera: player_path NOT SET")
		return

	current = true
	is_side = true
	
	# Start in 2D mode
	if player.has_method("set_2d_mode"):
		player.set_2d_mode(true)

	if parallax_2d:
		parallax_2d.visible = true 

	if game_viewport:
		game_viewport.transparent_bg = true

	fov = fov_2d

func _process(delta: float) -> void:
	if player == null:
		return

	# Toggle mode
	if Input.is_action_just_pressed("change_camera"):
		is_side = not is_side
		
		# We don't need to recalculate base_z_2d anymore because 
		# we now use the fixed_z_rail!

		if player.has_method("set_2d_mode"):
			player.set_2d_mode(is_side)

		if parallax_2d:
			parallax_2d.visible = is_side

		if game_viewport:
			game_viewport.transparent_bg = is_side

	# --- follow logic ---
	var p: Vector3 = player.global_position
	var target_pos: Vector3
	
	if is_side:
		# FIX: Use 'fixed_z_rail' instead of player.z
		# This keeps the camera steady even if the player walks deep into the screen.
		target_pos = Vector3(p.x + x_offset_2d, p.y + height_2d, fixed_z_rail + distance_z_2d)
	else:
		var dir: Vector3 = Vector3(1.0, 0.0, 0.0)
		var desired_dist: float = maxf(side_distance_3d, min_distance_3d)
		target_pos = p - dir * desired_dist + Vector3(0.0, height_3d, 0.0)

	var target_rot: Vector3
	if is_side:
		target_rot = Vector3.ZERO
	else:
		var tmp := Transform3D()
		tmp.origin = target_pos
		tmp = tmp.looking_at(p + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		target_rot = tmp.basis.get_euler()

	# Smooth position & rotation
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	rotation = rotation.lerp(target_rot, rotation_speed * delta)

	# Smooth FOV
	var target_fov: float = fov_2d if is_side else fov_3d
	fov = lerp(fov, target_fov, rotation_speed * delta)
