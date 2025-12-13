# Wand.gd
extends Node3D

# --------------------------------------------------------------------
# NODES
# --------------------------------------------------------------------
@export var wand_ray_path: NodePath
@export var magic_particles_path: NodePath   # GPUParticles3D
@export var player_path: NodePath            # Player, used to read is_2d (optional)
@export var camera_path: NodePath            # Optional: assign a Camera3D manually
@export var mouse_pick_radius_px: float = 120.0
@export var debug_camera: bool = false

@onready var cam: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var wand_ray: RayCast3D = get_node(wand_ray_path) as RayCast3D
@onready var wand_magic: GPUParticles3D = get_node(magic_particles_path) as GPUParticles3D
@onready var player: Node = get_node_or_null(player_path)

# --------------------------------------------------------------------
# SELECTION / TRANSFORM
# --------------------------------------------------------------------
@export var selection_radius: float = 7.0
@export var rotate_anim_time: float = 0.2
@export var move_speed: float = 4.0
@export var max_grab_distance: float = 15.0

@export var scale_speed: float = 1.0
@export var min_scale: float = 0.5
@export var max_scale: float = 2.0

# --------------------------------------------------------------------
# FLOOR / GROUND (dynamic)
# --------------------------------------------------------------------
@export var floor_height: float = 2.0        # fallback if ray doesn't hit anything
@export var floor_offset: float = 0.0
@export var ground_ray_length: float = 80.0  # how far down we search for "ground"
@export var ground_ray_start_offset: float = 0.2 # IMPORTANT: start ray near object center so it won't hit player on top

# --------------------------------------------------------------------
# AURA
# --------------------------------------------------------------------
@export var aura_max_alpha: float = 0.4
@export var aura_fade_time: float = 0.2

# --------------------------------------------------------------------
# BEAM
# --------------------------------------------------------------------
@export var beam_amount: int = 3000
@export var beam_max_length: float = 90.0
@export var beam_thickness: float = 0.15
@export var beam_lifetime: float = 0.05

const TARGET_GROUP := "wand_target"
const AURA_NAME := "SelectionAura"
const ROTATE_STEP := PI * 0.5

# tiny lift for horizontal collision checks so floor contact doesn't block X/Z
const HORIZ_EPS := 0.02

# how fine we "slide" when moving down into contact
const DOWN_SOLVE_STEPS := 10

# --------------------------------------------------------------------
# State
# --------------------------------------------------------------------
var magic_mat: ParticleProcessMaterial = null
var hovered: Node3D = null
var grabbed: Node3D = null

var aura_tweens: Dictionary = {}
var rotate_tween: Tween = null
var frame_counter: int = 0


# ====================================================================
# Helpers: Aura material & mesh
# ====================================================================
func _get_aura_material(aura: MeshInstance3D) -> StandardMaterial3D:
	var mat: Material = aura.get_surface_override_material(0)
	if mat == null:
		mat = aura.material_override
	if mat == null:
		mat = aura.get_active_material(0)
	if mat == null:
		return null

	if not mat.resource_local_to_scene:
		mat = mat.duplicate()
		mat.resource_local_to_scene = true
		aura.material_override = mat

	return mat as StandardMaterial3D


func _get_visual_mesh(root: Node3D) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


# ====================================================================
# Helpers: Camera & mouse (SubViewport safe)
# ====================================================================
func _get_subviewport_camera() -> Camera3D:
	var root: Node = get_tree().current_scene
	if root == null:
		if debug_camera: print("[WAND][CAM] current_scene is null")
		return null

	var sv: SubViewport = root.get_node_or_null("SubViewportContainer/SubViewport") as SubViewport
	if sv == null:
		if debug_camera: print("[WAND][CAM] SubViewport NOT found at SubViewportContainer/SubViewport")
		return null

	return sv.get_node_or_null("Camera3D") as Camera3D


func _get_active_camera() -> Camera3D:
	var c: Camera3D = cam
	if c == null:
		c = _get_subviewport_camera()
	if c == null:
		c = get_viewport().get_camera_3d()
	return c


