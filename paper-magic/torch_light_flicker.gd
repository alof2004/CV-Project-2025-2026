extends OmniLight3D

var base_energy = 2.0 # The normal brightness
var noise = FastNoiseLite.new() # A random noise generator
var time_passed = 0.0

func _ready():
	# Configure the noise so it feels like fire
	noise.seed = randi()
	noise.frequency = 2.0 # How fast it flickers

func _process(delta):
	time_passed += delta
	# Get a random value between -1 and 1
	var random_value = noise.get_noise_1d(time_passed * 50.0)
	
	# Apply it to the light energy (Base brightness + random flicker)
	light_energy = base_energy + (random_value * 0.5)
