extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.get_node("GameState").persistence_enabled = false
	var app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.current_room_name = root.get_node("GameState").ROOMS[1]
	app.build_room(1)
	# Exclude import/shader and initial one-second FPS sampling warmup.
	await create_timer(5).timeout
	var samples: Array[int] = []
	for i in 8:
		await create_timer(1).timeout
		samples.append(Engine.get_frames_per_second())
	var total := 0
	for sample in samples:
		total += sample
	print(
		"GARDEN_WARM_PERF fps_samples=",
		samples,
		" average=",
		float(total) / samples.size(),
		" draw_calls=",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=",
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	)
	app.queue_free()
	await process_frame
	quit()
