shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture  : source_color, hint_depth_texture,  filter_nearest;
uniform sampler2D normal_texture : source_color, hint_normal_roughness_texture, filter_nearest;

uniform vec3  outline_color : source_color = vec3(0.0); // black

uniform float depth_threshold         : hint_range(0, 2) = 0.10;
uniform float reverse_depth_threshold : hint_range(0, 2) = 0.25;
uniform float normal_threshold        : hint_range(0, 2) = 0.40;

uniform float thickness : hint_range(0.5, 6.0, 0.1) = 6.0; // outline width in pixels-ish
uniform float smoothness : hint_range(0.0, 0.1, 0.001) = 0.01; // edge softness

uniform vec3 normal_edge_bias = vec3(1.0, 1.0, 1.0);

float get_depth(vec2 screen_uv, mat4 inv_projection_matrix) {
	float depth = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	float depth  = get_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 normal  = texture(normal_texture, SCREEN_UV).xyz * 2.0 - 1.0;

	vec2 texel = (thickness / VIEWPORT_SIZE.xy);

	// 8-neighborhood for thicker / more continuous outline
	vec2 uvs[8];
	uvs[0] = SCREEN_UV + vec2( 0.0,  texel.y);
	uvs[1] = SCREEN_UV + vec2( 0.0, -texel.y);
	uvs[2] = SCREEN_UV + vec2( texel.x,  0.0);
	uvs[3] = SCREEN_UV + vec2(-texel.x,  0.0);
	uvs[4] = SCREEN_UV + vec2( texel.x,  texel.y);
	uvs[5] = SCREEN_UV + vec2( texel.x, -texel.y);
	uvs[6] = SCREEN_UV + vec2(-texel.x,  texel.y);
	uvs[7] = SCREEN_UV + vec2(-texel.x, -texel.y);

	// clamp to avoid sampling outside screen
	for (int i = 0; i < 8; i++) {
		uvs[i] = clamp(uvs[i], vec2(0.0), vec2(1.0));
	}

	float depth_diff = 0.0;
	float depth_diff_reversed = 0.0;

	float normal_sum = 0.0;

	for (int i = 0; i < 8; i++) {
		float d = get_depth(uvs[i], INV_PROJECTION_MATRIX);

		// accumulate depth discontinuity
		depth_diff += depth - d;
		depth_diff_reversed += d - depth;

		// accumulate normal discontinuity (biased)
		vec3 n = texture(normal_texture, uvs[i]).xyz * 2.0 - 1.0;
		vec3 normal_diff = normal - n;

		float normal_bias_diff = dot(normal_diff, normal_edge_bias);
		float normal_indicator = smoothstep(-0.01, 0.01, normal_bias_diff);

		normal_sum += dot(normal_diff, normal_diff) * normal_indicator;
	}

	// smooth masks (less jaggy than step)
	float depth_edge = smoothstep(depth_threshold - smoothness, depth_threshold + smoothness, depth_diff);

	float reverse_depth_edge = smoothstep(
		reverse_depth_threshold - smoothness,
		reverse_depth_threshold + smoothness,
		depth_diff_reversed
	);

	float indicator = sqrt(max(normal_sum, 0.0));
	float normal_edge = smoothstep(
		normal_threshold - smoothness,
		normal_threshold + smoothness,
		indicator - reverse_depth_edge
	);

	float edge = clamp(max(depth_edge, normal_edge), 0.0, 1.0);

	vec3 original = texture(screen_texture, SCREEN_UV).rgb;
	ALBEDO = mix(original, outline_color, edge);
}
