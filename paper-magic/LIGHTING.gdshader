shader_type spatial;
render_mode blend_mix, cull_back, ambient_light_disabled;

uniform vec3 lamp_pos = vec3(0.0);
uniform vec3 lamp_dir = vec3(0.0, -1.0, 0.0); // world direction
uniform float lamp_range = 20.0;

uniform float inner_angle_deg = 10.0;
uniform float outer_angle_deg = 18.0;

uniform float threshold = 0.02;
uniform vec3 base_color : source_color = vec3(0.8, 0.8, 0.8);

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 to_p = v_world_pos - lamp_pos;
	float d = length(to_p);
	if (d > lamp_range) discard;

	vec3 L = normalize(to_p);
	float cone = dot(normalize(lamp_dir), L); // 1 = center of cone

	float ci = cos(radians(inner_angle_deg));
	float co = cos(radians(outer_angle_deg));

	float cone_att = smoothstep(co, ci, cone);
	float dist_att = clamp(1.0 - (d / lamp_range), 0.0, 1.0);

	float vis = cone_att * dist_att;
	if (vis < threshold) discard;

	ALBEDO = base_color * vis;
	ALPHA = 1.0;
}
