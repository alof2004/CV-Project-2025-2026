shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float meltiness : hint_range(0.0, 16.0) = 4.0;
uniform float top_bias : hint_range(0.5, 8.0) = 2.5;

// How pixelated it gets at progress=1.0
uniform float max_block_px : hint_range(1.0, 64.0) = 30.0;

// When to start pixelating (0 = immediately, 0.3 = after some dissolve)
uniform float pixelate_start : hint_range(0.0, 1.0) = 0;

float hash(float n) { return fract(sin(n) * 43758.5453123); }

void fragment() {
    // Map progress -> pixelation amount (0..1)
    float p = clamp((progress - pixelate_start) / max(1.0 - pixelate_start, 0.0001), 0.0, 1.0);

    // Smooth it so it ramps nicely
    p = p * p * (3.0 - 2.0 * p); // smoothstep

    // Block size: 1px normally, grows during dissolve
    float block_px = mix(1.0, max_block_px, p);

    vec2 uv = UV;

    // Pixelate: snap UV to block grid (using block_px)
    vec2 b = vec2(block_px) * SCREEN_PIXEL_SIZE;
    vec2 uvb = (floor(uv / b) + 0.5) * b;

    // Melt (based on block coords so it stays chunky)
    float t = 1.0 - uvb.y;
    float fall = progress * pow(t, top_bias);

    float col = floor(uvb.x / b.x);
    float j = (hash(col) - 0.5) * meltiness * b.y;

    vec2 suv = uvb;
    suv.y += fall + j * progress;

    if (suv.y < 0.0 || suv.y > 1.0) {
        COLOR = vec4(0.0);
    } else {
        COLOR = texture(screen_texture, suv);
    }
}