func _get_mouse_pos_for_camera(camera: Camera3D) -> Vector2:
	var root: Node = get_tree().current_scene
	if root == null or camera == null:
		return get_viewport().get_mouse_position()

	var sv: SubViewport = root.get_node_or_null("SubViewportContainer/SubViewport") as SubViewport
	var svc: SubViewportContainer = root.get_node_or_null("SubViewportContainer") as SubViewportContainer
	if sv == null or svc == null:
		return get_viewport().get_mouse_position()

	if camera.get_viewport() != sv:
		return get_viewport().get_mouse_position()

	var m_local: Vector2 = svc.get_local_mouse_position()
	var c_size: Vector2 = svc.size
	var sv_size: Vector2 = sv.size

	if c_size.x > 0.0 and c_size.y > 0.0:
		return Vector2(
			m_local.x * (sv_size.x / c_size.x),
			m_local.y * (sv_size.y / c_size.y)
		)

	return m_local


# ====================================================================
# Helpers: Collision queries
# ====================================================================
func _find_collision_shape(n: Node) -> CollisionShape3D:
	var cs: CollisionShape3D = n.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null and cs.shape != null:
		return cs
	for c in n.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
			return c as CollisionShape3D
	return null


func _intersect_shape_with_transform(grabbed_node: Node3D, cs: CollisionShape3D, xf: Transform3D) -> bool:
	if cs == null or cs.shape == null:
		return false

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cs.shape
	q.transform = xf

	if grabbed_node is CollisionObject3D:
		q.exclude = [ (grabbed_node as CollisionObject3D).get_rid() ]
		q.collision_mask = (grabbed_node as CollisionObject3D).collision_mask
	else:
		q.collision_mask = 0xFFFFFFFF

	return space.intersect_shape(q, 1).size() > 0


func _would_collide(grabbed_node: Node3D, cs: CollisionShape3D, motion: Vector3, extra_offset: Vector3 = Vector3.ZERO) -> bool:
	if cs == null or cs.shape == null:
		return false
	var xf: Transform3D = cs.global_transform
	xf.origin += motion + extra_offset
	return _intersect_shape_with_transform(grabbed_node, cs, xf)


# Try to move as much as possible along a motion vector without colliding.
func _apply_motion_safely(grabbed_node: Node3D, cs: CollisionShape3D, motion: Vector3, extra_offset: Vector3 = Vector3.ZERO, steps: int = 8) -> Vector3:
	if motion == Vector3.ZERO:
		return Vector3.ZERO
	if cs == null or cs.shape == null:
		return motion

	if not _would_collide(grabbed_node, cs, motion, extra_offset):
		return motion

	var lo: float = 0.0
	var hi: float = 1.0
	for _i in range(steps):
		var mid: float = (lo + hi) * 0.5
		var test: Vector3 = motion * mid
		if _would_collide(grabbed_node, cs, test, extra_offset):
			hi = mid
		else:
			lo = mid
	return motion * lo


# ====================================================================
# Helpers: Dynamic ground height under object (won't hit player on top)
# ====================================================================
func _get_ground_y_under(node: Node3D) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	# Start near the object's center (NOT above it), then ray down.
	# This avoids the ray hitting the player/objects standing on top.
	var from: Vector3 = node.global_transform.origin + Vector3(0.0, ground_ray_start_offset, 0.0)
	var to: Vector3 = from - Vector3(0.0, ground_ray_length, 0.0)

	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)

	var excludes: Array[RID] = []
	if node is CollisionObject3D:
		excludes.append((node as CollisionObject3D).get_rid())
	if player is CollisionObject3D:
		excludes.append((player as CollisionObject3D).get_rid())
	q.exclude = excludes

	# Use world mask by default
	q.collision_mask = 0xFFFFFFFF

	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty() and hit.has("position"):
		var p: Vector3 = hit["position"] as Vector3
		return p.y

	return floor_height


