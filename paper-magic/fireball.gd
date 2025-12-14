extends Area3D

@export var speed: float = 10.0
@export var damage: int = 1

func _ready():
	# --- ADD THESE TWO LINES ---
	# This ensures Godot actually calls your functions when a hit happens
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	# ---------------------------
	
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta: float):
	position += transform.basis.z * speed * delta

func _on_area_entered(area):
	# 1. Check if the Area itself has the script (e.g., direct hit)
	if area.has_method("ignite"): 
		area.ignite()
		queue_free()
		return

	# 2. Check if the Parent has the script (e.g., hit the Area child of the Torch)
	var parent = area.get_parent()
	if parent != null and parent.has_method("ignite"):
		parent.ignite()
		queue_free()

func _on_body_entered(body):
	# 1. Ignore the wizard
	if body.name == "wizard" or body.name == "Wizard":
		return

	# 2. Check if the solid body we hit is part of a torch
	# (Case A: Script is on the body itself)
	if body.has_method("ignite"):
		body.ignite()
	
	# (Case B: Script is on the Parent of the body)
	# This is the most likely case if your Torch has a StaticBody child
	var parent = body.get_parent()
	if parent != null and parent.has_method("ignite"):
		parent.ignite()

	# 3. Destroy the fireball
	queue_free()
