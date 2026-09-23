extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.get_node("GameState").persistence_enabled = false
	var app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var failures := 0
	var counts := {}
	for cycle in 3:
		for room in [0, 1, 2]:
			app.build_room(room)
			await create_timer(0.4).timeout
			var manager = app.world_root.get_node("PlayerOcclusionXRay")
			if not manager.is_warmed: await manager.warmed
			var budget = app.world_root.get_node("RoomRenderBudget")
			var observed: Array = [manager.records.size(), manager.materials.templates.size(), manager.dynamic_proxies.size(), app.study_spots.size(), app.npcs.size()]
			if counts.has(room) and counts[room] != observed: failures += 1
			counts[room] = observed
			if app.world_root.find_children("PlayerOcclusionXRay", "Node", false, false).size() != 1: failures += 1
			if manager.materials.material_copies != 0: failures += 1
			if room == 1 and (budget.grouped_emitters != 3 or app.study_spots.size() != 32): failures += 1
			print("LIFECYCLE cycle=", cycle, " room=", room, " counts=", observed, " resources=", Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), " memory_mb=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576)
	print("PERFORMANCE_LIFECYCLE failures=", failures)
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)
