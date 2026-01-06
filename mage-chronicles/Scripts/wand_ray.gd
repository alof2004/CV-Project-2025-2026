
extends Node3D




@export var wand_ray_path: NodePath
@export var magic_particles_path: NodePath   




@export var selection_radius: float = 7.0
@export var rotate_speed: float = 2.0
@export var scale_speed: float = 1.0
@export var min_scale: float = 0.5
@export var max_scale: float = 2.0




@export var aura_max_alpha: float = 0.4
@export var aura_fade_time: float = 0.2




@export var beam_speed: float = 12.0
@export var beam_amount: int = 1500
@export var beam_max_length: float = 10000.0

@export var mouse_pick_radius_px: float = 120.0

@export_node_path("Camera3D") var camera_path: NodePath
@onready var cam: Camera3D = get_node_or_null(camera_path) as Camera3D




@export var debug_wand: bool = true
@export var debug_material_sharing: bool = true

const TARGET_GROUP := "wand_target"
const AURA_NAME    := "SelectionAura"

@onready var wand_ray: RayCast3D        = get_node_or_null(wand_ray_path) as RayCast3D
@onready var wand_magic: GPUParticles3D = get_node_or_null(magic_particles_path) as GPUParticles3D

var magic_mat: ParticleProcessMaterial = null

var hovered: Node3D = null
var grabbed: Node3D = null

var last_colliding: bool = false
var frame_counter: int = 0


var aura_tweens: Dictionary = {}

func _dbg(msg: String) -> void:
	if debug_wand:
		print("[WAND] ", msg)

func _dbg_target(t: Node3D, where: String = "") -> void:
	if not debug_wand:
		return

	if t == null:
		_dbg(where + " target=NULL")
		return

	_dbg(where + " target=" + t.name + " path=" + str(t.get_path()) + " groups=" + str(t.get_groups()))

	var aura := t.find_child(AURA_NAME, true, false) as MeshInstance3D
	if aura == null:
		_dbg(where + "  aura=NOT FOUND (needs child named '" + AURA_NAME + "')")
		return

	var mat := aura.material_override
	var alpha := -1.0
	if mat is StandardMaterial3D:
		alpha = (mat as StandardMaterial3D).albedo_color.a

	_dbg(where + "  aura.visible=" + str(aura.visible)
		+ " aura.mesh_id=" + (str(aura.mesh.get_instance_id()) if aura.mesh else "null")
		+ " aura.mat_id=" + (str(mat.get_instance_id()) if mat else "null")
		+ " aura.alpha=" + str(alpha))

	
	if debug_material_sharing and mat != null:
		for c in t.get_children():
			if c is MeshInstance3D and c != aura:
				var m2 := (c as MeshInstance3D).material_override
				if m2 != null and m2.get_instance_id() == mat.get_instance_id():
					_dbg(where + "  !!! WARNING: aura material is SHARED with mesh '" + c.name + "' -> fading aura will hide the real object")





func _get_aura_material(aura: MeshInstance3D) -> StandardMaterial3D:
	if aura == null:
		return null

	var mat: Material = aura.get_surface_override_material(0)
	if mat == null:
		mat = aura.material_override
	if mat == null:
		mat = aura.get_active_material(0)
	if mat == null:
		return null

	
	mat = mat.duplicate(true)
	mat.resource_local_to_scene = true
	aura.material_override = mat

	var sm := mat as StandardMaterial3D
	if sm == null:
		return null

	
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.alpha_scissor_threshold = 0.0

	return sm

func _ready() -> void:
	
	if wand_ray == null:
		push_error("[WAND] ERROR: wand_ray is NULL (bad path?)")
	else:
		wand_ray.enabled = true

	
	if wand_magic == null:
		push_error("[WAND] ERROR: wand_magic is NULL (bad path?)")
	else:
		magic_mat = wand_magic.process_material as ParticleProcessMaterial
		if magic_mat == null:
			push_error("[WAND] WandMagic has no ParticleProcessMaterial")
		else:
			magic_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			magic_mat.spread = 5.0
			magic_mat.gravity = Vector3.ZERO
			magic_mat.direction = Vector3(0, 0, -1)
			magic_mat.initial_velocity_min = beam_speed
			magic_mat.initial_velocity_max = beam_speed

		wand_magic.local_coords = true
		wand_magic.amount = beam_amount
		wand_magic.emitting = false

		var aabb := AABB()
		aabb.position = Vector3(-beam_max_length * 0.5, -beam_max_length * 0.5, -beam_max_length * 0.5)
		aabb.size = Vector3(beam_max_length, beam_max_length, beam_max_length)
		wand_magic.visibility_aabb = aabb

	
	_dbg("Init existing targets in group '" + TARGET_GROUP + "' count=" + str(get_tree().get_nodes_in_group(TARGET_GROUP).size()))
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node is Node3D:
			_init_target_aura(node as Node3D)

	
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if not (n is Node3D):
		return
	var t := n as Node3D
	if t.is_in_group(TARGET_GROUP):
		_dbg("node_added -> init aura for " + t.name + " (" + str(t.get_path()) + ")")
		_init_target_aura(t)