# ====================================================================
# Aura + Beam init
# ====================================================================
func _ready() -> void:
	if wand_ray == null:
		push_error("[WAND] wand_ray is NULL (bad path?)")
		return
	wand_ray.enabled = true

	if wand_magic == null:
		push_error("[WAND] wand_magic is NULL (bad path?)")
		return

	magic_mat = wand_magic.process_material as ParticleProcessMaterial
	if magic_mat == null:
		push_error("[WAND] WandMagic has no ParticleProcessMaterial")
		return

	magic_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	magic_mat.emission_box_extents = Vector3(beam_thickness, beam_thickness, 0.5)
	magic_mat.initial_velocity_min = 0.0
	magic_mat.initial_velocity_max = 0.0
	magic_mat.gravity = Vector3.ZERO
	magic_mat.spread = 180.0

	wand_magic.local_coords = false
	wand_magic.amount = beam_amount
	wand_magic.emitting = false
	wand_magic.lifetime = beam_lifetime
	wand_magic.preprocess = beam_lifetime

	var aabb: AABB = AABB()
	aabb.position = Vector3(-beam_max_length * 0.5, -beam_max_length * 0.5, -beam_max_length * 0.5)
	aabb.size = Vector3(beam_max_length, beam_max_length, beam_max_length)
	wand_magic.visibility_aabb = aabb

	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node is Node3D:
			var aura: MeshInstance3D = (node as Node3D).get_node_or_null(AURA_NAME) as MeshInstance3D
			if aura:
				var mat: StandardMaterial3D = _get_aura_material(aura)
				if mat:
					var c: Color = mat.albedo_color
					c.a = 0.0
					mat.albedo_color = c
				aura.visible = false


# ====================================================================
# Rotation input
# ====================================================================
func _input(event: InputEvent) -> void:
	if grabbed == null:
		return
	if event.is_action_pressed("wand_rotate_l"):
		_start_rotation_tween(-1)
	elif event.is_action_pressed("wand_rotate_r"):
		_start_rotation_tween(1)


func _start_rotation_tween(dir: int) -> void:
	if grabbed == null:
		return
	if rotate_tween and rotate_tween.is_valid():
		rotate_tween.kill()
		rotate_tween = null

	var target_rot: Vector3 = grabbed.rotation_degrees
	target_rot.y += rad_to_deg(ROTATE_STEP) * dir

	rotate_tween = get_tree().create_tween()
	rotate_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rotate_tween.tween_property(grabbed, "rotation_degrees", target_rot, rotate_anim_time)


# ====================================================================
# Main loop
# ====================================================================
func _physics_process(delta: float) -> void:
	frame_counter += 1

	_update_hover()

	if Input.is_action_just_pressed("wand_grab"):
		_toggle_select()

	if grabbed:
		_update_move(delta)
		_update_scale(delta)
		_check_player_distance()

	_update_magic_beam(grabbed)


func _check_player_distance() -> void:
	if grabbed == null:
		return

	var ref_pos: Vector3
	var player_node: Node3D = player as Node3D
	if player_node != null:
		ref_pos = player_node.global_transform.origin
	else:
		ref_pos = global_transform.origin

	if ref_pos.distance_to(grabbed.global_transform.origin) > max_grab_distance:
		_force_deselect()


func _force_deselect() -> void:
	if grabbed == null:
		return

	if rotate_tween and rotate_tween.is_valid():
		rotate_tween.kill()
		rotate_tween = null

	_set_aura_visible(grabbed, false)

	if grabbed is RigidBody3D:
		(grabbed as RigidBody3D).freeze = false

	grabbed = null
	_update_magic_beam(null)


# ====================================================================
# Hover + selection
# ====================================================================
func _update_hover() -> void:
	var camera: Camera3D = _get_active_camera()
	if camera == null:
		hovered = null
		return

	var mouse_pos: Vector2 = _get_mouse_pos_for_camera(camera)
	var wand_pos: Vector3 = wand_ray.global_transform.origin

	var new_hover: Node3D = null
	var best_px: float = mouse_pick_radius_px

	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if not (node is Node3D):
			continue
		var n: Node3D = node as Node3D
		var world_pos: Vector3 = n.global_transform.origin

		if (world_pos - wand_pos).length() > selection_radius:
			continue
		if camera.is_position_behind(world_pos):
			continue

		var screen_pos: Vector2 = camera.unproject_position(world_pos)
		var d_px: float = screen_pos.distance_to(mouse_pos)

		if d_px < best_px:
			best_px = d_px
			new_hover = n

	hovered = new_hover


