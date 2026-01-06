shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded, specular_disabled;

uniform float size : hint_range(0.0, 0.5) = 0.5;         
uniform float size_inner : hint_range(0.01, 0.5) = 0.2;  


uniform sampler2D noise : repeat_enable, filter_linear;


uniform float noise_scale : hint_range(0.1, 20.0) = 3.0;
uniform float noise_speed : hint_range(0.0, 5.0) = 0.6;
uniform float noise_warp  : hint_range(0.0, 0.5) = 0.12;
uniform float edge_softness : hint_range(0.0001, 0.2) = 0.04;

uniform vec4 portalFrameColor : source_color = vec4(0.9, 0.2, 1.0, 1.0);
uniform vec4 portalHighlightColor : source_color = vec4(1.0, 0.6, 1.0, 1.0);
uniform vec4 inner : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec2 rotate_uv(vec2 uv, vec2 pivot, float angle_rad) {
	float s = sin(angle_rad);
	float c = cos(angle_rad);
	mat2 r = mat2(vec2(c, -s), vec2(s,  c));
	return (uv - pivot) * r + pivot;
}

void fragment() {
	vec2 center = vec2(0.5);
	float dist = length(UV - center);
	float outer = smoothstep(size, size - edge_softness, dist);
	float ang = radians(45.0) * TIME * 0.25;
	vec2 nuv = rotate_uv(UV * noise_scale, center * noise_scale, ang);
	nuv += vec2(TIME * noise_speed, -TIME * noise_speed);
	float n = texture(noise, nuv).r; 

	float inner_r = max(0.0, size - size_inner);
	float noisy_inner_r = inner_r + (n - 0.5) * noise_warp;

	float ring = smoothstep(noisy_inner_r, size, dist);
	float frame = smoothstep(size - edge_softness * 0.6, size, dist);

	vec3 col = inner.rgb;
	col = mix(col, portalHighlightColor.rgb, ring);
	col = mix(col, portalFrameColor.rgb, frame);
	
	ALBEDO = col;
	EMISSION = col;
	ALPHA = outer;
}
