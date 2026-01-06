# BeamPrism.gd
extends CollisionObject3D
# Works for StaticBody3D or Area3D.

@export var exit_marker_path: NodePath = NodePath("Exit")

func get_exit_position() -> Vector3:
	var exit := get_node_or_null(exit_marker_path) as Node3D
	return exit.global_position if exit else global_position

func get_exit_direction() -> Vector3:
	var exit := get_node_or_null(exit_marker_path) as Node3D
	if exit:
		# Marker forward is -Z
		return (-exit.global_transform.basis.z).normalized()

	# Fallback if marker missing
	return (-global_transform.basis.z).normalized()