func _toggle_select() -> void:
	if grabbed and hovered == grabbed:
		_force_deselect()
		return

	if hovered == null and grabbed:
		_force_deselect()
		return

	if hovered:
		if grabbed and grabbed != hovered:
			_force_deselect()

		grabbed = hovered
		if grabbed is RigidBody3D:
			(grabbed as RigidBody3D).freeze = true
		_set_aura_visible(grabbed, true)


# ====================================================================
# Aura
# ====================================================================
func _set_aura_visible(target: Node3D, visible: bool) -> void:
	if target == null:
		return

	var aura: MeshInstance3D = target.get_node_or_null(AURA_NAME) as MeshInstance3D
	if aura == null:
		return

	var mat: StandardMaterial3D = _get_aura_material(aura)
	if mat == null:
		return

	if aura_tweens.has(aura):
		var old_tween: Tween = aura_tweens[aura] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		aura_tweens.erase(aura)

	var to_col: Color = mat.albedo_color
	to_col.a = aura_max_alpha if visible else 0.0

	aura.visible = true

	var duration: float = aura_fade_time
	if not visible:
		duration *= 0.4

	var tw: Tween = get_tree().create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", to_col, duration)

	if not visible:
		tw.tween_callback(Callable(aura, "set_visible").bind(false))

	aura_tweens[aura] = tw


# ====================================================================
# Bottom helper
# ====================================================================
func _get_bottom_y(node: Node3D) -> float:
	var mesh: MeshInstance3D = _get_visual_mesh(node)
	if mesh == null:
		return node.global_position.y
	var aabb: AABB = mesh.get_aabb()
	var local_bottom: Vector3 = aabb.position + Vector3(aabb.size.x * 0.5, 0.0, aabb.size.z * 0.5)
	var global_bottom: Vector3 = mesh.global_transform * local_bottom
	return global_bottom.y


# ====================================================================
# MOVE
# ====================================================================
func _update_move(delta: float) -> void:
	if grabbed == null:
		return

	var is_2d_mode: bool = false
	if player:
		var v: Variant = player.get("is_2d")
		if typeof(v) == TYPE_BOOL:
			is_2d_mode = v as bool

	# Horizontal input
	var input_dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_object_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_object_right"):
		input_dir.x += 1.0
	if not is_2d_mode:
		if Input.is_action_pressed("move_object_up"):
			input_dir.y += 1.0
		if Input.is_action_pressed("move_object_down"):
			input_dir.y -= 1.0
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Vertical input (optional)
	var y_dir: float = 0.0
	if Input.is_action_pressed("move_object_y_up"):
		y_dir += 1.0
	if Input.is_action_pressed("move_object_y_down"):
		y_dir -= 1.0

	if input_dir == Vector2.ZERO and y_dir == 0.0:
		return

	# Build camera-relative X/Z
	var move_dir: Vector3 = Vector3.ZERO
	if is_2d_mode:
		move_dir = Vector3(input_dir.x, 0.0, 0.0)
	else:
		var cam_ref: Camera3D = _get_active_camera()
		if cam_ref:
			var basis: Basis = cam_ref.global_transform.basis
			var forward: Vector3 = -basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var right: Vector3 = basis.x
			right.y = 0.0
			right = right.normalized()
			move_dir = right * input_dir.x + forward * input_dir.y
			if move_dir.length() > 0.0:
				move_dir = move_dir.normalized()
		else:
			move_dir = Vector3(input_dir.x, 0.0, input_dir.y)

	var cs: CollisionShape3D = _find_collision_shape(grabbed)

	# Horizontal (slide: try full, then x, then z)
	var horiz: Vector3 = move_dir * move_speed * delta
	if horiz != Vector3.ZERO:
		var applied: Vector3 = _apply_motion_safely(grabbed, cs, horiz, Vector3(0.0, HORIZ_EPS, 0.0), 6)
		if applied == Vector3.ZERO:
			var hx: Vector3 = Vector3(horiz.x, 0.0, 0.0)
			var hz: Vector3 = Vector3(0.0, 0.0, horiz.z)
			var ax: Vector3 = _apply_motion_safely(grabbed, cs, hx, Vector3(0.0, HORIZ_EPS, 0.0), 6)
			var az: Vector3 = _apply_motion_safely(grabbed, cs, hz, Vector3(0.0, HORIZ_EPS, 0.0), 6)
			grabbed.global_position += ax + az
		else:
			grabbed.global_position += applied

	# Vertical
	if y_dir != 0.0:
		var vert: Vector3 = Vector3(0.0, y_dir * move_speed * delta, 0.0)
		var vsteps: int = DOWN_SOLVE_STEPS if y_dir < 0.0 else 6
		var applied_v: Vector3 = _apply_motion_safely(grabbed, cs, vert, Vector3.ZERO, vsteps)
		grabbed.global_position += applied_v

	# Clamp to ground only when moving down or not moving Y
	if y_dir <= 0.0:
		var ground_y: float = _get_ground_y_under(grabbed) + floor_offset
		var bottom_y: float = _get_bottom_y(grabbed)
		if bottom_y < ground_y:
			grabbed.global_position.y += (ground_y - bottom_y)


