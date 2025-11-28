extends CharacterBody3D

const SPEED := 4.0
const JUMP_FORCE := 6.0
const GRAVITY := 15.0
const ROTATION_SPEED := 10.0    # higher = faster turning

@onready var anim: AnimationPlayer = $"wizard/AnimationPlayer"

func _physics_process(delta):
	var input_dir := Vector2.ZERO

	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_north"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_south"):
		input_dir.y += 1.0

	input_dir = input_dir.normalized()

	var velocity := self.velocity

	# convert 2D input to 3D direction (X,Z)
	var move_dir := Vector3(input_dir.x, 0.0, input_dir.y)

	velocity.x = move_dir.x * SPEED
	velocity.z = move_dir.z * SPEED

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_FORCE
		_play("jumping")

	# rotate character to face movement direction (yaw only)
	if move_dir.length() > 0.01:
		# Godot forward is -Z
		var target_yaw := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, ROTATION_SPEED * delta)


	self.velocity = velocity
	move_and_slide()

	_handle_animation(move_dir)


func _handle_animation(move_dir: Vector3) -> void:
	if not is_on_floor():
		return

	if move_dir.length() > 0.01:
		_play("walking")
	else:
		_play("magic controlling")


func _play(name: String) -> void:
	if anim.current_animation != name:
		anim.play(name)
