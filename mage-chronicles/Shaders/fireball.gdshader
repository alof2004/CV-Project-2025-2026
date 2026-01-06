shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 color_core : source_color = vec3(1.0, 0.8, 0.0);
uniform vec3 color_edge : source_color = vec3(1.0, 0.1, 0.0);
uniform float noise_scale = 2.0;
uniform float displacement_amount = 0.2; 
uniform float speed = 2.0;

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
	float n = noise(VERTEX * noise_scale + vec3(0.0, TIME * speed, 0.0));
	VERTEX += NORMAL * n * displacement_amount;
}

void fragment() {
	float n = noise(VERTEX * noise_scale + vec3(0.0, TIME * speed, 0.0));
	float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
	vec3 final_color = mix(color_core, color_edge, fresnel + n * 0.2);
	float alpha = clamp(fresnel * 1.5 + n * 0.5, 0.0, 1.0);
	ALBEDO = final_color;
	ALPHA = alpha;
}