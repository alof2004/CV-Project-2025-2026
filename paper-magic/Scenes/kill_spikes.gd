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

	var p := body as Node3D
	if p == null:
		return

	if not p.is_in_group("player"):
		return

	if respawn_point == null:
		push_warning("[KillArea] respawn_point is NULL (not set).")
		return

	# Use dissolve if available
	if p.has_method("die_and_respawn"):
		busy = true
		p.call("die_and_respawn", respawn_point.global_position)
		# Prevent re-trigger spam while overlapping
		await get_tree().create_timer(0.2).timeout
		busy = false
		return

	# Fallback: old instant respawn
	p.set_deferred("global_transform", respawn_point.global_transform)
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
