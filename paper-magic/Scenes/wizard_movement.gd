extends CharacterBody3D

# --- New Variables for Magic ---
@export var fireball_scene: PackedScene 
const MAGIC_ANIM := "magic controlling"
const MAGIC_ANIM_SPEED := 3.0 
var is_casting: bool = false
# -------------------------------

const SPEED := 4.0
const JUMP_FORCE := 5.0          
const RUN_JUMP_FORCE := 6.0      
const GRAVITY := 15.0
const ROTATION_SPEED := 10.0

const IDLE_ANIM := "idle"
const WALK_ANIM := "running"
const JUMP_ANIM := "jumping_falling"
const RUN_JUMP_ANIM := "running_jumping"
const FALL_ANIM := ""

const JUMP_ANIM_SPEED := 1.3
const BLEND_TIME := 0.15

@onready var anim: AnimationPlayer = $"wizard/AnimationPlayer"

var is_2d: bool = true
var plane_z: float = 0.0   

func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	plane_z = global_transform.origin.z

func set_2d_mode(enabled: bool) -> void:
	is_2d = enabled
	if is_2d:
		plane_z = global_transform.origin.z
		velocity.z = 0.0

func _physics_process(delta: float) -> void:
	if is_casting:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)
		move_and_slide()
		return 

	if Input.is_action_just_pressed("fireball") and is_on_floor():
		cast_spell()
		return

	# --- STANDARD MOVEMENT ---
	var input_dir := Vector2.ZERO
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
	if is_2d:
		vel.z = 0.0
	else:
		vel.z = move_dir.z * SPEED

	if not is_on_floor():
		vel.y -= GRAVITY * delta

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
	
	# 1. WAIT FOR SPAWN
	await get_tree().create_timer(0.3).timeout
	spawn_fireball()

	# 2. WAIT FOR ANIMATION CUT (1.7s mark)
	var total_real_time = 1.7 / MAGIC_ANIM_SPEED
	var remaining_wait = total_real_time - 0.3
	
	if remaining_wait > 0:
		await get_tree().create_timer(remaining_wait).timeout

	# 3. SLOW RETURN TO IDLE
	is_casting = false
	
	# I changed 0.15 (BLEND_TIME) to 0.5 here.
	# This means it takes half a second to smooth back to idle.
	# Increase this number (e.g. to 0.8 or 1.0) if you want it even slower.
	_play(IDLE_ANIM, 0.5)

func spawn_fireball():
	if fireball_scene:
		var fireball = fireball_scene.instantiate()
		get_parent().add_child(fireball)
		
		# --- YOUR EXACT COORDINATES ---
		fireball.global_transform = global_transform
		fireball.global_position.y -= 0.5 
		fireball.translate_object_local(Vector3(0, 0, 0.8))

func _handle_animation(move_dir: Vector3) -> void:
	if is_casting: 
		return

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
