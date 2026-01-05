shader_type canvas_item;

uniform sampler2D source_tex : filter_nearest, repeat_disable;

uniform float edge_strength : hint_range(0.0, 10.0) = 1.0;
uniform vec4 stroke_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float stroke_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.15;
uniform float edge_smooth : hint_range(0.0, 1.0) = 0.05;

const float sobel_x[9] = float[](
	-1.0, 0.0, 1.0,
	-2.0, 0.0, 2.0,
	-1.0, 0.0, 1.0
);

const float sobel_y[9] = float[](
	-1.0, -2.0, -1.0,
	 0.0,  0.0,  0.0,
	 1.0,  2.0,  1.0
);

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE; // size of the TextureRect’s UV step DOES NOT work with source_tex
	// so compute texel from texture size:
	vec2 ts = vec2(textureSize(source_tex, 0));
	texel = 1.0 / ts;

	float gx = 0.0;
	float gy = 0.0;
	int index = 0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 uv_off = UV + vec2(float(x), float(y)) * texel;
			vec3 c = texture(source_tex, uv_off).rgb;
			float value = dot(c, vec3(0.299, 0.587, 0.114));
			gx += value * sobel_x[index];
			gy += value * sobel_y[index];
			index++;
		}
	}

	float edge = length(vec2(gx, gy)) * edge_strength;
	float mask = smoothstep(edge_threshold, edge_threshold + edge_smooth, edge);

	COLOR = vec4(stroke_color.rgb, mask * stroke_color.a * stroke_opacity);
}
