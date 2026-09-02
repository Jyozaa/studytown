shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform vec4 water_colour : source_color = vec4(0.68, 0.91, 0.96, 0.72);
uniform vec4 foam_colour : source_color = vec4(0.96, 0.99, 1.0, 1.0);

void vertex() {
	// Microscopic motion keeps the streams alive without making the path shake.
	float wobble = sin(TIME * 2.8 + UV.y * 18.0 + UV.x * 4.0) * 0.004;
	VERTEX.x += wobble;
	VERTEX.z += cos(TIME * 2.35 + UV.y * 15.0) * 0.003;
}

void fragment() {
	// Two travelling bands create the white foamy look from the reference while
	// the underlying stream remains pale cyan and translucent.
	float flow_a = 0.5 + 0.5 * sin((UV.y * 8.0 - TIME * 2.65) * 6.283185);
	float flow_b = 0.5 + 0.5 * sin((UV.y * 19.0 - TIME * 4.10 + UV.x * 1.4) * 6.283185);

	float flow = flow_a * 0.64 + flow_b * 0.36;
	float foam = smoothstep(0.56, 0.92, flow);

	// Slight rim highlight around the tube.
	float edge = abs(UV.x - 0.5) * 2.0;
	float rim = smoothstep(0.50, 1.0, edge) * 0.16;

	ALBEDO = mix(water_colour.rgb, foam_colour.rgb, foam * 0.62 + rim);
	ALPHA = water_colour.a * (0.78 + foam * 0.20);
}
