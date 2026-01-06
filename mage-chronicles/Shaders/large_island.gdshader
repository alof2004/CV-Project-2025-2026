shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, ambient_light_disabled;

uniform vec3 lamp_pos;
uniform vec3 lamp_dir;
uniform float lamp_range;
uniform float inner_cos;
uniform float outer_cos;

uniform float min_visibility = 0.01;
uniform vec3 base_color : source_color = vec3(0.9);

varying vec3 v_wp;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 to_p = v_wp - lamp_pos;
	float d = length(to_p);
	if (d > lamp_range) discard;

	vec3 L = normalize(to_p);
	float cone = dot(normalize(lamp_dir), L);

	float cone_att = smoothstep(outer_cos, inner_cos, cone);
	float dist_att = clamp(1.0 - (d / lamp_range), 0.0, 1.0);

	float vis = cone_att * dist_att;
	if (vis < min_visibility) discard;

	ALBEDO = base_color * vis;
	ALPHA = 1.0;
}
