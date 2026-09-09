shader_type sky;
uniform vec4 zenith : source_color = vec4(0.314,0.380,0.490,1.0);
uniform vec4 middle : source_color = vec4(0.455,0.447,0.561,1.0);
uniform vec4 horizon : source_color = vec4(0.851,0.569,0.412,1.0);
void sky() {
	float elevation = max(EYEDIR.y, 0.0);
	vec3 gradient = mix(horizon.rgb, middle.rgb, smoothstep(0.0, 0.22, elevation));
	gradient = mix(gradient, zenith.rgb, smoothstep(0.16, 0.65, elevation));
	if (EYEDIR.y < 0.0) {
		gradient = mix(horizon.rgb, vec3(0.03,0.052,0.039), smoothstep(0.0, 0.30, -EYEDIR.y));
	}
	if (LIGHT0_ENABLED) {
		float alignment = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
		gradient += vec3(1.0,0.56,0.26) * pow(alignment, 42.0) * 0.10;
		gradient += vec3(1.0,0.77,0.49) * smoothstep(0.9996, 0.99986, alignment) * 1.5;
	}
	COLOR = gradient;
}
