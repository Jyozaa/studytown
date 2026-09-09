shader_type spatial;

// Garden-only ground treatment: retain the supplied lawn pattern, but keep
// its contrast subordinate to paths, water and characters. No bitmap rewrite.
uniform sampler2D lawn_pattern : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_pattern = false;
uniform vec4 shadow_grass : source_color = vec4(0.114, 0.169, 0.137, 1.0);
uniform vec4 sun_grass : source_color = vec4(0.196, 0.282, 0.192, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float broad = 0.5 + 0.25 * sin(p.x * 0.19 + sin(p.y * 0.12)) + 0.25 * cos(p.y * 0.24);
	float detail = has_pattern ? dot(texture(lawn_pattern, p * 0.042).rgb, vec3(0.25, 0.6, 0.15)) : 0.4;
	ALBEDO = mix(shadow_grass.rgb, sun_grass.rgb, clamp(0.28 + broad * 0.32 + detail * 0.40, 0.0, 1.0));
	ROUGHNESS = 0.95;
}
