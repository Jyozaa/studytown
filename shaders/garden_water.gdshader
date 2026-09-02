shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform vec4 deep_color : source_color = vec4(0.10, 0.58, 0.68, 1.0);
uniform vec4 light_color : source_color = vec4(0.42, 0.91, 0.92, 1.0);

void fragment() {
	vec2 uv = UV * 7.0;

	float wave_a = sin((uv.x * 0.86 + uv.y * 0.52 + TIME * 0.42) * 6.283185);
	float wave_b = sin((uv.x * -0.48 + uv.y * 1.12 - TIME * 0.31) * 6.283185);
	float wave_c = sin((uv.x + uv.y * -0.70 + TIME * 0.18) * 12.56637);

	float ripple = wave_a * 0.38 + wave_b * 0.38 + wave_c * 0.24;
	ripple = ripple * 0.5 + 0.5;

	vec3 colour = mix(deep_color.rgb, light_color.rgb, 0.18 + ripple * 0.28);
	ALBEDO = colour;
	ROUGHNESS = 0.10 + (1.0 - ripple) * 0.10;
	METALLIC = 0.02;
	SPECULAR = 0.82;
	ALPHA = 0.88;
}
