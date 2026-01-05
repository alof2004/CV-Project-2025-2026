extends OmniLight3D

var base_energy = 2.0 
var noise = FastNoiseLite.new() 
var time_passed = 0.0

func _ready():
	noise.seed = randi()
	noise.frequency = 2.0

func _process(delta):
	time_passed += delta
	var random_value = noise.get_noise_1d(time_passed * 50.0)
	light_energy = base_energy + (random_value * 0.5)
