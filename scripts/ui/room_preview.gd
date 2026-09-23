extends RefCounted

# Generates one-shot, low-resolution previews from the actual editable room
# scenes so the dashboard stays in sync with the rooms.

const ROOM_SCENES := {
	"library": "res://assets/dev_local/room_layouts/library.tscn",
	"garden": "res://assets/dev_local/room_layouts/garden.tscn",
	"train": "res://assets/dev_local/room_layouts/train.tscn",
	"japanese": "res://assets/dev_local/room_layouts/japanese.tscn",
}

const ROOM_CAMERAS := {
	"library":
	{
		"position": Vector3(5.2, 4.4, 9.3),
		"target": Vector3(0.0, 1.0, 2.3),
		"fov": 40.0,
	},
	"garden":
	{
		"position": Vector3(12.0, 8.0, 13.5),
		"target": Vector3(0.0, 1.0, 0.0),
		"fov": 47.0,
	},
	"train":
	{
		"position": Vector3(0.1, 3.1, 9.5),
		"target": Vector3(0.0, 1.3, -1.0),
		"fov": 46.0,
	},
	"japanese":
	{
		"position": Vector3(9.0, 6.8, 11.0),
		"target": Vector3(0.0, 1.2, 0.0),
		"fov": 46.0,
	},
}


static func make_preview(room_id: String, size_value := Vector2i(240, 170)) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size_value.x, size_value.y)
	holder.clip_contents = true
	if DisplayServer.get_name() == "headless":
		return holder

	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = size_value
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.own_world_3d = true
	container.add_child(viewport)
	# Menu thumbnails are static by design (see UPDATE_ONCE above), but the
	# mode does not hold once the viewport joins the live menu tree: it keeps
	# re-rendering full rooms every frame (~8k draws in the menu). Freeze the
	# viewport after its first presents so the thumbnail stays a still image.
	viewport.tree_entered.connect(_freeze_after_present.bind(viewport), CONNECT_ONE_SHOT)

	var scene_path := str(ROOM_SCENES.get(room_id, ""))

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		var fallback := ColorRect.new()
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.color = Color("#8c775c")
		holder.add_child(fallback)
		return holder

	var packed := preload("res://scripts/performance/room_resource_cache.gd").get_scene(scene_path)

	if packed == null:
		return holder

	var room := packed.instantiate()
	room.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(room)
	if room_id == "garden":
		# Garden carries its own authored afternoon lighting. Extra preview
		# lights washed out the new pond/grass and doubled the key exposure.
		var pond_camera := Camera3D.new()
		viewport.add_child(pond_camera)
		pond_camera.position = Vector3(17, 15, 21)
		pond_camera.look_at_from_position(pond_camera.position, Vector3(0, 1, -1))
		pond_camera.fov = 52
		pond_camera.current = true
		return holder

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#8a7965")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#ffe7bb")
	environment.ambient_light_energy = 0.85
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var key := room_id if ROOM_CAMERAS.has(room_id) else "library"

	var camera_data: Dictionary = ROOM_CAMERAS[key]

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	light.light_color = Color("#ffd59a")
	light.light_energy = 1.25
	viewport.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-4.0, 6.0, 5.0)
	fill.light_color = Color("#fff0cd")
	fill.light_energy = 2.2
	fill.omni_range = 22.0
	viewport.add_child(fill)

	var camera := Camera3D.new()
	camera.position = camera_data["position"]
	camera.fov = float(camera_data["fov"])
	viewport.add_child(camera)
	camera.look_at_from_position(camera.position, camera_data["target"])
	camera.current = true

	return holder


static func _freeze_after_present(viewport: SubViewport) -> void:
	if not is_instance_valid(viewport):
		return
	var tree := viewport.get_tree()
	if tree == null:
		return
	# Weakref: the menu tree (and this viewport) is freed on room change while
	# the timer may still be pending. A direct lambda capture would error when
	# the timer fires after the viewport is gone.
	var ref: WeakRef = weakref(viewport)
	tree.create_timer(1.5).timeout.connect(func() -> void: _disable_viewport(ref))


static func _disable_viewport(ref: WeakRef) -> void:
	var viewport := ref.get_ref() as SubViewport
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
