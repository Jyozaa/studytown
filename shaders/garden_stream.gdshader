shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform vec4 water_colour : source_color = vec4(0.62, 0.89, 0.96, 0.72);
uniform vec4 foam_colour : source_color = vec4(0.96, 0.99, 1.0, 1.0);

void vertex() {
	float wobble = sin(TIME * 2.8 + UV.y * 18.0 + UV.x * 4.0) * 0.003;
	VERTEX.x += wobble;
	VERTEX.z += cos(TIME * 2.35 + UV.y * 15.0) * 0.0025;
}

void fragment() {
	float flow_a = 0.5 + 0.5 * sin((UV.y * 8.0 - TIME * 2.65) * 6.283185);
	float flow_b = 0.5 + 0.5 * sin((UV.y * 19.0 - TIME * 4.10 + UV.x * 1.4) * 6.283185);

	float flow = flow_a * 0.64 + flow_b * 0.36;
	float foam = smoothstep(0.56, 0.92, flow);

	float edge = abs(UV.x - 0.5) * 2.0;
	float rim = smoothstep(0.50, 1.0, edge) * 0.14;

	// Slightly denser toward UV.y=1, matching the geometry that gets thicker
	// toward the landing end of each side jet.
	float end_density = smoothstep(0.50, 1.0, UV.y) * 0.10;

	ALBEDO = mix(water_colour.rgb, foam_colour.rgb, foam * 0.60 + rim);
	ALPHA = water_colour.a * (0.76 + foam * 0.18 + end_density);
}
