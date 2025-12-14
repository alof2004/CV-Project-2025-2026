# Wand.gd (with aura debug)
extends Node3D

# --------------------------------------------------------------------
# NODES
# --------------------------------------------------------------------
@export var wand_ray_path: NodePath
@export var magic_particles_path: NodePath   # GPUParticles3D
@export var player_path: NodePath            # optional
@export var camera_path: NodePath            # optional
@export var mouse_pick_radius_px: float = 120.0
@export var debug_camera: bool = false

@export var debug_wand: bool = true
@export var debug_aura: bool = true

@onready var cam: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var wand_ray: RayCast3D = get_node_or_null(wand_ray_path) as RayCast3D
@onready var wand_magic: GPUParticles3D = get_node_or_null(magic_particles_path) as GPUParticles3D
@onready var player: Node = get_node_or_null(player_path)

# --------------------------------------------------------------------
# SELECTION / TRANSFORM
# --------------------------------------------------------------------
@export var selection_radius: float = 7.0
@export var rotate_anim_time: float = 0.2
@export var move_speed: float = 4.0
@export var max_grab_distance: float = 15.0

# Scaling is RELATIVE multiplier while grabbed
@export var scale_speed: float = 1.0
@export var min_scale: float = 0.5
@export var max_scale: float = 2.0

# --------------------------------------------------------------------
# FLOOR / GROUND
# --------------------------------------------------------------------
@export var floor_height: float = 2.0
@export var floor_offset: float = 0.0
@export var ground_ray_length: float = 80.0
@export var ground_ray_start_offset: float = 0.2

# --------------------------------------------------------------------
# AURA (SelectionAura mesh under targets)
# You said: albedo is transparent, glow comes from EMISSION.
# We will:
#   - force unique material instance (fix disappearing)
#   - tween ALBEDO alpha (for visibility) AND EMISSION energy (for glow)
#   - NOT overwrite your emission color/texture/operator
# --------------------------------------------------------------------
@export var aura_max_alpha: float = 0.65
@export var aura_fade_time: float = 0.2
@export var aura_scale_boost: float = 1.01

# multiply your existing Energy Multiplier by this when visible
@export var aura_energy_boost: float = 1.0

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

const HORIZ_EPS := 0.02
const DOWN_SOLVE_STEPS := 10

# --------------------------------------------------------------------
# State
# --------------------------------------------------------------------
var magic_mat: ParticleProcessMaterial = null
var hovered: Node3D = null
var grabbed: Node3D = null

var aura_tweens: Dictionary = {}             # MeshInstance3D -> Tween
var aura_base_energy: Dictionary = {}        # MeshInstance3D -> float (original energy mult)
var rotate_tween: Tween = null

# Relative scaling state
var grabbed_scale_factor: float = 1.0
var grabbed_base_mesh_scale: Vector3 = Vector3.ONE
var grabbed_base_cs_scale: Vector3 = Vector3.ONE
var grabbed_base_aura_scale: Vector3 = Vector3.ONE

# RigidBody grab state
var grabbed_is_rb: bool = false
var grabbed_rb_prev_freeze_mode: int = RigidBody3D.FREEZE_MODE_STATIC

var orig_mesh_scale: Dictionary = {} # Node3D -> Vector3
var orig_cs_scale: Dictionary = {}   # Node3D -> Vector3
var orig_aura_scale: Dictionary = {} # Node3D -> Vector3

# ====================================================================
# Debug helpers
# ====================================================================
func _dbg(msg: String) -> void:
	if debug_wand:
		print("[WAND] ", msg)

func _dbg_aura(msg: String) -> void:
	if debug_aura:
		print("[WAND][AURA] ", msg)

func _mat_summary(mat: Material) -> String:
	if mat == null:
		return "mat=NULL"
	var t := mat.get_class()
	var id := str(mat.get_instance_id())
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		return "%s id=%s albedo_a=%.3f emission_on=%s emission_energy=%.3f emission_color=%s blend=%s cull=%s depth_draw=%s" % [
			t, id,
			sm.albedo_color.a,
			str(sm.emission_enabled),
			sm.emission_energy_multiplier,
			str(sm.emission),
			str(sm.blend_mode),
			str(sm.cull_mode),
			str(sm.depth_draw_mode)
		]
	return "%s id=%s" % [t, id]

func _node_path_safe(n: Node) -> String:
	return str(n.get_path()) if n != null else "<null>"


# ====================================================================
# Camera & mouse (SubViewport safe)
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
# Helpers: find mesh / collider
# ====================================================================
func _get_visual_mesh(root: Node3D) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null

