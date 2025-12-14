extends Camera3D

@export var player_path: NodePath
@export var parallax_2d_path: NodePath          # CanvasLayer/ParallaxBackground
@export var subviewport_path: NodePath          # SubViewport that renders the 3D scene

# 2D (side) view
@export var height_2d: float = 0
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
var base_z_2d: float = 0.0

var _debug_frame: int = 0


func _ready() -> void:
	print("--- Camera3D READY ---")
	print("  player_path      =", player_path,      " node =", player)
	print("  parallax_2d_path =", parallax_2d_path, " node =", parallax_2d)
	print("  subviewport_path =", subviewport_path, " node =", game_viewport)

	if player == null:
		push_error("Camera: player_path NOT SET")
		return

	current = true
	is_side = true
	base_z_2d = player.global_position.z + distance_z_2d

	# Start in 2D mode
	if player.has_method("set_2d_mode"):
		player.set_2d_mode(true)

	if parallax_2d:
		parallax_2d.visible = true  # 2D parallax ON at start

	if game_viewport:
		# In 2D we want the 3D view transparent so the CanvasLayer parallax shows
		game_viewport.transparent_bg = true

	# Start with 2D FOV
	fov = fov_2d


func _process(delta: float) -> void:
	if player == null:
		return

	# Toggle mode
	if Input.is_action_just_pressed("change_camera"):
		is_side = not is_side
		print("\n=== CHANGE CAMERA pressed, is_side =", is_side, "===")

		if is_side:
			# Entering 2D view: lock Z behind player again
			base_z_2d = player.global_position.z + distance_z_2d

		if player.has_method("set_2d_mode"):
			player.set_2d_mode(is_side)

		# 2D parallax only in side view
		if parallax_2d:
			parallax_2d.visible = is_side

		# SubViewport:
		#   is_side (2D)  -> transparent_bg = true  (see CanvasLayer parallax)
		#   !is_side (3D) -> transparent_bg = false (see 3D skybox)
		if game_viewport:
			game_viewport.transparent_bg = is_side

	# --- follow logic ---
	var p: Vector3 = player.global_position

	var target_pos: Vector3
	if is_side:
		target_pos = Vector3(p.x + x_offset_2d, p.y + height_2d, base_z_2d)
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

	# Smooth position & rotation for BOTH directions
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	rotation = rotation.lerp(target_rot, rotation_speed * delta)

	# Smooth FOV for BOTH directions (2D <-> 3D)
	var target_fov: float = fov_2d if is_side else fov_3d
	fov = lerp(fov, target_fov, rotation_speed * delta)