func _init_target_aura(target: Node3D) -> void:
	var aura := target.find_child(AURA_NAME, true, false) as MeshInstance3D
	if aura == null:
		_dbg("init_target_aura: " + target.name + " has no '" + AURA_NAME + "'")
		return

	var mat := _get_aura_material(aura)
	if mat != null:
		var c: Color = mat.albedo_color
		c.a = 0.0
		mat.albedo_color = c

	aura.visible = false
	_dbg_target(target, "INIT  ")

func _physics_process(delta: float) -> void:
	if wand_ray == null:
		return

	frame_counter += 1

	
	var is_col: bool = wand_ray.is_colliding()
	if is_col != last_colliding or frame_counter % 30 == 0:
		if is_col:
			var col := wand_ray.get_collider()
			_dbg("Ray HIT: " + str(col) + " groups=" + str(col.get_groups()))
		else:
			_dbg("Ray hit NOTHING")
		last_colliding = is_col

	_update_hover()

	if Input.is_action_just_pressed("wand_grab"):
		_toggle_select()

	if grabbed:
		_update_rotation(delta)
		_update_scale(delta)

	var target: Node3D = grabbed if grabbed != null else hovered
	_update_magic_beam(target)

func _update_hover() -> void:
	var new_hover: Node3D = null
	var best_px: float = mouse_pick_radius_px

	var camera: Camera3D = cam
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var wand_pos: Vector3 = wand_ray.global_transform.origin

	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if not (node is Node3D):
			continue

		var n := node as Node3D
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

	if new_hover == hovered:
		return

	_dbg("hover changed: " + (hovered.name if hovered else "NULL") + " -> " + (new_hover.name if new_hover else "NULL"))
	hovered = new_hover

func _toggle_select() -> void:
	_dbg("toggle_select hovered=" + (hovered.name if hovered else "NULL")
		+ " grabbed=" + (grabbed.name if grabbed else "NULL"))
	_dbg_target(hovered, "BEFORE ")
	_dbg_target(grabbed, "BEFORE ")

	
	if hovered == null and grabbed:
		_set_aura_visible(grabbed, false)
		grabbed = null
		_dbg("cleared selection")
		_dbg_target(grabbed, "AFTER  ")
		return

	if hovered:
		if grabbed and grabbed != hovered:
			_set_aura_visible(grabbed, false)

		grabbed = hovered
		_set_aura_visible(grabbed, true)

	_dbg_target(hovered, "AFTER  ")
	_dbg_target(grabbed, "AFTER  ")




func _set_aura_visible(target: Node3D, visible: bool) -> void:
	if target == null:
		return

	_dbg("_set_aura_visible target=" + target.name + " visible=" + str(visible))
	_dbg_target(target, "PRE   ")

	var aura := target.find_child(AURA_NAME, true, false) as MeshInstance3D
	if aura == null:
		_dbg("No aura node on " + target.name)
		return

	var mat: StandardMaterial3D = _get_aura_material(aura)
	if mat == null:
		_dbg("No aura material on " + target.name)
		return

	
	if aura_tweens.has(aura):
		var old_tween: Tween = aura_tweens[aura] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		aura_tweens.erase(aura)

	var from_col: Color = mat.albedo_color
	var to_col: Color = from_col
	to_col.a = aura_max_alpha if visible else 0.0

	
	aura.visible = true

	var tw: Tween = get_tree().create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", to_col, aura_fade_time)

	if not visible:
		tw.tween_callback(Callable(aura, "set_visible").bind(false))

	aura_tweens[aura] = tw

	_dbg_target(target, "POST  ")




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




func _update_magic_beam(target: Node3D) -> void:
	if wand_magic == null or magic_mat == null or wand_ray == null:
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

	var xf := Transform3D.IDENTITY
	xf.origin = from_pos
	xf = xf.looking_at(from_pos + dir_world, Vector3.UP)

	wand_magic.global_transform = xf

	var lifetime: float = dist / beam_speed

	magic_mat.initial_velocity_min = beam_speed
	magic_mat.initial_velocity_max = beam_speed
	wand_magic.lifetime = lifetime
	wand_magic.preprocess = lifetime
	wand_magic.emitting = true
