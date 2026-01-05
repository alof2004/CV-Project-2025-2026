shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float meltiness : hint_range(0.0, 16.0) = 4.0;
uniform float top_bias : hint_range(0.5, 8.0) = 2.5;

uniform float max_block_px : hint_range(1.0, 64.0) = 30.0;
uniform float pixelate_start : hint_range(0.0, 1.0) = 0.0;

// Fade controls
uniform float fade_start : hint_range(0.0, 1.0) = 0.2; // when black fade begins
uniform float fade_end   : hint_range(0.0, 1.0) = 0.5;
uniform float fade_power : hint_range(0.2, 4.0) = 1.5; // curve

float hash(float n) { return fract(sin(n) * 43758.5453123); }

void fragment() {
    float p = clamp((progress - pixelate_start) / max(1.0 - pixelate_start, 0.0001), 0.0, 1.0);
    p = p * p * (3.0 - 2.0 * p);

    float block_px = mix(1.0, max_block_px, p);

    vec2 uv = UV;

    vec2 b = vec2(block_px) * SCREEN_PIXEL_SIZE;
    vec2 uvb = (floor(uv / b) + 0.5) * b;

    float t = 1.0 - uvb.y;
    float fall = progress * pow(t, top_bias);

    float col = floor(uvb.x / b.x);
    float j = (hash(col) - 0.5) * meltiness * b.y;

    vec2 suv = uvb;
    suv.y += fall + j * progress;

    vec4 out_col;
    if (suv.y < 0.0 || suv.y > 1.0) {
        out_col = vec4(0.0);
    } else {
        out_col = texture(screen_texture, suv);
    }

    // Fade to black based on progress
    float f = clamp((progress - fade_start) / max(fade_end - fade_start, 0.0001), 0.0, 1.0);
    f = pow(f, fade_power);

    out_col.rgb = mix(out_col.rgb, vec3(0.0), f);
    // keep alpha at 1 so the fullscreen rect stays opaque during fade
    out_col.a = 1.0;

    COLOR = out_col;
}
