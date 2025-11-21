shader_type canvas_item;

uniform sampler2D screen_tex : source_color;
uniform vec2 pixel_count = vec2(180.0, 180.0);

void fragment() {
    vec2 uv = UV;
    uv *= pixel_count;
    uv = floor(uv);
    uv /= pixel_count;
    COLOR = texture(screen_tex, uv);
}
