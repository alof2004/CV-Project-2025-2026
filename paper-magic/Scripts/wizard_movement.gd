extends CharacterBody3D


@export var fireball_scene: PackedScene 
const MAGIC_ANIM := "magic controlling"
const MAGIC_ANIM_SPEED := 3.0 
var is_casting: bool = false


const SPEED := 4.0
const JUMP_FORCE := 5.0
const RUN_JUMP_FORCE := 6.0
@export var gravity := 15.0
const ROTATION_SPEED := 10.0

const IDLE_ANIM := "idle"
const WALK_ANIM := "running"
const JUMP_ANIM := "jumping_falling"
const RUN_JUMP_ANIM := "running_jumping"
const FALL_ANIM := ""

const JUMP_ANIM_SPEED := 1.3
const BLEND_TIME := 0.15


@export var burn_out_time := 1.2
@export var burn_in_time := 1.2
@export var kill_radius := 2.0 
@export var burn_center_offset := Vector3(0.0, 0.5, 0.0) 

@onready var anim: AnimationPlayer = $"wizard/AnimationPlayer"
@onready var wizard_root: Node = $"wizard"
@onready var main_mesh: MeshInstance3D = $"wizard/Armature/GeneralSkeleton/Main_Mesh"

var is_2d := true
var plane_z := 0.0

var dead := false
var burn_mats: Array[ShaderMaterial] = []
var _saved_collision_layer: int
var _saved_collision_mask: int
var _burn_template: ShaderMaterial


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	plane_z = global_transform.origin.z

	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask

	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path.ends_with("Levels/Level4.tscn"):
		gravity = 5

	_burn_template = main_mesh.get_surface_override_material(0) as ShaderMaterial
	if _burn_template == null:
		_burn_template = main_mesh.get_active_material(0) as ShaderMaterial

	if _burn_template == null or _burn_template.shader == null:
		push_warning("Assign your burn ShaderMaterial on Main_Mesh -> Surface Material Override -> 0 (with Albedo/Noise/ColorCurve set).")
		return

	burn_mats.clear()
	_apply_burn_to_all_meshes(wizard_root)

	
	for m in burn_mats:
		m.set_shader_parameter("radius", 0.0)

	
	print("[Wizard] burn_mats:", burn_mats.size())


func set_2d_mode(enabled: bool) -> void:
	is_2d = enabled
	if is_2d:
		plane_z = global_transform.origin.z
		velocity.z = 0.0

func _physics_process(delta: float) -> void:
	if dead:
		return

	var input_dir := Vector2.ZERO

	if is_casting:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)
		move_and_slide()
		return 

	if Input.is_action_just_pressed("fireball") and is_on_floor():
		cast_spell()
		return

	
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if not is_2d:
		if Input.is_action_pressed("move_north"):
			input_dir.y += 1.0
		if Input.is_action_pressed("move_south"):
			input_dir.y -= 1.0

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	var move_dir := Vector3.ZERO
	if is_2d:
		move_dir = Vector3(input_dir.x, 0.0, 0.0)
	else:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var basis := cam.global_transform.basis
			var forward := -basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var right := basis.x
			right.y = 0.0
			right = right.normalized()
			move_dir = (right * input_dir.x + forward * input_dir.y).normalized()
		else:
			move_dir = Vector3(input_dir.x, 0.0, input_dir.y)

	var vel := velocity
	vel.x = move_dir.x * SPEED
	vel.z = 0.0 if is_2d else move_dir.z * SPEED

	if not is_on_floor():
		vel.y -= gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		var horizontal_speed := Vector2(vel.x, vel.z).length()
		if horizontal_speed > 0.1:
			vel.y = RUN_JUMP_FORCE
			_play(RUN_JUMP_ANIM, 0.05)
			anim.seek(0.2, true)
		else:
			vel.y = JUMP_FORCE
			_play(JUMP_ANIM, 0.05)
			anim.seek(0.55, true)

	if move_dir.length() > 0.01:
		var target_yaw := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, ROTATION_SPEED * delta)

	velocity = vel
	move_and_slide()

	if is_2d:
		var t := global_transform
		t.origin.z = plane_z
		global_transform = t

	_handle_animation(move_dir)