# ====================================================================
# SCALE
# - DO NOT push the object upward to "make room" for other objects/player.
# - Only anchor bottom to the ground under it (GridMap / object beneath).
# - If the player is on top, scaling will not auto-lift the object.
# ====================================================================
func _update_scale(delta: float) -> void:
	if grabbed == null:
		return

	var mesh: MeshInstance3D = _get_visual_mesh(grabbed)
	if mesh == null:
		return

	var cs: CollisionShape3D = _find_collision_shape(grabbed)

	# Bottom target is just the supporting surface under it (won't hit player on top anymore)
	var ground_y: float = _get_ground_y_under(grabbed) + floor_offset
	var current_bottom: float = maxf(_get_bottom_y(grabbed), ground_y)

	var old_s: Vector3 = mesh.scale
	var new_s: Vector3 = old_s

	if Input.is_action_pressed("wand_scale_up"):
		new_s *= (1.0 + scale_speed * delta)
	if Input.is_action_pressed("wand_scale_dn"):
		new_s *= (1.0 - scale_speed * delta)

	new_s = new_s.clamp(
		Vector3(min_scale, min_scale, min_scale),
		Vector3(max_scale, max_scale, max_scale)
	)

	if new_s == old_s:
		return

	# Apply scales
	mesh.scale = new_s
	if cs:
		cs.scale = new_s

	var aura: Node3D = grabbed.get_node_or_null(AURA_NAME) as Node3D
	if aura:
		aura.scale = new_s

	# Re-anchor so bottom stays where it was (grows upward from support surface)
	var aabb: AABB = mesh.get_aabb()
	var half_h: float = aabb.size.y * 0.5
	var new_dist_to_bottom: float = half_h * mesh.scale.y
	grabbed.global_position.y = current_bottom + new_dist_to_bottom

	# IMPORTANT: removed the "nudge upward until clear" loop entirely


# ====================================================================
# Beam
# ====================================================================
func _update_magic_beam(target: Node3D) -> void:
	if wand_magic == null or magic_mat == null:
		return

	if target == null:
		wand_magic.emitting = false
		return

	var from_pos: Vector3 = wand_ray.to_global(wand_ray.target_position)
	var to_pos: Vector3 = target.global_transform.origin
	var dir_world: Vector3 = to_pos - from_pos
	var dist: float = dir_world.length()

	if dist < 0.05:
		wand_magic.emitting = false
		return

	dir_world = dir_world.normalized()
	var mid: Vector3 = from_pos + dir_world * (dist * 0.5)

	var xf: Transform3D = Transform3D.IDENTITY
	xf.origin = mid
	xf = xf.looking_at(mid + dir_world, Vector3.UP)
	wand_magic.global_transform = xf

	magic_mat.emission_box_extents = Vector3(beam_thickness, beam_thickness, dist * 0.5)
	wand_magic.lifetime = beam_lifetime
	wand_magic.preprocess = beam_lifetime
	wand_magic.emitting = true
