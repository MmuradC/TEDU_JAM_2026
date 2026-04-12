shader_type spatial;

uniform float map_size = 10000.0;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * (MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0))).xyz;
}

void fragment() {
	// Simple Grass Green
	vec3 grass = vec3(0.2, 0.3, 0.15);
	vec3 color = grass;
	
	// 1. Grid System (Every 500 meters)
	vec2 grid_uv = v_world_pos.xz / 500.0;
	vec2 grid = abs(fract(grid_uv - 0.5) - 0.5) / fwidth(grid_uv);
	float line = min(grid.x, grid.y);
	float grid_pattern = 1.0 - smoothstep(0.0, 0.05, line);
	color = mix(color, vec3(0.5, 0.5, 0.5), grid_pattern * 0.3);
	
	// 2. Detail Texture
	vec4 tex = texture(albedo_texture, v_world_pos.xz * 0.05);
	
	ALBEDO = color * mix(0.9, 1.1, tex.r);
	ROUGHNESS = 0.8;
}
