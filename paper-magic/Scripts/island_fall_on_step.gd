extends RigidBody3D

@export var fall_gravity_scale: float = 0.15
@export var trigger_path: NodePath = NodePath("StepTrigger")
@export var player_group: StringName = &"player"
@export var disable_trigger_after: bool = true

var _triggered := false
@onready var _trigger: Area3D = get_node_or_null(trigger_path) as Area3D

func _ready() -> void:
	gravity_scale = 0.0

	if _trigger == null:
		push_warning("Step trigger not found at '%s'." % trigger_path)
		return

	_trigger.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return

	var target := body as Node3D
	if target == null:
		return

	if not target.is_in_group(player_group):
		var parent := target.get_parent() as Node3D
		if parent == null or not parent.is_in_group(player_group):
			return

	_triggered = true
	gravity_scale = fall_gravity_scale
	sleeping = false

	if disable_trigger_after and _trigger != null:
		_trigger.monitoring = false
