instance uniform vec2 xray_center : instance_index(0) = vec2(0.5);
instance uniform vec2 xray_viewport : instance_index(1) = vec2(1280.0, 720.0);
instance uniform vec2 xray_radius : instance_index(2) = vec2(100.0, 130.0);
instance uniform float xray_strength : instance_index(3) = 0.0;

float xray_opacity(vec2 screen_uv) {
	vec2 pixel = screen_uv * xray_viewport;
	float cell_size = 7.0 * max(xray_viewport.y / 720.0, 0.5);
	vec2 cell = floor(pixel / cell_size);
	vec2 stepped = (cell + 0.5) * cell_size;
	float noise = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float smooth_distance = length((pixel - xray_center * xray_viewport) / xray_radius);
	float block_distance = length((stepped - xray_center * xray_viewport) / xray_radius);
	// The centre stays soft. Only the feather uses stable, square noise cells.
	float edge = mix(smooth_distance, block_distance, smoothstep(0.50, 0.75, smooth_distance));
	edge += (noise - 0.5) * 0.13 * smoothstep(0.50, 0.75, smooth_distance);
	float window = 1.0 - smoothstep(0.62, 1.03, edge);
	return 1.0 - window * xray_strength * 0.96;
}
