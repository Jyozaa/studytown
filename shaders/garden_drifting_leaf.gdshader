shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_disable;
varying float ground_height;
void vertex() {
	float phase = TIME * 1.2 + INSTANCE_CUSTOM.x;
	float fade = smoothstep(0.0, 0.08, INSTANCE_CUSTOM.y) * (1.0 - smoothstep(0.78, 1.0, INSTANCE_CUSTOM.y));
	VERTEX *= fade;
	float tumble = phase * 1.7;
	VERTEX.yz = mat2(vec2(cos(tumble), -sin(tumble)), vec2(sin(tumble), cos(tumble))) * VERTEX.yz;
	VERTEX.x += sin(phase) * 0.16;
	VERTEX.y += sin(phase * 2.8) * 0.22;
	VERTEX.z += cos(phase * 0.8) * 0.13;
	ground_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	// Pointed-oval leaf silhouette with a subtle center vein. Combined with
	// the texture alpha so both plain quads and the authored leaf mesh shade
	// as leaves.
	float silhouette = (1.0 - abs(p.y)) * 0.62 + 0.06 - abs(p.x);
	vec4 texel = texture(leaf_tex, UV);
	float alpha = texel.a * smoothstep(-0.05, 0.05, silhouette);
	if (alpha < 0.03 || ground_height < 0.18) { discard; }
	ALBEDO = texel.rgb * COLOR.rgb * (0.82 + 0.18 * smoothstep(0.12, 0.0, abs(p.x)));
	ROUGHNESS = 0.9;
}
