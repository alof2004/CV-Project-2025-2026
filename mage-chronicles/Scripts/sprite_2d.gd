extends ParallaxLayer

func _ready() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var s: Sprite2D = $Sprite2D                   
	s.centered = true                             
	s.position = screen_size * 0.5                
	s.scale = Vector2(4.0, 4.0)                   
