extends Area3D

@export var respawn_point_path: NodePath

var respawn_point: Node3D = null
var busy := false

func _ready() -> void:
	monitoring = true
	monitorable = true

	if respawn_point_path != NodePath():
		respawn_point = get_node_or_null(respawn_point_path) as Node3D

	body_entered.connect(_on_body_entered)

func set_respawn_target(p: Node3D) -> void:
	respawn_point = p

func _on_body_entered(body: Node) -> void:
	if busy:
		return

	
	var p: Node3D = null
	if body is Node3D and (body as Node3D).is_in_group("player"):
		p = body as Node3D
	else:
		var parent := body.get_parent()
		if parent is Node3D and (parent as Node3D).is_in_group("player"):
			p = parent as Node3D

	if p == null:
		return

	if respawn_point == null:
		push_warning("[KillArea] respawn_point is NULL (not set).")
		return

	if p.has_method("die_and_respawn"):
		busy = true
		p.call("die_and_respawn", respawn_point.global_position)
		await get_tree().create_timer(0.2).timeout
		busy = false
		return

	p.set_deferred("global_transform", respawn_point.global_transform)
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
