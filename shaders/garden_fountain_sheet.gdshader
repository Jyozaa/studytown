shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform vec4 water_colour : source_color = vec4(0.62, 0.89, 0.96, 0.52);
uniform vec4 foam_colour : source_color = vec4(0.96, 0.99, 1.0, 0.92);

void fragment() {
	// UV.y runs from the jet apex (0) down the falling umbrella (1).
	float vertical_flow =
		0.5 + 0.5 * sin((UV.y * 16.0 - TIME * 3.25 + UV.x * 3.0) * 6.283185);
	float fine_flow =
		0.5 + 0.5 * sin((UV.y * 31.0 - TIME * 5.0 - UV.x * 9.0) * 6.283185);
	float angular_breakup =
		0.5 + 0.5 * sin((UV.x * 13.0 + UV.y * 2.7 + TIME * 0.55) * 6.283185);

	float flow = vertical_flow * 0.56 + fine_flow * 0.28 + angular_breakup * 0.16;
	float foam = smoothstep(0.56, 0.90, flow);

	// The sheet is denser close to the apex and along fast/foamy streaks, while
	// the rest remains translucent enough that it never reads as solid glass.
	float fall = smoothstep(0.0, 0.22, UV.y);
	float broken_alpha = 0.20 + flow * 0.24 + foam * 0.20;
	float alpha = mix(0.66, broken_alpha, fall);

	ALBEDO = mix(water_colour.rgb, foam_colour.rgb, foam * 0.68);
	ALPHA = alpha;
}
