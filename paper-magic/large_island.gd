extends RigidBody3D

@export var dip_amount: float = 0.15
@export var dip_time: float = 0.08
@export var return_time: float = 0.12

var _start_pos: Vector3
var _tween: Tween

func _ready() -> void:
	_start_pos = global_position
	$Area3D.body_entered.connect(_on_enter)

func _on_enter(body: Node) -> void:
	if !(body is Node3D) or !body.is_in_group("player"):
		return

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", _start_pos + Vector3(0, -dip_amount, 0), dip_time)
	_tween.tween_property(self, "global_position", _start_pos, return_time)
