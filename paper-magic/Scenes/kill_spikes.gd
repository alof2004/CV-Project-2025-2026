extends Area3D

@export var respawn_point_path: NodePath  # point behind the spikes (Marker3D)
@onready var respawn_point := get_node(respawn_point_path) as Node3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# basic "death" -> teleport respawn
	var p := body as Node3D
	if p and respawn_point:
		p.global_position = respawn_point.global_position
		p.global_rotation = respawn_point.global_rotation
