shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 scroll_uv_per_sec = vec2(0.10, 0.0); // screen-UV units per second

void fragment() {
    vec2 suv = SCREEN_UV + TIME * scroll_uv_per_sec;

    // CanvasGroup builtin behavior (reads from backbuffer)
    vec4 c = textureLod(screen_texture, suv, 0.0);
    if (c.a > 0.0001) {
        c.rgb /= c.a;
    }

    COLOR *= c;
}
