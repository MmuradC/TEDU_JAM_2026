shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_intensity = 0.4;
uniform float noise_amount = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	// Sample the screen texture
	vec4 color = texture(screen_texture, SCREEN_UV);
	
	// Vignette
	float dist = distance(UV, vec2(0.5));
	color.rgb *= smoothstep(0.8, 0.5, dist * vignette_intensity);
	
	// Subtle noise (Film Grain)
	float n = hash(UV + vec2(TIME * 0.01));
	color.rgb += (n - 0.5) * noise_amount;
	
	COLOR = color;
}
