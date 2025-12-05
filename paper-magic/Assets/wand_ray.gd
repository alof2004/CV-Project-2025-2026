# Wand.gd
extends Node3D

# --------------------------------------------------------------------
# NODES
# --------------------------------------------------------------------
@export var wand_ray_path: NodePath
@export var magic_particles_path: NodePath   # GPUParticles3D

# --------------------------------------------------------------------
# SELECTION / TRANSFORM
# --------------------------------------------------------------------
@export var selection_radius: float = 7.0   # how close to wand tip to hover/select
@export var rotate_speed: float = 2.0       # manual rotation (rad/s)
@export var scale_speed: float = 1.0        # manual scale factor/s
@export var min_scale: float = 0.5
@export var max_scale: float = 2.0

# --------------------------------------------------------------------
# AURA
# --------------------------------------------------------------------
@export var aura_max_alpha: float = 0.4     # target alpha when fully glowing
@export var aura_fade_time: float = 0.2     # time (seconds) for fade in/out

# --------------------------------------------------------------------
# BEAM (GPUParticles3D)
# --------------------------------------------------------------------
@export var beam_speed: float = 12.0        # particle speed along beam
@export var beam_amount: int = 1500         # how many particles
@export var beam_max_length: float = 10000.0   # must cover max wand distance

const TARGET_GROUP := "wand_target"
const AURA_NAME    := "SelectionAura"

@onready var wand_ray: RayCast3D        = get_node(wand_ray_path)
@onready var wand_magic: GPUParticles3D = get_node(magic_particles_path)

var magic_mat: ParticleProcessMaterial = null

var hovered: Node3D = null
var grabbed: Node3D = null

var last_colliding: bool = false
var frame_counter: int = 0

# aura -> Tween
var aura_tweens: Dictionary = {}


# -------------------------------------------------------
# Helper: get a *per-instance* StandardMaterial3D for aura
# -------------------------------------------------------
func _get_aura_material(aura: MeshInstance3D) -> StandardMaterial3D:
	var mat: Material = aura.get_surface_override_material(0)
	if mat == null:
		mat = aura.material_override
	if mat == null:
		mat = aura.get_active_material(0)
	if mat == null:
		return null

	# Make sure this instance has its own copy
	if not mat.resource_local_to_scene:
		mat = mat.duplicate()
		mat.resource_local_to_scene = true
		aura.material_override = mat

	return mat as StandardMaterial3D


func _ready() -> void:
	# Ray
	if wand_ray == null:
		push_error("[WAND] ERROR: wand_ray is NULL (bad path?)")
	else:
		wand_ray.enabled = true

	# Magic beam
	if wand_magic == null:
		push_error("[WAND] ERROR: wand_magic is NULL (bad path?)")
	else:
		magic_mat = wand_magic.process_material as ParticleProcessMaterial
		if magic_mat == null:
			push_error("[WAND] WandMagic has no ParticleProcessMaterial")
		else:
			# Emit from a single point
			magic_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			magic_mat.spread = 5.0
			magic_mat.gravity = Vector3.ZERO      # straight beam
			magic_mat.direction = Vector3(0, 0, -1)  # along -Z of emitter
			magic_mat.initial_velocity_min = beam_speed
			magic_mat.initial_velocity_max = beam_speed

		# Local coords so we can rotate emitter to face the target
		wand_magic.local_coords = true
		wand_magic.amount = beam_amount
		wand_magic.emitting = false

		# Large visibility box so the beam is not clipped
		var aabb := AABB()
		aabb.position = Vector3(-beam_max_length * 0.5, -beam_max_length * 0.5, -beam_max_length * 0.5)
		aabb.size = Vector3(beam_max_length, beam_max_length, beam_max_length)
		wand_magic.visibility_aabb = aabb

	# Ensure all auras start hidden and fully transparent
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node is Node3D:
			var aura_node: MeshInstance3D = node.get_node_or_null(AURA_NAME) as MeshInstance3D
			if aura_node:
				var mat: StandardMaterial3D = _get_aura_material(aura_node)
				if mat:
					var c: Color = mat.albedo_color
					c.a = 0.0
					mat.albedo_color = c
				aura_node.visible = false


