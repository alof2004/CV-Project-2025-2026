shader_type spatial;
render_mode unshaded, cull_disabled; // Unshaded because fire is light.

uniform vec3 color_core : source_color = vec3(1.0, 0.8, 0.0); // Yellow
uniform vec3 color_edge : source_color = vec3(1.0, 0.1, 0.0); // Red
uniform float noise_scale = 2.0;
uniform float displacement_amount = 0.2; // How much the ball wobbles
uniform float speed = 2.0;

// Simple 3D Noise function
vec3 hash(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			 dot(p, vec3(269.5, 183.3, 246.1)),
			 dot(p, vec3(113.5, 271.9, 124.6)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(dot(hash(i + vec3(0.0, 0.0, 0.0)), f - vec3(0.0, 0.0, 0.0)),
					   dot(hash(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0)), u.x),
				   mix(dot(hash(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0)),
					   dot(hash(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0)), u.x), u.y),
			   mix(mix(dot(hash(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0)),
					   dot(hash(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0)), u.x),
				   mix(dot(hash(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0)),
					   dot(hash(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

void vertex() {
	// 1. Calculate noise based on vertex position and time
	float n = noise(VERTEX * noise_scale + vec3(0.0, TIME * speed, 0.0));

	// 2. Push the vertex out along its normal vector
	VERTEX += NORMAL * n * displacement_amount;
}

void fragment() {
	// 1. Calculate the same noise for coloring
	// (Note: In a real production shader, we'd use a varying to pass this from vertex to fragment to save perf)
	float n = noise(VERTEX * noise_scale + vec3(0.0, TIME * speed, 0.0));

	// 2. Fresnel: Makes the edges glow.
	// This calculates the angle between the camera (VIEW) and the surface normal (NORMAL)
	float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));

	// 3. Combine noise and fresnel for the final color look
	vec3 final_color = mix(color_core, color_edge, fresnel + n * 0.2);

	// 4. Add a transparency fade so it's not a hard plastic ball
	float alpha = clamp(fresnel * 1.5 + n * 0.5, 0.0, 1.0);

	ALBEDO = final_color;
	ALPHA = alpha;
}