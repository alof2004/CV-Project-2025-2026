extends ParallaxBackground
@export var speed := Vector2(100.0, 0.0)

func _process(delta: float) -> void:
	scroll_offset += speed * delta
