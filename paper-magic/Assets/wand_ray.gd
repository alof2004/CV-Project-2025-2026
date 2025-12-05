extends Node3D

@export var wand_ray_path: NodePath

@export var selection_radius: float = 2.0   # how close to wand tip to hover/select
@export var rotate_speed: float = 2.0       # manual rotation (rad/s)
@export var scale_speed: float = 1.0        # manual scale factor/s
@export var min_scale: float = 0.5
@export var max_scale: float = 2.0

@export var aura_max_alpha: float = 0.4     # target alpha when fully glowing
@export var aura_fade_time: float = 0.2     # time (seconds) for fade in/out

const TARGET_GROUP := "wand_target"
const AURA_NAME    := "SelectionAura"

@onready var wand_ray: RayCast3D = get_node(wand_ray_path)

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
	print("\n[WAND] _ready")
	print("[WAND] wand_ray_path =", wand_ray_path)

	if wand_ray == null:
		push_error("[WAND] ERROR: wand_ray is NULL (bad path?)")
	else:
		print("[WAND] RayCast3D found:", wand_ray.name, " enabled =", wand_ray.enabled)
		wand_ray.enabled = true

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
		print("[WAND] wand_grab pressed")
		_toggle_select()
	if Input.is_action_just_released("wand_grab"):
		print("[WAND] wand_grab released")

	# While something is selected, rotate / scale it
	if grabbed:
		_update_rotation(delta)
		_update_scale(delta)


# ---------- Hover & selection (proximity) ----------

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

	if frame_counter % 30 == 0:
		print("[WAND] Proximity:", wand_pos,
			" best =", (new_hover.name if new_hover else "none"),
			" dist =", (best_dist if new_hover else -1.0))

	if new_hover == hovered:
		return

	hovered = new_hover


func _toggle_select() -> void:
	# Click empty space → clear selection
	if hovered == null and grabbed:
		print("[WAND] Deselect:", grabbed.name)
		_set_aura_visible(grabbed, false)
		grabbed = null
		return

	if hovered:
		# Clear previous selection
		if grabbed and grabbed != hovered:
			print("[WAND] Change selection from", grabbed.name, "to", hovered.name)
			_set_aura_visible(grabbed, false)

		grabbed = hovered
		print("[WAND] Select:", grabbed.name)
		_set_aura_visible(grabbed, true)


# ---------- Aura fade-in / fade-out ----------

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
		print("[WAND] Rotating", grabbed.name, "by", angle, "rad around Y")
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
		print("[WAND] Scaling", grabbed.name, "from", orig, "to", s)

	grabbed.scale = s