func cast_spell():
	is_casting = true
	_play(MAGIC_ANIM, 0.1) 
	
	
	await get_tree().create_timer(0.3).timeout
	spawn_fireball()

	
	var total_real_time = 1.7 / MAGIC_ANIM_SPEED
	var remaining_wait = total_real_time - 0.3
	
	if remaining_wait > 0:
		await get_tree().create_timer(remaining_wait).timeout

	
	is_casting = false
	
	
	
	
	_play(IDLE_ANIM, 0.5)

func spawn_fireball():
	if fireball_scene:
		var fireball = fireball_scene.instantiate()
		get_parent().add_child(fireball)
		
		
		fireball.global_transform = global_transform
		fireball.global_position.y -= 0.5 
		fireball.translate_object_local(Vector3(0, 0, 0.8))


func die_and_respawn(respawn_pos: Vector3) -> void:
	if dead:
		return
	dead = true

	velocity = Vector3.ZERO
	anim.stop()

	
	collision_layer = 0
	collision_mask = 0

	_set_burn_center(global_position + burn_center_offset)

	
	for m in burn_mats:
		m.set_shader_parameter("radius", 0.0)

	var t := create_tween()
	t.set_parallel(true)
	for m in burn_mats:
		t.tween_property(m, "shader_parameter/radius", kill_radius, burn_out_time)

	t.set_parallel(false)
	t.tween_callback(Callable(self, "_respawn_now").bind(respawn_pos))


func _respawn_now(respawn_pos: Vector3) -> void:
	global_position = respawn_pos
	if is_2d:
		plane_z = global_position.z

	_set_burn_center(respawn_pos + burn_center_offset)

	
	for m in burn_mats:
		m.set_shader_parameter("radius", kill_radius)

	var t := create_tween()
	t.set_parallel(true)
	for m in burn_mats:
		t.tween_property(m, "shader_parameter/radius", 0.0, burn_in_time)

	t.set_parallel(false)
	t.tween_callback(func ():
		collision_layer = _saved_collision_layer
		collision_mask = _saved_collision_mask
		dead = false
		_playsafe(IDLE_ANIM)
	)


func _set_burn_center(center: Vector3) -> void:
	
	for m in burn_mats:
		m.set_shader_parameter("burn_center", center)


func _apply_burn_to_all_meshes(node: Node) -> void:
	for c in node.get_children():
		_apply_burn_to_all_meshes(c)

	if not (node is MeshInstance3D):
		return

	var mi := node as MeshInstance3D
	if mi.mesh == null:
		return

	var surface_count := mi.mesh.get_surface_count()
	for s in range(surface_count):
		
		var sm := _burn_template.duplicate(true) as ShaderMaterial

		
		var base_mat := mi.get_active_material(s)
		if base_mat is BaseMaterial3D:
			var albedo := (base_mat as BaseMaterial3D).get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
			if albedo != null:
				sm.set_shader_parameter("albedo_texture", albedo)

		
		sm.set_shader_parameter("radius", 0.0)

		mi.set_surface_override_material(s, sm)
		burn_mats.append(sm)


func _handle_animation(move_dir: Vector3) -> void:
	if (anim.current_animation == JUMP_ANIM or anim.current_animation == RUN_JUMP_ANIM) and anim.is_playing():
		return

	if not is_on_floor():
		if FALL_ANIM != "":
			_play(FALL_ANIM, BLEND_TIME)
		return

	if move_dir.length() > 0.01:
		_play(WALK_ANIM, BLEND_TIME)
	else:
		_play(IDLE_ANIM, BLEND_TIME)


func _on_animation_finished(name: StringName) -> void:
	if dead:
		return
		
	if name == MAGIC_ANIM and is_casting:
		is_casting = false
		_playsafe(IDLE_ANIM)

	if (name == JUMP_ANIM or name == RUN_JUMP_ANIM) and is_on_floor():
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		if horizontal_speed > 0.1:
			_playsafe(WALK_ANIM)
		else:
			_playsafe(IDLE_ANIM)

func _play(name: String, blend_time: float = BLEND_TIME) -> void:
	if anim.current_animation == name and anim.is_playing():
		return

	if name == JUMP_ANIM or name == RUN_JUMP_ANIM:
		anim.speed_scale = JUMP_ANIM_SPEED
	elif name == MAGIC_ANIM:
		anim.speed_scale = MAGIC_ANIM_SPEED  
	else:
		anim.speed_scale = 1.0

	anim.play(name, blend_time)

func _playsafe(name: String) -> void:
	_play(name, BLEND_TIME)
