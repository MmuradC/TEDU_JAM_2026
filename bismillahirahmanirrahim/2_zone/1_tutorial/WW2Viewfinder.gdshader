shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float grain_amount = 0.2;
uniform float vignette_softness = 0.5;
uniform float lens_distortion = 0.15;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 screen_uv_to_centered(vec2 uv) {
	return uv * 2.0 - 1.0;
}

void fragment() {
	vec2 uv = UV;
	
	// SQUARE CROP MASK (Centered)
	float aspect = 16.0 / 9.0;
	float square_width = 1.0 / aspect;
	float margin = (1.0 - square_width) / 2.0;
	
	if (uv.x < margin || uv.x > 1.0 - margin) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// OLD LENS DISTORTION (Barrel)
		vec2 centered_uv = screen_uv_to_centered(SCREEN_UV);
		float d_sq = dot(centered_uv, centered_uv);
		vec2 distorted_uv = SCREEN_UV + centered_uv * d_sq * lens_distortion;
		
		// Sample original color with distortion
		vec4 color = texture(screen_texture, distorted_uv);
		
		// BLACK & WHITE CONVERSION
		float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		color.rgb = vec3(gray);
		
		// FILM GRAIN
		float noise = hash(uv + vec2(TIME * 0.1));
		color.rgb += (noise - 0.5) * grain_amount;
		
		// SCRATCHES
		float scratch = step(0.992, hash(vec2(uv.x * 0.1 + TIME * 0.2, 0.5)));
		color.rgb = mix(color.rgb, vec3(1.0), scratch * 0.4);
		
		// INTERNAL VIGNETTE
		float dist_center = distance(uv, vec2(0.5));
		float v = smoothstep(0.48, 0.3, dist_center);
		color.rgb *= v;
		
		COLOR = color;
	}
}
