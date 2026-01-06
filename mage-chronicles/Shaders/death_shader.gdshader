shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;

uniform vec3 burn_center = vec3(0.0);
uniform float radius = 0.0;
uniform float borderWidth = 0.25;
uniform float burnMult = 0.25;

uniform sampler2D noiseTexture : filter_linear_mipmap, repeat_enable;
uniform float noise_scale = 1.5;
uniform float noise_z_scale = 0.35;

uniform float blend_steps = 8.0;
uniform sampler2D colorCurve : source_color, filter_linear_mipmap;

varying vec3 v_world_pos;

float sample_noise_3d(vec3 p) {
    vec2 uv1 = p.xz * noise_scale;
    vec2 uv2 = p.xy * noise_scale + vec2(p.z * noise_z_scale);
    float a = texture(noiseTexture, uv1).b;
    float b = texture(noiseTexture, uv2).b;
    return mix(a, b, 0.5);
}

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec4 base = texture(albedo_texture, UV);

    float dist = distance(v_world_pos, burn_center);
    dist += sample_noise_3d(v_world_pos) * burnMult;

    
    float cut = step(dist, radius); 

    
    float edge = 1.0 - smoothstep(radius, radius + borderWidth, dist);
    edge *= (1.0 - cut); 

    
    float q = floor(edge * blend_steps) / blend_steps;

    
    vec3 curve_rgb = texture(colorCurve, vec2(q, 0.5)).rgb;

    
    float mix_amt = pow(edge, 0.4);
    ALBEDO = mix(base.rgb, curve_rgb, mix_amt);

    
    ALPHA = base.a * (1.0 - cut);
}
