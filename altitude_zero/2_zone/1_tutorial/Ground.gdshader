shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform vec3 grass_color : source_color = vec3(0.12, 0.22, 0.06);
uniform vec3 dirt_color : source_color = vec3(0.28, 0.20, 0.12);
uniform vec3 rock_color : source_color = vec3(0.35, 0.32, 0.28);
uniform vec3 snow_color : source_color = vec3(0.92, 0.93, 0.95);

uniform float detail_scale = 40.0;
uniform float macro_scale = 0.008;
uniform float slope_threshold = 0.6;
uniform float snow_height = 0.85;
uniform float blend_sharpness = 4.0;

float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

// 4-octave FBM for richer detail
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV;

    // Triplanar-style detail texture (use UV for now, scale tightly)
    vec4 tex = texture(albedo_texture, uv * detail_scale);
    vec4 norm_tex = texture(normal_texture, uv * detail_scale);
    float roughness_val = texture(roughness_texture, uv * detail_scale).r;

    // Macro variation to break tiling
    float macro = fbm(uv * macro_scale * 300.0);

    // Fine noise blend
    float fine = fbm(uv * 8.0) * 0.6 + fbm(uv * 32.0) * 0.3 + fbm(uv * 128.0) * 0.1;

    // Slope from normal (approximated via noise gradient)
    float slope = clamp(fbm(uv * 4.0 + 0.5) * 1.8, 0.0, 1.0);

    // Height approximation from macro noise
    float height = macro;

    // --- Layer blending ---

    // Grass vs Dirt based on noise
    float grass_dirt = smoothstep(0.45, 0.65, fine);
    vec3 base = mix(grass_color, dirt_color, grass_dirt);

    // Blend in rock on steep slopes
    float rock_blend = smoothstep(slope_threshold, slope_threshold + 0.2, slope);
    base = mix(base, rock_color, rock_blend);

    // Blend in snow at high elevation
    float snow_blend = smoothstep(snow_height - 0.05, snow_height + 0.05, height);
    snow_blend *= (1.0 - rock_blend * 0.8); // Less snow on steep rocks
    base = mix(base, snow_color, snow_blend);

    // Apply texture detail multiplicatively
    float detail = (tex.r + tex.g + tex.b) / 3.0;
    base *= mix(0.85, 1.15, detail);

    // Macro color variation
    base *= mix(0.82, 1.18, macro);

    // Subtle color temperature shift (warmer in low areas, cooler up high)
    base = mix(base * vec3(1.04, 1.0, 0.96), base * vec3(0.97, 0.99, 1.03), height);

    ALBEDO = base;
    NORMAL_MAP = norm_tex.rgb;
    NORMAL_MAP_DEPTH = 0.6;
    ROUGHNESS = mix(0.85, 0.95, roughness_val) * mix(1.0, 0.7, snow_blend);
    SPECULAR = mix(0.02, 0.15, snow_blend); // Snow is slightly more specular
    AO = mix(0.9, 1.0, macro);
    AO_LIGHT_AFFECT = 0.4;
}