extends Camera3D

@export var player_path: NodePath
@onready var player: CharacterBody3D = get_node(player_path)

const HEIGHT := 1.0      # how high above the player
const DIST_Z := 6.0     # how far away from the player in Z

func _ready():
	# fixed side-view rotation (looking along -Z; adjust if needed)
	rotation_degrees = Vector3(0.0, 0.0, 0.0)   # or (0, -90, 0) depending on your axis

func _process(delta):
	if player == null:
		return

	var p := player.global_transform.origin

	# follow player only in X (side-scroll), keep fixed Z distance and some height
	global_transform.origin = Vector3(
		p.x,             # track X
		p.y + HEIGHT,    # a bit above
		p.z + DIST_Z     # fixed distance from the scene
	)
