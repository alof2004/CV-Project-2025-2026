extends CharacterBody3D

const SPEED := 4.0
const JUMP_FORCE := 5.0          # normal jump
const RUN_JUMP_FORCE := 6.0      # stronger jump when running
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
var plane_z: float = 0.0   # z-position used in 2D mode


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	plane_z = global_transform.origin.z


func set_2d_mode(enabled: bool) -> void:
	is_2d = enabled
	if is_2d:
		plane_z = global_transform.origin.z
		velocity.z = 0.0


func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO

	# --- collect input ---
	# Left/right always available
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0

	# Forward/back only matter in 3D mode
	if not is_2d:
		if Input.is_action_pressed("move_north"):
			input_dir.y += 1.0
		if Input.is_action_pressed("move_south"):
			input_dir.y -= 1.0

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# --- convert input to world movement ---
	var move_dir := Vector3.ZERO

	if is_2d:
		# Movement only along X (Paper Mario side view)
		move_dir = Vector3(input_dir.x, 0.0, 0.0)
	else:
		# Movement relative to camera: W = forward, A = left, etc.
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
			# Fallback: world axes
			move_dir = Vector3(input_dir.x, 0.0, input_dir.y)

	var vel := velocity

	# Horizontal movement
	vel.x = move_dir.x * SPEED
	if is_2d:
		vel.z = 0.0
	else:
		vel.z = move_dir.z * SPEED

	# Gravity
	if not is_on_floor():
		vel.y -= GRAVITY * delta

	# Jump: apply Y velocity immediately, stronger when running
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

	# Rotate towards movement direction
	if move_dir.length() > 0.01:
		var target_yaw := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, ROTATION_SPEED * delta)

	velocity = vel
	move_and_slide()

	# Lock Z in 2D mode
	if is_2d:
		var t := global_transform
		t.origin.z = plane_z
		global_transform = t

	_handle_animation(move_dir)


func _handle_animation(move_dir: Vector3) -> void:
	# do not interrupt jump animations while they are playing
	if (anim.current_animation == JUMP_ANIM
			or anim.current_animation == RUN_JUMP_ANIM) \
			and anim.is_playing():
		return

	if not is_on_floor():
		if FALL_ANIM != "":
			_play(FALL_ANIM, BLEND_TIME)
		return

	if move_dir.length() > 0.01:
		_play(WALK_ANIM, BLEND_TIME)
	else:
		_play(IDLE_ANIM, BLEND_TIME)


# kept in case your animations still call this method
func _on_jump_takeoff() -> void:
	pass


func _on_animation_finished(name: StringName) -> void:
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
	else:
		anim.speed_scale = 1.0

	anim.play(name, blend_time)


func _playsafe(name: String) -> void:
	_play(name, BLEND_TIME)