func _physics_process(delta: float) -> void:
	if wand_ray == null:
		return

	frame_counter += 1

	# Ray debug (optional)
	var is_col: bool = wand_ray.is_colliding()
	if is_col != last_colliding or frame_counter % 30 == 0:
		if is_col:
			var col := wand_ray.get_collider()
			print("[WAND] Ray HIT (debug):", col, " groups:", col.get_groups())
		else:
			print("[WAND] Ray hit NOTHING (debug)")
		last_colliding = is_col

	_update_hover()

	# Select / deselect with wand_grab
	if Input.is_action_just_pressed("wand_grab"):
		_toggle_select()

	# While something is selected, rotate / scale it
	if grabbed:
		_update_rotation(delta)
		_update_scale(delta)

	# Beam goes to grabbed if any, otherwise to hovered
	var target: Node3D = grabbed if grabbed != null else hovered
	_update_magic_beam(target)



func _update_hover() -> void:
	var new_hover: Node3D = null
	var best_dist: float = selection_radius

	# Use wand tip (ray origin) in world coordinates
	var wand_pos: Vector3 = wand_ray.global_transform.origin

	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node is Node3D:
			var pos: Vector3 = node.global_transform.origin
			var d: float = (pos - wand_pos).length()
			if d < best_dist:
				best_dist = d
				new_hover = node

	if new_hover == hovered:
		return

	hovered = new_hover


func _toggle_select() -> void:
	# Click empty space → clear selection
	if hovered == null and grabbed:
		_set_aura_visible(grabbed, false)
		grabbed = null
		return

	if hovered:
		# Clear previous selection
		if grabbed and grabbed != hovered:
			_set_aura_visible(grabbed, false)

		grabbed = hovered
		_set_aura_visible(grabbed, true)


# ====================================================================
# AURA FADE-IN / FADE-OUT
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

	# Stop old tween
	if aura_tweens.has(aura):
		var old_tween: Tween = aura_tweens[aura] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		aura_tweens.erase(aura)

	var from_col: Color = mat.albedo_color
	var to_col: Color = from_col
	to_col.a = aura_max_alpha if visible else 0.0

	# Visible while animating
	aura.visible = true

	var tw: Tween = get_tree().create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", to_col, aura_fade_time)

	if not visible:
		tw.tween_callback(Callable(aura, "set_visible").bind(false))

	aura_tweens[aura] = tw


# ====================================================================
# TRANSFORM CONTROLS
# ====================================================================

func _update_rotation(delta: float) -> void:
	if grabbed == null:
		return

	var angle: float = 0.0
	if Input.is_action_pressed("wand_rotate_l"):
		angle -= rotate_speed * delta
	if Input.is_action_pressed("wand_rotate_r"):
		angle += rotate_speed * delta

	if angle != 0.0:
		grabbed.rotate_y(angle)


func _update_scale(delta: float) -> void:
	if grabbed == null:
		return

	var s: Vector3 = grabbed.scale
	var orig: Vector3 = s

	if Input.is_action_pressed("wand_scale_up"):
		s *= 1.0 + scale_speed * delta
	if Input.is_action_pressed("wand_scale_dn"):
		s *= 1.0 - scale_speed * delta

	s.x = clamp(s.x, min_scale, max_scale)
	s.y = clamp(s.y, min_scale, max_scale)
	s.z = clamp(s.z, min_scale, max_scale)

	if s != orig:
		grabbed.scale = s


# ====================================================================
# MAGIC BEAM (STRAIGHT LINE FROM WAND TIP TO TARGET)
# ====================================================================

func _update_magic_beam(target: Node3D) -> void:
	if wand_magic == null or magic_mat == null:
		return

	if target == null:
		wand_magic.emitting = false
		return

	# Start from the *tip* of the ray (not the RayCast origin)
	var from_pos: Vector3 = wand_ray.to_global(wand_ray.target_position)

	# Target position
	var to_pos: Vector3 = target.global_transform.origin
	print(to_pos)
	var dir_world: Vector3 = to_pos - from_pos
	var dist: float = dir_world.length()

	if dist < 0.05:
		wand_magic.emitting = false
		return

	dir_world = dir_world.normalized()

	# Build a transform that looks from from_pos to to_pos (-Z axis points to target)
	var xf := Transform3D.IDENTITY
	xf.origin = from_pos
	xf = xf.looking_at(from_pos + dir_world, Vector3.UP)

	wand_magic.global_transform = xf

	# Time so particles reach the target exactly once
	var lifetime: float = dist / beam_speed

	magic_mat.initial_velocity_min = beam_speed
	magic_mat.initial_velocity_max = beam_speed
	wand_magic.lifetime = lifetime
	wand_magic.preprocess = lifetime   # fill whole beam
	wand_magic.emitting = true
