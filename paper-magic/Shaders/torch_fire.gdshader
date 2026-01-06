shader_type spatial;

render_mode unshaded, cull_disabled, blend_add;

uniform vec3 color_base : source_color = vec3(1.0, 0.7, 0.1); 
uniform vec3 color_tip : source_color = vec3(0.8, 0.1, 0.0);  
uniform float scroll_speed = 2.5;
uniform float noise_scale = 3.0;


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
	
	
	float taper = mix(0.6, 1.2, UV.y);
	VERTEX.xz *= taper;
}

void fragment() {
	
	
	float vertical_mask = smoothstep(0.1, 0.9, UV.y);

	
	
	vec3 noise_pos = VERTEX * noise_scale + vec3(0.0, -TIME * scroll_speed, 0.0);
	
	float n = noise(noise_pos) * 0.5 + 0.5;

	
	
	float flame_shape = vertical_mask * n;

	
	
	vec3 final_color = mix(color_tip, color_base, vertical_mask);
	
	final_color += vec3(0.5, 0.5, 0.2) * pow(vertical_mask, 3.0);

	
	
	
	float alpha = smoothstep(0.1, 0.6, flame_shape * 1.5);

	ALBEDO = final_color;
	ALPHA = alpha;
}