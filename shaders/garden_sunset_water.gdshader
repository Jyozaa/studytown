shader_type spatial;
render_mode cull_back;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	float wave = sin(p.x * 2.2 + p.y * 1.4 + TIME * 0.65) * cos(p.y * 3.1 - TIME * 0.4);
	float depth = smoothstep(0.3, 0.85, length((p - vec2(0.0,-1.0)) / vec2(10.5,7.0)));
	ALBEDO = mix(vec3(0.025,0.058,0.076), vec3(0.047,0.094,0.109), depth);
	NORMAL_MAP = vec3(0.5 + 0.025 * wave, 0.5 + 0.025 * sin(p.y * 2.1 + TIME * 0.5), 1.0);
	ROUGHNESS = 0.22 + wave * 0.035;
	METALLIC = 0.22;
	SPECULAR = 0.8;
}
