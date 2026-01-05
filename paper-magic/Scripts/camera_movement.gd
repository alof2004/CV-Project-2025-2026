extends Camera3D

@export_group("References")
@export var player_path: NodePath
@export var parallax_2d_path: NodePath
@export var subviewport_path: NodePath

@export_group("Collision Settings")
@export_flags_3d_physics var collision_mask: int = 1 
@export var rise_speed: float = 5.0      
@export var max_rise_height: float = 6.0  

@export_group("2D View Settings")
@export var fixed_z_rail: float = 0.0     
@export var height_2d: float = 10.0
@export var distance_z_2d: float = 9.0
@export var x_offset_2d: float = 3.0
@export var fov_2d: float = 55.0
@export var ortho_size_2d: float = 10.0

@export_group("3D View Settings")
@export var height_3d: float = 1.5
@export var side_distance_3d: float = 6.0
@export var min_distance_3d: float = 6.0
@export var fov_3d: float = 70.0

@export_group("Smoothing")
@export var follow_speed: float = 5.0
@export var rotation_speed: float = 5.0

@onready var player: CharacterBody3D = get_node(player_path) as CharacterBody3D
@onready var parallax_2d := get_node_or_null(parallax_2d_path)
@onready var game_viewport: SubViewport = get_node_or_null(subviewport_path) as SubViewport

var is_side: bool = true
var is_ortho_2d: bool = true
var is_ortho_3d: bool = false
var current_extra_height: float = 0.0 

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
	var use_orthographic := is_ortho_2d if is_side else is_ortho_3d
	projection = Camera3D.PROJECTION_ORTHOGONAL if use_orthographic else Camera3D.PROJECTION_PERSPECTIVE
	if use_orthographic:
		size = ortho_size_2d

func _process(delta: float) -> void:
	if player == null:
		return

	if Input.is_action_just_pressed("change_camera"):
		is_side = not is_side
		if player.has_method("set_2d_mode"):
			player.set_2d_mode(is_side)
		if parallax_2d:
			parallax_2d.visible = is_side

		if game_viewport:
			game_viewport.transparent_bg = is_side

	if Input.is_action_just_pressed("change_perspective"):
		if is_side:
			is_ortho_2d = not is_ortho_2d
		else:
			is_ortho_3d = not is_ortho_3d

	var p: Vector3 = player.global_position
	var target_pos: Vector3
	
	if is_side:
		target_pos = Vector3(p.x + x_offset_2d, p.y + height_2d, fixed_z_rail + distance_z_2d)
		current_extra_height = 0.0 
		
	else:
		var dir: Vector3 = Vector3(1.0, 0.0, 0.0)
		var desired_dist: float = maxf(side_distance_3d, min_distance_3d)
		var base_pos = p - dir * desired_dist + Vector3(0.0, height_3d, 0.0)
		var wall_hit = check_wall_collision(p + Vector3(0, 1.5, 0), base_pos)
		
		if wall_hit:
			current_extra_height = lerp(current_extra_height, max_rise_height, rise_speed * delta)
		else:
			current_extra_height = lerp(current_extra_height, 0.0, rise_speed * delta)
		
		target_pos = base_pos + Vector3(0.0, current_extra_height, 0.0)

	var target_rot: Vector3
	if is_side:
		target_rot = Vector3.ZERO
	else:
		var tmp := Transform3D()
		tmp.origin = target_pos
		tmp = tmp.looking_at(p + Vector3(0.0, 1.5, 0.0), Vector3.UP)
		target_rot = tmp.basis.get_euler()

	# --- Apply Smoothing ---
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	rotation = rotation.lerp(target_rot, rotation_speed * delta)

	# --- Apply FOV Smoothing ---
	var target_fov: float = fov_2d if is_side else fov_3d
	fov = lerp(fov, target_fov, rotation_speed * delta)

	# --- Apply Projection ---
	var use_orthographic := is_ortho_2d if is_side else is_ortho_3d
	var target_projection := Camera3D.PROJECTION_ORTHOGONAL if use_orthographic else Camera3D.PROJECTION_PERSPECTIVE
	if projection != target_projection:
		projection = target_projection
	if use_orthographic:
		size = ortho_size_2d

func check_wall_collision(from_pos: Vector3, to_pos: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	
	#exclude the player
	query.exclude = [player.get_rid()]
	query.collision_mask = collision_mask 
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()
