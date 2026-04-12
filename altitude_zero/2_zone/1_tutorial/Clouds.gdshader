shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_texture;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.7;
uniform float scrolling_speed = 0.02;
uniform vec4 cloud_color : source_color = vec4(0.9, 0.9, 1.0, 0.95);
uniform float height_intensity = 30.0;

varying float v_height;

void vertex() {
	vec2 uv = UV + vec2(TIME * scrolling_speed);
	float h = texture(noise_texture, uv).r;
	VERTEX.y += h * height_intensity;
	v_height = h;
}

void fragment() {
	// FIX: Ensure both sides are lit correctly or use emission
	vec2 uv1 = UV + vec2(TIME * scrolling_speed, TIME * scrolling_speed * 0.5);
	vec2 uv2 = UV - vec2(TIME * scrolling_speed * 0.7, TIME * 0.01);
	
	float n1 = texture(noise_texture, uv1).r;
	float n2 = texture(noise_texture, uv2 * 2.0).r;
	float combined_noise = (n1 * 0.6 + n2 * 0.4);
	
	float alpha = smoothstep(1.0 - cloud_density, 1.0, combined_noise);
	
	// COLOR & LIGHTING
	// Use some emission to ensure they are visible from the bottom
	vec3 base_col = cloud_color.rgb * mix(0.6, 1.2, v_height);
	
	ALBEDO = base_col;
	EMISSION = base_col * 0.2; // Subtle self-glow for visibility
	ALPHA = alpha * cloud_color.a;
	
	// Backface Normal fix (optional but good for lighting)
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