func _find_collision_shape(n: Node) -> CollisionShape3D:
	var cs: CollisionShape3D = n.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null and cs.shape != null:
		return cs
	for c in n.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
			return c as CollisionShape3D
	return null


# ====================================================================
# Helpers: collision queries
# ====================================================================
func _intersect_shape_with_transform(grabbed_node: Node3D, cs: CollisionShape3D, xf: Transform3D) -> bool:
	if cs == null or cs.shape == null:
		return false

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
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

func _apply_motion_safely(grabbed_node: Node3D, cs: CollisionShape3D, motion: Vector3, extra_offset: Vector3 = Vector3.ZERO, steps: int = 8) -> Vector3:
	if motion == Vector3.ZERO:
		return Vector3.ZERO
	if cs == null or cs.shape == null:
		return motion

	if not _would_collide(grabbed_node, cs, motion, extra_offset):
		return motion

	var lo := 0.0
	var hi := 1.0
	for _i in range(steps):
		var mid := (lo + hi) * 0.5
		var test := motion * mid
		if _would_collide(grabbed_node, cs, test, extra_offset):
			hi = mid
		else:
			lo = mid
	return motion * lo


# ====================================================================
# Helpers: ground height under object
# ====================================================================
func _get_ground_y_under(node: Node3D) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var from := node.global_transform.origin + Vector3(0.0, ground_ray_start_offset, 0.0)
	var to := from - Vector3(0.0, ground_ray_length, 0.0)

	var q := PhysicsRayQueryParameters3D.create(from, to)

	var excludes: Array[RID] = []
	if node is CollisionObject3D:
		excludes.append((node as CollisionObject3D).get_rid())
	if player is CollisionObject3D:
		excludes.append((player as CollisionObject3D).get_rid())
	q.exclude = excludes
	q.collision_mask = 0xFFFFFFFF

	var hit := space.intersect_ray(q)
	if not hit.is_empty() and hit.has("position"):
		return (hit["position"] as Vector3).y

	return floor_height

func _get_bottom_y(node: Node3D) -> float:
	var mesh := _get_visual_mesh(node)
	if mesh == null:
		return node.global_position.y
	var aabb := mesh.get_aabb()
	var local_bottom := aabb.position + Vector3(aabb.size.x * 0.5, 0.0, aabb.size.z * 0.5)
	var global_bottom := mesh.global_transform * local_bottom
	return global_bottom.y


# ====================================================================
# Aura: get/duplicate material (NO style overrides)
# ====================================================================
func _get_aura_material(aura: MeshInstance3D) -> StandardMaterial3D:
	if aura == null:
		return null

	# Try surface material first (common on imported GLBs)
	var mat: Material = aura.get_surface_override_material(0)
	if mat == null:
		mat = aura.material_override
	if mat == null:
		mat = aura.get_active_material(0)
	if mat == null:
		_dbg_aura("No material found on aura " + _node_path_safe(aura))
		return null

	_dbg_aura("FOUND aura material: " + _mat_summary(mat))

	if not (mat is StandardMaterial3D):
		_dbg_aura("Aura material is NOT StandardMaterial3D (it's " + mat.get_class() + ") -> aura won't fade with this script")
		return null

	# Always duplicate so aura never shares with the real mesh (fix disappearing)
	var dup := mat.duplicate(true) as Material
	dup.resource_local_to_scene = true
	aura.material_override = dup

	var sm := dup as StandardMaterial3D

	# Make sure alpha can fade (your albedo is transparent; we only animate alpha)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.alpha_scissor_threshold = 0.0

	# Prevent the aura from "covering" the object (safe for overlays)
	sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	sm.render_priority = 1

	# Record original emission energy once (keeps your per-object glow tuning)
	if not aura_base_energy.has(aura):
		aura_base_energy[aura] = sm.emission_energy_multiplier
		_dbg_aura("BASE energy stored: %.3f for %s" % [sm.emission_energy_multiplier, _node_path_safe(aura)])

	_dbg_aura("DUP aura material now: " + _mat_summary(sm))
	return sm


