extends CanvasLayer

var main
var label: Label
var clock := 0.0
var frames := 0
var lights: Array = []
var emitters: Array = []

func configure(owner_node) -> void:
	main = owner_node
	layer = 120
	label = Label.new()
	label.position = Vector2(20, 100)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)
	lights = main.world_root.find_children("*", "Light3D", true, false)
	emitters = main.world_root.find_children("*", "GPUParticles3D", true, false)

func _process(delta: float) -> void:
	clock += delta
	frames += 1
	if clock < 0.5: return
	var particle_count := 0
	var shadow_count := 0
	for emitter in emitters:
		if is_instance_valid(emitter) and emitter.emitting: particle_count += emitter.amount
	for light in lights:
		if is_instance_valid(light) and light.shadow_enabled: shadow_count += 1
	var xray = main.world_root.get_node_or_null("PlayerOcclusionXRay")
	label.text = "PERFORMANCE · %s · %s\n%.0f FPS · %.2f ms/frame · physics %.2f ms\n%.0f draws · %.0f objects · %.0f primitives\n%d lights / %d shadowed · %d leaves · %d NPCs · %d seats\nX-ray %d active · %.0f rays/s · %.3f ms · %d shared materials / %d prepared\nGPU time: unavailable in this Compatibility driver" % [main.current_room_config.id, preload("res://scripts/performance/graphics_quality.gd").selected(), frames / clock, clock * 1000 / frames, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), lights.size(), shadow_count, particle_count, main.npcs.size(), main.study_spots.size(), xray.active.size() if xray else 0, xray.query_rate if xray else 0, xray.detection_usec / 1000.0 if xray else 0, xray.materials.templates.size() if xray else 0, xray.records.size() if xray else 0]
	clock = 0.0
	frames = 0
