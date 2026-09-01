shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D water_pattern : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D water_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 deep_color : source_color = vec4(0.075, 0.43, 0.52, 1.0);
uniform vec4 light_color : source_color = vec4(0.34, 0.82, 0.82, 1.0);
uniform vec2 tiling = vec2(3.6, 3.6);

void fragment() {
	vec2 moving_uv = UV * tiling + vec2(TIME * 0.010, TIME * 0.006);
	float ripple = texture(water_pattern, moving_uv).r;
	ALBEDO = mix(deep_color.rgb, light_color.rgb, 0.22 + ripple * 0.66);
	NORMAL_MAP = texture(water_normal, moving_uv * 1.13).rgb;
	NORMAL_MAP_DEPTH = 0.52;
	ROUGHNESS = 0.24;
	SPECULAR = 0.68;
}
