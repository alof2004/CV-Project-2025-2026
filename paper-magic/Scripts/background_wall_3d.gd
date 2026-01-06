extends Node3D


@export var camera_path: NodePath

@export var player_path: NodePath



@export var layer_nodes: Array[NodePath] = []


@export var base_side_distance: float = 3.0

@export var side_step: float = 1.5


@export var base_height: float = 0.0

@export var height_step: float = 0.0


@export var base_parallax_factor: float = 0.3



@export var on_left_side: bool = true


@onready var cam: Camera3D = get_node_or_null(camera_path)
@onready var player: Node3D = get_node_or_null(player_path)


var _layers: Array[Node3D] = []
var _debug_frame: int = 0


func _ready() -> void:
	print("--- BackgroundWall3D READY ---")
	print("  camera_path =", camera_path, "  cam =", cam)
	print("  player_path =", player_path, "  player =", player)

	if cam == null:
		push_error("BackgroundWall3D: camera_path is not set")
	if player == null:
		push_error("BackgroundWall3D: player_path is not set")

	
	if layer_nodes.is_empty():
		print("BackgroundWall3D: layer_nodes is empty, auto-collecting MeshInstance3D children")
		for child in get_children():
			if child is MeshInstance3D:
				layer_nodes.append(child.get_path())

	print("BackgroundWall3D: layer_nodes =", layer_nodes)

	for path in layer_nodes:
		var node3d := get_node_or_null(path) as Node3D
		if node3d:
			_layers.append(node3d)
			print("  using layer:", node3d.name, " path =", path)
		else:
			print("  WARNING: layer path", path, "is not a valid Node3D")


func _process(_delta: float) -> void:
	if cam == null or player == null:
		return
	var layer_count: int = _layers.size()
	if layer_count == 0:
		return

	var p: Vector3 = player.global_position

	
	
	
	var track_dir: Vector3 = Vector3(1.0, 0.0, 0.0)
	var side_dir: Vector3 = Vector3(0.0, 0.0, -1.0) if on_left_side else Vector3(0.0, 0.0, 1.0)

	
	var track_pos: float = p.x
	var denom: float = max(1.0, float(layer_count - 1))

	for i in range(layer_count):
		var node3d: Node3D = _layers[i]
		if node3d == null:
			continue

		var dist: float = base_side_distance + float(i) * side_step
		var height: float = base_height + float(i) * height_step

		
		var base_pos: Vector3 = p + side_dir * dist + Vector3(0.0, height, 0.0)

		
		var layer_factor: float = base_parallax_factor * (1.0 - float(i) / denom)
		var along: Vector3 = track_dir * (track_pos * layer_factor)

		var final_pos := base_pos + along
		node3d.global_position = final_pos
		
		

	
	_debug_frame += 1
	if _debug_frame % 30 == 0 and layer_count > 0:
		var first := _layers[0]
		if first:
			print("[BG WALL] side =", ("LEFT" if on_left_side else "RIGHT"),
				" player_pos =", p,
				" first_layer_pos =", first.global_position)
