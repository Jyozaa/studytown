shader_type particles;
render_mode disable_velocity;
uniform vec4 tint_a : source_color;
uniform vec4 tint_b : source_color;
float random_value(float seed) { return fract(sin(seed * 12.9898) * 43758.5453); }
void start() {
	float seed = float(NUMBER) + float(RANDOM_SEED % 65536u);
	float a = random_value(seed);
	float b = random_value(seed + 3.1);
	float c = random_value(seed + 7.4);
	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xyz += vec3((a - 0.5) * 3.2, (b - 0.5) * 0.9, (c - 0.5) * 2.7);
	float size = mix(0.65, 1.0, c);
	TRANSFORM[0].xyz *= size;
	TRANSFORM[1].xyz *= size;
	TRANSFORM[2].xyz *= size;
	VELOCITY = vec3(0.12 + a * 0.08, -0.38 - b * 0.16, -0.10 - c * 0.07);
	CUSTOM = vec4(a * TAU, 0.0, c, 0.0);
	COLOR = mix(tint_a, tint_b, b);
}
void process() {
	CUSTOM.y += DELTA / LIFETIME;
	CUSTOM.x += DELTA * mix(-1.0, 1.1, CUSTOM.z);
	VELOCITY += vec3(0.022, -0.045, -0.018) * DELTA;
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	if (CUSTOM.y >= 1.0) { ACTIVE = false; }
}
