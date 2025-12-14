shader_type spatial;
// blend_add is crucial for making it glow and be visible against dark backgrounds
render_mode unshaded, cull_disabled, blend_add;

uniform vec3 color_base : source_color = vec3(1.0, 0.7, 0.1); // Bright Orange/Yellow
uniform vec3 color_tip : source_color = vec3(0.8, 0.1, 0.0);  // Darker Red
uniform float scroll_speed = 2.5;
uniform float noise_scale = 3.0;

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
	// Gentle shaping: Make the base slightly wider and the top thinner
	// On a capsule, UV.y goes from 0 (top) to 1 (bottom) roughly.
	float taper = mix(0.6, 1.2, UV.y);
	VERTEX.xz *= taper;
}

void fragment() {
	// 1. Vertical Gradient (1.0 at bottom, 0.0 at top)
	// We use UV.y because it follows the capsule shape nicely.
	float vertical_mask = smoothstep(0.1, 0.9, UV.y);

	// 2. Scrolling 3D Noise
	// We scroll based on TIME in the Y direction.
	vec3 noise_pos = VERTEX * noise_scale + vec3(0.0, -TIME * scroll_speed, 0.0);
	// Map noise from [-1,1] to [0,1] range
	float n = noise(noise_pos) * 0.5 + 0.5;

	// 3. Combine mask and noise to define the flame shape
	// The noise "eats away" at the vertical mask.
	float flame_shape = vertical_mask * n;

	// 4. Color
	// Mix base color towards tip color based on height
	vec3 final_color = mix(color_tip, color_base, vertical_mask);
	// Make the very center bottom super bright
	final_color += vec3(0.5, 0.5, 0.2) * pow(vertical_mask, 3.0);

	// 5. Alpha Calculation (Visibility!)
	// Use smoothstep to create a solid core that fades out.
	// The '1.5' multiplier ensures the base stays visible.
	float alpha = smoothstep(0.1, 0.6, flame_shape * 1.5);

	ALBEDO = final_color;
	ALPHA = alpha;
}