func _init_aura_for_target(t: Node3D) -> void:
	var aura := t.find_child(AURA_NAME, true, false) as MeshInstance3D
	if aura == null:
		_dbg_aura("INIT: target has NO SelectionAura: " + _node_path_safe(t))
		return

	aura.top_level = false

	var sm := _get_aura_material(aura)
	if sm == null:
		_dbg_aura("INIT: aura material failed for " + _node_path_safe(aura))
		return

	# Start hidden: alpha=0, emission energy=0
	var c := sm.albedo_color
	c.a = 0.0
	sm.albedo_color = c

	var base_energy: float = float(aura_base_energy.get(aura, sm.emission_energy_multiplier))
	sm.emission_energy_multiplier = 0.0

	aura.visible = false

	_dbg_aura("INIT DONE: aura vis=false alpha=0 energy 0 (base=%.3f) node=%s" % [base_energy, _node_path_safe(aura)])


# ====================================================================
# Ready
# ====================================================================
func _ready() -> void:
	_dbg("READY")
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

	var aabb := AABB()
	aabb.position = Vector3(-beam_max_length * 0.5, -beam_max_length * 0.5, -beam_max_length * 0.5)
	aabb.size = Vector3(beam_max_length, beam_max_length, beam_max_length)
	wand_magic.visibility_aabb = aabb

	# Init existing targets
	var targets := get_tree().get_nodes_in_group(TARGET_GROUP)
	_dbg("Targets in group '%s': %d" % [TARGET_GROUP, targets.size()])
	for node in targets:
		if node is Node3D:
			_init_aura_for_target(node as Node3D)

	# Init targets spawned later
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Node3D and (n as Node3D).is_in_group(TARGET_GROUP):
			_dbg("node_added target=" + (n as Node3D).name + " path=" + _node_path_safe(n))
			_init_aura_for_target(n as Node3D)
	)


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

	var target_rot := grabbed.rotation_degrees
	target_rot.y += rad_to_deg(ROTATE_STEP) * dir

	rotate_tween = get_tree().create_tween()
	rotate_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rotate_tween.tween_property(grabbed, "rotation_degrees", target_rot, rotate_anim_time)


# ====================================================================
# Main loop
# ====================================================================
func _physics_process(delta: float) -> void:
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
	var player_node := player as Node3D
	ref_pos = player_node.global_transform.origin if player_node != null else global_transform.origin
	if ref_pos.distance_to(grabbed.global_transform.origin) > max_grab_distance:
		_dbg("Too far -> force deselect")
		_force_deselect()


func _force_deselect() -> void:
	if grabbed == null:
		return

	_dbg("DESELECT " + grabbed.name)
	_set_aura_visible(grabbed, false)

	if grabbed_is_rb and grabbed is RigidBody3D:
		var rb := grabbed as RigidBody3D
		rb.freeze = false
		rb.freeze_mode = grabbed_rb_prev_freeze_mode
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO

	grabbed_is_rb = false
	grabbed = null
	_update_magic_beam(null)


# ====================================================================
# Hover + selection
# ====================================================================
func _update_hover() -> void:
	var camera := _get_active_camera()
	if camera == null:
		hovered = null
		return

	var mouse_pos := _get_mouse_pos_for_camera(camera)
	var wand_pos := wand_ray.global_transform.origin

	var new_hover: Node3D = null
	var best_px := mouse_pick_radius_px

	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if not (node is Node3D):
			continue
		var n := node as Node3D
		var world_pos := n.global_transform.origin

		if (world_pos - wand_pos).length() > selection_radius:
			continue
		if camera.is_position_behind(world_pos):
			continue

		var screen_pos := camera.unproject_position(world_pos)
		var d_px := screen_pos.distance_to(mouse_pos)
		if d_px < best_px:
			best_px = d_px
			new_hover = n

	if new_hover != hovered:
		_dbg("HOVER %s -> %s" % [hovered.name if hovered else "NULL", new_hover.name if new_hover else "NULL"])

	hovered = new_hover


