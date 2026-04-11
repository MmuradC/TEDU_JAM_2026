shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec3 grass_color = vec3(0.1, 0.2, 0.05);
uniform vec3 dirt_color = vec3(0.2, 0.15, 0.1);
uniform float detail_scale = 50.0;
uniform float macro_scale = 0.01;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	
	// Base terrain mix based on large-scale noise
	float n = noise(uv * 5.0) * 0.5 + noise(uv * 20.0) * 0.25 + noise(uv * 100.0) * 0.125;
	vec3 base_color = mix(grass_color, dirt_color, n);
	
	// Detail texture blending
	vec4 tex = texture(albedo_texture, uv * detail_scale);
	float detail = (tex.r + tex.g + tex.b) / 3.0;
	vec3 final_color = base_color * mix(0.9, 1.1, detail);
	
	// Macro variation to avoid tiling
	float macro_n = noise(uv * macro_scale);
	final_color *= mix(0.8, 1.2, macro_n);
	
	ALBEDO = final_color;
	NORMAL = vec3(0.0, 1.0, 0.0);
	ROUGHNESS = 0.9;
}
