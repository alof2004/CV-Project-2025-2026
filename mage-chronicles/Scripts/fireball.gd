extends Area3D

@export var speed: float = 10.0
@export var damage: int = 1

func _ready():
	
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta: float):
	position += transform.basis.z * speed * delta

func _on_area_entered(area):
	
	if area.has_method("ignite"): 
		area.ignite()
		queue_free()
		return

	
	var parent = area.get_parent()
	if parent != null and parent.has_method("ignite"):
		parent.ignite()
		queue_free()

func _on_body_entered(body):
	
	if body.name == "wizard" or body.name == "Wizard":
		return

	
	
	if body.has_method("ignite"):
		body.ignite()
	
	
	
	var parent = body.get_parent()
	if parent != null and parent.has_method("ignite"):
		parent.ignite()

	
	queue_free()