func _toggle_select() -> void:
	_dbg("TOGGLE grabbed=%s hovered=%s" % [grabbed.name if grabbed else "NULL", hovered.name if hovered else "NULL"])

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

		# RB: freeze as kinematic so it can push
		grabbed_is_rb = false
		if grabbed is RigidBody3D:
			var rb := grabbed as RigidBody3D
			grabbed_is_rb = true
			grabbed_rb_prev_freeze_mode = rb.freeze_mode
			rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			rb.freeze = true
			rb.linear_velocity = Vector3.ZERO
			rb.angular_velocity = Vector3.ZERO

		# Capture base scales (relative scaling)
		# --- Capture ORIGINAL scales (persist across grabs) ---
		_ensure_original_scales(grabbed)

		var mesh := _get_visual_mesh(grabbed)
		var cs := _find_collision_shape(grabbed)
		var aura_node := grabbed.find_child(AURA_NAME, true, false) as Node3D

		# Always base on ORIGINAL, not current
		grabbed_base_mesh_scale = orig_mesh_scale.get(grabbed, mesh.scale) if mesh else Vector3.ONE
		grabbed_base_cs_scale = orig_cs_scale.get(grabbed, cs.scale) if cs else Vector3.ONE
		grabbed_base_aura_scale = orig_aura_scale.get(grabbed, aura_node.scale) if aura_node else Vector3.ONE

		# Initialize factor from current scale (so it doesn't jump), but clamp it
		if mesh:
			var fx: float = mesh.scale.x / maxf(grabbed_base_mesh_scale.x, 0.0001)
			var fy: float = mesh.scale.y / maxf(grabbed_base_mesh_scale.y, 0.0001)
			var fz: float = mesh.scale.z / maxf(grabbed_base_mesh_scale.z, 0.0001)
			grabbed_scale_factor = clampf((fx + fy + fz) / 3.0, min_scale, max_scale)
		else:
			grabbed_scale_factor = 1.0


		_dbg("SELECT " + grabbed.name)
		_set_aura_visible(grabbed, true)


# ====================================================================
# Aura show/hide (fade alpha + emission energy)
# ====================================================================
func _set_aura_visible(target: Node3D, visible: bool) -> void:
	if target == null:
		return

	var aura := target.find_child(AURA_NAME, true, false) as MeshInstance3D
	if aura == null:
		_dbg_aura("SET visible=%s: NO SelectionAura under %s" % [str(visible), _node_path_safe(target)])
		return

	aura.top_level = false

	var sm := _get_aura_material(aura)
	if sm == null:
		_dbg_aura("SET visible=%s: material failed for %s" % [str(visible), _node_path_safe(aura)])
		return

	if aura_tweens.has(aura):
		var old_tw := aura_tweens[aura] as Tween
		if old_tw and old_tw.is_valid():
			old_tw.kill()
		aura_tweens.erase(aura)

	var base_energy: float = float(aura_base_energy.get(aura, sm.emission_energy_multiplier))
	base_energy *= aura_energy_boost

	var from_alpha := sm.albedo_color.a
	var to_alpha := aura_max_alpha if visible else 0.0

	# Energy follows alpha so your emission-based glow fades with it
	var from_energy := sm.emission_energy_multiplier
	var to_energy := base_energy if visible else 0.0

	var to_col := sm.albedo_color
	to_col.a = to_alpha

	_dbg_aura("SET aura %s visible=%s  alpha %.3f->%.3f  energy %.3f->%.3f  mat=%s" % [
		_node_path_safe(aura), str(visible),
		from_alpha, to_alpha,
		from_energy, to_energy,
		_mat_summary(sm)
	])

	aura.visible = true
	aura.scale = grabbed_base_aura_scale * grabbed_scale_factor * (aura_scale_boost if visible else 1.0)

	var dur := aura_fade_time
	if not visible:
		dur *= 0.4

	var tw := get_tree().create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sm, "albedo_color", to_col, dur)
	tw.parallel().tween_property(sm, "emission_energy_multiplier", to_energy, dur)

	if not visible:
		tw.tween_callback(func() -> void:
			aura.visible = false
			_dbg_aura("HIDE DONE " + _node_path_safe(aura))
		)

	aura_tweens[aura] = tw


