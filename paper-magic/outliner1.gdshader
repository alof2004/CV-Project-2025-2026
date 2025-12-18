shader_type canvas_item;

uniform sampler2D mask_tex;
uniform float thickness = 1.0;

void fragment() {
    vec4 base = texture(TEXTURE, UV);

    vec2 px = TEXTURE_PIXEL_SIZE * thickness;

    // Use alpha as the mask signal (background should be 0 with transparent_bg)
    float aC = texture(mask_tex, UV).a;
    float aR = texture(mask_tex, UV + vec2(px.x, 0.0)).a;
    float aL = texture(mask_tex, UV - vec2(px.x, 0.0)).a;
    float aU = texture(mask_tex, UV + vec2(0.0, px.y)).a;
    float aD = texture(mask_tex, UV - vec2(0.0, px.y)).a;

    float edge = max(max(abs(aC - aR), abs(aC - aL)), max(abs(aC - aU), abs(aC - aD)));
    edge = step(0.001, edge);

    // Take outline color from the mask RGB (so different items can have different colors)
    vec3 mask_rgb = texture(mask_tex, UV).rgb;
    vec4 outline = vec4(mask_rgb, 1.0);

    COLOR = mix(base, outline, edge);
}
