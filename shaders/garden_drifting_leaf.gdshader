shader_type spatial;
render_mode cull_disabled;
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
	if (dot(p,p) > 1.0 || ground_height < 0.18) { discard; }
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