# ====================================================================
# MOVE
# ====================================================================
func _update_move(delta: float) -> void:
	if grabbed == null:
		return

	var is_2d_mode := false
	if player:
		var v: Variant = player.get("is_2d")
		if typeof(v) == TYPE_BOOL:
			is_2d_mode = v as bool

	var input_dir := Vector2.ZERO
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

	var y_dir := 0.0
	if Input.is_action_pressed("move_object_y_up"):
		y_dir += 1.0
	if Input.is_action_pressed("move_object_y_down"):
		y_dir -= 1.0

	if input_dir == Vector2.ZERO and y_dir == 0.0:
		return

	var move_dir := Vector3.ZERO
	if is_2d_mode:
		move_dir = Vector3(input_dir.x, 0.0, 0.0)
	else:
		var cam_ref := _get_active_camera()
		if cam_ref:
			var basis := cam_ref.global_transform.basis
			var forward := -basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var right := basis.x
			right.y = 0.0
			right = right.normalized()
			move_dir = right * input_dir.x + forward * input_dir.y
			if move_dir.length() > 0.0:
				move_dir = move_dir.normalized()
		else:
			move_dir = Vector3(input_dir.x, 0.0, input_dir.y)

	var cs := _find_collision_shape(grabbed)

	var horiz := move_dir * move_speed * delta
	if horiz != Vector3.ZERO:
		var applied := _apply_motion_safely(grabbed, cs, horiz, Vector3(0.0, HORIZ_EPS, 0.0), 6)
		if applied == Vector3.ZERO:
			var hx := Vector3(horiz.x, 0.0, 0.0)
			var hz := Vector3(0.0, 0.0, horiz.z)
			var ax := _apply_motion_safely(grabbed, cs, hx, Vector3(0.0, HORIZ_EPS, 0.0), 6)
			var az := _apply_motion_safely(grabbed, cs, hz, Vector3(0.0, HORIZ_EPS, 0.0), 6)
			grabbed.global_position += ax + az
		else:
			grabbed.global_position += applied

	if y_dir != 0.0:
		var vert := Vector3(0.0, y_dir * move_speed * delta, 0.0)
		var vsteps := DOWN_SOLVE_STEPS if y_dir < 0.0 else 6
		var applied_v := _apply_motion_safely(grabbed, cs, vert, Vector3.ZERO, vsteps)
		grabbed.global_position += applied_v

	if y_dir <= 0.0:
		var ground_y := _get_ground_y_under(grabbed) + floor_offset
		var bottom_y := _get_bottom_y(grabbed)
		if bottom_y < ground_y:
			grabbed.global_position.y += (ground_y - bottom_y)


# ====================================================================
# SCALE (relative)
# ====================================================================
func _update_scale(delta: float) -> void:
	if grabbed == null:
		return

	var mesh := _get_visual_mesh(grabbed)
	if mesh == null:
		return

	var cs := _find_collision_shape(grabbed)
	var aura_node := grabbed.find_child(AURA_NAME, true, false) as Node3D

	var ground_y := _get_ground_y_under(grabbed) + floor_offset
	var current_bottom := maxf(_get_bottom_y(grabbed), ground_y)

	var old_factor := grabbed_scale_factor
	var new_factor := old_factor

	if Input.is_action_pressed("wand_scale_up"):
		new_factor *= (1.0 + scale_speed * delta)
	if Input.is_action_pressed("wand_scale_dn"):
		new_factor *= (1.0 - scale_speed * delta)

	new_factor = clampf(new_factor, min_scale, max_scale)
	if is_equal_approx(new_factor, old_factor):
		return

	grabbed_scale_factor = new_factor

	mesh.scale = grabbed_base_mesh_scale * grabbed_scale_factor
	if cs:
		cs.scale = grabbed_base_cs_scale * grabbed_scale_factor
	if aura_node:
		aura_node.scale = grabbed_base_aura_scale * grabbed_scale_factor * aura_scale_boost

	var new_bottom := _get_bottom_y(grabbed)
	grabbed.global_position.y += (current_bottom - new_bottom)


# ====================================================================
# Beam
# ====================================================================
func _update_magic_beam(target: Node3D) -> void:
	if wand_magic == null or magic_mat == null:
		return

	if target == null:
		wand_magic.emitting = false
		return

	var from_pos := wand_ray.to_global(wand_ray.target_position)
	var to_pos := target.global_transform.origin
	var dir_world := to_pos - from_pos
	var dist := dir_world.length()

	if dist < 0.05:
		wand_magic.emitting = false
		return

	dir_world = dir_world.normalized()
	var mid := from_pos + dir_world * (dist * 0.5)

	var xf := Transform3D.IDENTITY
	xf.origin = mid
	xf = xf.looking_at(mid + dir_world, Vector3.UP)
	wand_magic.global_transform = xf

	magic_mat.emission_box_extents = Vector3(beam_thickness, beam_thickness, dist * 0.5)
	wand_magic.lifetime = beam_lifetime
	wand_magic.preprocess = beam_lifetime
	wand_magic.emitting = true

func _ensure_original_scales(t: Node3D) -> void:
	if t == null:
		return

	var mesh := _get_visual_mesh(t)
	var cs := _find_collision_shape(t)
	var aura_node := t.find_child(AURA_NAME, true, false) as Node3D

	if mesh and not orig_mesh_scale.has(t):
		orig_mesh_scale[t] = mesh.scale
	if cs and not orig_cs_scale.has(t):
		orig_cs_scale[t] = cs.scale
	if aura_node and not orig_aura_scale.has(t):
		orig_aura_scale[t] = aura_node.scale
