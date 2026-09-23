shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/player_occlusion_window.gdshaderinc"

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform vec4 rough_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 metal_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float roughness_value = 1.0;
uniform float metallic_value = 0.0;
uniform float specular_value = 0.5;
uniform float normal_strength = 1.0;
uniform bool normal_enabled = false;
uniform bool ao_enabled = false;
uniform bool vertex_color_enabled = false;
uniform bool source_alpha = false;
uniform float alpha_cutoff = 0.0;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 1.0;
uniform bool emission_multiply = false;
uniform bool emission_has_texture = false;

void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
}

void fragment() {
	vec4 color = base_color * texture(base_texture, UV);
	if (vertex_color_enabled) { color *= COLOR; }
	if (color.a < alpha_cutoff) { discard; }
	ALBEDO = color.rgb;
	ROUGHNESS = roughness_value * dot(texture(rough_texture, UV), rough_channel);
	METALLIC = metallic_value * dot(texture(metal_texture, UV), metal_channel);
	SPECULAR = specular_value;
	if (normal_enabled) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	if (ao_enabled) { AO = dot(texture(ao_texture, UV), ao_channel); }
	vec3 glow = emission_has_texture ? texture(emission_texture, UV).rgb : (emission_multiply ? vec3(1.0) : vec3(0.0));
	EMISSION = (emission_multiply ? emission_color * glow : emission_color + glow) * emission_energy;
	ALPHA = (source_alpha ? color.a : 1.0) * xray_opacity(SCREEN_UV);
}
