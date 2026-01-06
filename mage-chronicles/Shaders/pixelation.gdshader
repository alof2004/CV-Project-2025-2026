shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 pixel_count = vec2(320.0, 180.0); 

void fragment() {
    vec2 uv = SCREEN_UV;
    uv = floor(uv * pixel_count) / pixel_count;
    COLOR = texture(screen_tex, uv);
}

