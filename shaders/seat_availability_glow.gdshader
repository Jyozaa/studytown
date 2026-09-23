shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
instance uniform float glow_phase = 0.0;
instance uniform bool glow_nearest = false;
void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * 6.2831853 / 2.1 + glow_phase);
	ALBEDO = vec3(1.0);
	EMISSION = vec3(0.6);
	ALPHA = glow_nearest ? mix(0.22, 0.48, pulse) : mix(0.09, 0.27, pulse);
}
