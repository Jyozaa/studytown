extends RefCounted


static func make_character_preview(
	character_loader,
	index: int,
	size_value := Vector2i(220, 190),
	headshot := false,
	fallback_override: Callable = Callable()
) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(size_value.x, size_value.y)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() == "headless":
		return container

	var viewport := SubViewport.new()
	viewport.size = size_value
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.own_world_3d = true
	container.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.TRANSPARENT
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d9e8ff")
	environment.ambient_light_energy = 1.05
	environment_node.environment = environment
	world.add_child(environment_node)

	var fallback_factory := func(parent_node: Node, _variant: int, _seated: bool) -> Node3D:
		var fallback_root := Node3D.new()
		parent_node.add_child(fallback_root)

		var mesh_instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.62
		sphere.height = 1.24
		mesh_instance.mesh = sphere
		mesh_instance.position.y = 1.1

		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#d7b27a")
		mesh_instance.material_override = material
		fallback_root.add_child(mesh_instance)

		return fallback_root

	var character: Node3D = character_loader.create_character(
		world, index, fallback_override if fallback_override.is_valid() else fallback_factory, false
	)

	if is_instance_valid(character):
		character.rotation.y += PI
		character.scale *= (1.03 if headshot else 0.86)

		character_loader.play_animation(character, "Idle", 0.0)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	key.light_color = Color("#fff0cd")
	key.light_energy = 1.30
	world.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.5, 3.2, 3.2)
	fill.light_color = Color("#b8d4ff")
	fill.light_energy = 2.1
	fill.omni_range = 8.5
	world.add_child(fill)

	var camera := Camera3D.new()

	if headshot:
		camera.position = Vector3(2.4, 2.05, 4.0)
		camera.fov = 24.0
		world.add_child(camera)
		camera.look_at_from_position(camera.position, Vector3(0.0, 1.66, 0.0))
	else:
		camera.position = Vector3(3.1, 2.45, 5.2)
		camera.fov = 24.0
		world.add_child(camera)
		camera.look_at_from_position(camera.position, Vector3(0.0, 1.34, 0.0))

	camera.current = true

	return container
