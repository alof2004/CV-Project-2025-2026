shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

// Melt controls
uniform float meltiness : hint_range(0.0, 0.5) = 0.15;   // amount of random column offset (UV units)
uniform float top_bias  : hint_range(0.5, 8.0) = 2.5;    // stronger effect near the top

// Fade controls
uniform float fade_start : hint_range(0.0, 1.0) = 0.2;
uniform float fade_end   : hint_range(0.0, 1.0) = 0.5;
uniform float fade_power : hint_range(0.2, 4.0) = 1.5;

uniform float columns : hint_range(8.0, 400.0) = 120.0;

float hash(float n) { return fract(sin(n) * 43758.5453123); }

float smooth01(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}

void fragment() {
	float p = smooth01(progress);
	vec2 uv = UV;
	float col = floor(uv.x * columns);
	float r = hash(col);
	float t = 1.0 - uv.y;
	float fall = p * pow(t, top_bias);
	float drift = (r - 0.5) * meltiness * p;
	vec2 suv = uv;
	suv.y += fall + drift;
	vec4 out_col = vec4(0.0);
	if (suv.y >= 0.0 && suv.y <= 1.0) {
		out_col = texture(screen_texture, suv);
	}
	float f = 0.0;
	if (fade_end > fade_start) {
		f = clamp((progress - fade_start) / (fade_end - fade_start), 0.0, 1.0);
		f = pow(f, fade_power);
	}
	out_col.rgb = mix(out_col.rgb, vec3(0.0), f);
	out_col.a = 1.0;

	COLOR = out_col;
}
