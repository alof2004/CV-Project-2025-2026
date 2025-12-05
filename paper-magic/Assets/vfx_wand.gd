extends Node3D

@export var wand_ray_path: NodePath
@export var magic_particles_path: NodePath   # GPUParticles3D (WandMagic)

@export var selection_radius: float = 2.0
@export var rotate_speed: float = 2.0
@export var scale_speed: float = 1.0
@export var min_scale: float = 0.5
@export var max_scale: float = 2.0

@export var aura_max_alpha: float = 0.4
@export var aura_fade_time: float = 0.2

# how thick the beam looks
@export var beam_thickness: float = 0.2     # half-height / half-width of the box
# how far past the object the beam continues
@export var beam_length_factor: float = 1.2 # 1.0 = exactly to object, >1 = overshoot

# NEW: how strong the downward bend is
@export var beam_gravity: float = 0.5       # small value = slight fall, larger = big arc

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


func _ready() -> void:
	print("\n[WAND] _ready")

	# ---- Ray ----
	if wand_ray:
		wand_ray.enabled = true
	else:
		push_error("[WAND] ERROR: wand_ray is NULL")

	# ---- Particles / beam ----
	if wand_magic:
		magic_mat = wand_magic.process_material as ParticleProcessMaterial
		if magic_mat == null:
			push_error("[WAND] WandMagic has no ParticleProcessMaterial")
		else:
			# Static beam along a box; particles then fall a bit in world -Y
			magic_mat.initial_velocity_min = 0.0
			magic_mat.initial_velocity_max = 0.0
			# CHANGED: give them a small downward pull
			magic_mat.gravity = Vector3(0.0, -beam_gravity, 0.0)
			magic_mat.spread = 0.0
			magic_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX

		# CHANGED: world-space so gravity is always “down”
		wand_magic.local_coords = false

		wand_magic.lifetime = 0.8
		wand_magic.preprocess = 0.8
		wand_magic.amount = 800
		wand_magic.emitting = false
	else:
		push_error("[WAND] ERROR: magic_particles_path is NULL")

	# ---- Auras start hidden ----
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

	var is_col: bool = wand_ray.is_colliding()
	if is_col != last_colliding or frame_counter % 30 == 0:
		if is_col:
			var col := wand_ray.get_collider()
			print("[WAND] Ray HIT (debug):", col, " groups:", col.get_groups())
		else:
			print("[WAND] Ray hit NOTHING (debug)")
		last_colliding = is_col

	_update_hover()

	if Input.is_action_just_pressed("wand_grab"):
		_toggle_select()

	if grabbed:
		_update_rotation(delta)
		_update_scale(delta)

	var target: Node3D = grabbed if grabbed != null else hovered
	_update_magic_beam(target)


# ---------- Hover / selection ----------

func _update_hover() -> void:
	var new_hover: Node3D = null
	var best_dist: float = selection_radius
	var wand_pos: Vector3 = wand_ray.global_transform.origin

	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node is Node3D:
			var pos: Vector3 = node.global_transform.origin
			var d: float = (pos - wand_pos).length()
			if d < best_dist:
				best_dist = d
				new_hover = node

	hovered = new_hover


func _toggle_select() -> void:
	if hovered == null and grabbed:
		_set_aura_visible(grabbed, false)
		grabbed = null
		return

	if hovered:
		if grabbed and grabbed != hovered:
			_set_aura_visible(grabbed, false)

		grabbed = hovered
		_set_aura_visible(grabbed, true)


# ---------- Aura fade ----------

func _set_aura_visible(target: Node3D, visible: bool) -> void:
	if target == null:
		return

	var aura := target.get_node_or_null(AURA_NAME) as MeshInstance3D
	if aura == null:
		return

	var mat := _get_aura_material(aura)
	if mat == null:
		return

	if aura_tweens.has(aura):
		var old_tween := aura_tweens[aura] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		aura_tweens.erase(aura)

	var from_col: Color = mat.albedo_color
	var to_col: Color = from_col
	to_col.a = aura_max_alpha if visible else 0.0

	aura.visible = true

	var tw := get_tree().create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", to_col, aura_fade_time)

	if not visible:
		tw.tween_callback(Callable(aura, "set_visible").bind(false))

	aura_tweens[aura] = tw


# ---------- Transform controls ----------

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

	if Input.is_action_pressed("wand_scale_up"):
		s *= 1.0 + scale_speed * delta
	if Input.is_action_pressed("wand_scale_dn"):
		s *= 1.0 - scale_speed * delta

	s.x = clamp(s.x, min_scale, max_scale)
	s.y = clamp(s.y, min_scale, max_scale)
	s.z = clamp(s.z, min_scale, max_scale)

	grabbed.scale = s


# ---------- MAGIC BEAM (solid “line” between wand and target) ----------

func _update_magic_beam(target: Node3D) -> void:
	if wand_magic == null or magic_mat == null:
		return

	if target == null:
		wand_magic.emitting = false
		return

	var from_pos: Vector3 = wand_ray.global_transform.origin
	var to_pos: Vector3   = target.global_transform.origin
	var dir: Vector3      = to_pos - from_pos
	var dist: float       = dir.length()

	if dist < 0.05:
		wand_magic.emitting = false
		return

	dir = dir.normalized()

	# How far the beam should cover (can overshoot object)
	var length := dist * beam_length_factor

	# Center of the beam
	var mid := from_pos + dir * (length * 0.5)

	# Build basis so local +Z points along dir
	var z_axis: Vector3 = dir
	var up := Vector3.UP
	if abs(z_axis.dot(up)) > 0.9:
		up = Vector3.RIGHT
	var x_axis: Vector3 = up.cross(z_axis).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()

	var basis := Basis(x_axis, y_axis, z_axis)

	# Move / rotate particle node so its local Z spans along wand->target
	wand_magic.global_transform = Transform3D(basis, mid)

	# Emit inside a long, thin box aligned to that Z axis
	magic_mat.emission_box_extents = Vector3(
		beam_thickness,
		beam_thickness,
		length * 0.5
	)

	wand_magic.emitting = true
