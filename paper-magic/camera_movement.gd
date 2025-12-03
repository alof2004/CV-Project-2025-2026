extends Camera3D

@export var player_path: NodePath

# --- 2D (front/side) view settings ---
@export var height_2d: float = 0.8      # was 1.5 → lower
@export var distance_z_2d: float = 9.0  # was 10.0 → closer
@export var x_offset_2d: float = -3.0

# --- 3D (left-side) view settings ---
@export var height_3d: float = 1.5          # was 2.0 → lower
@export var side_distance_3d: float = 7.0   # was 10.0 → closer
@export var min_distance_3d: float = 7.0    # keep in sync

@export var follow_speed: float = 6.0
@export var rotation_speed: float = 6.0

@onready var player: CharacterBody3D = get_node(player_path) as CharacterBody3D

var is_side: bool = true
var base_z_2d: float = 0.0

func _ready() -> void:
	if player == null:
		return
	current = true
	is_side = true
	base_z_2d = player.global_position.z + distance_z_2d
	if player.has_method("set_2d_mode"):
		player.set_2d_mode(true)

func _process(delta: float) -> void:
	if player == null:
		return

	if Input.is_action_just_pressed("change_camera"):
		is_side = not is_side
		if is_side:
			base_z_2d = player.global_position.z + distance_z_2d
		if player.has_method("set_2d_mode"):
			player.set_2d_mode(is_side)

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

	global_position = global_position.lerp(target_pos, follow_speed * delta)
	rotation = rotation.lerp(target_rot, rotation_speed * delta)
