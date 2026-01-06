shader_type spatial;

render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color;
uniform vec4 tint : source_color = vec4(0.4, 0.9, 0.4, 1.0);
uniform vec2  wind_dir = vec2(1.0, 0.2);        
uniform float wind_strength : hint_range(0, 1.5) = 0.25;
uniform float wind_speed    : hint_range(0.0, 10.0) = 1.5;
uniform float wind_freq     : hint_range(0.0, 10.0) = 2.0;
uniform float bend_power    : hint_range(0.5, 6.0) = 2.0;

uniform float alpha_scissor : hint_range(0,1) = 0.4;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

void vertex() {
    vec2 dir = normalize(wind_dir);

    float w = pow(clamp(UV.y, 0.0, 1.0), bend_power);

    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    float rnd = hash1(float(INSTANCE_ID) + 1.2345);

    float phase = dot(world_pos.xz, dir) * wind_freq + TIME * wind_speed + rnd * 6.2831853;

    float sway = sin(phase) + 0.5 * sin(phase * 2.17);

    VERTEX.x += dir.x * sway * wind_strength * w;
    VERTEX.z += dir.y * sway * wind_strength * w;
}

void fragment() {
    vec4 tex = texture(albedo_tex, UV);

    vec4 col = tex * tint;      
    ALBEDO = col.rgb;
    ALPHA  = col.a;

    ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
}