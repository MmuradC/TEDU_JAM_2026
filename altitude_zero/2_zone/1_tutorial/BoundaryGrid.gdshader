shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 grid_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float grid_size = 20.0;
uniform float line_thickness = 0.1;
uniform float pulse_speed = 2.0;

void fragment() {
	vec2 uv = UV * grid_size;
	
	// Create pulsing effect
	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * 0.4 + 0.6;
	
	// Grid lines
	vec2 grid = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
	float line = min(grid.x, grid.y);
	float grid_mask = 1.0 - smoothstep(0.0, line_thickness, line);
	
	// Subtle zone fill
	float glow = 0.15;
	
	ALBEDO = grid_color;
	ALPHA = (grid_mask + glow) * pulse;
}
