extends RefCounted

# Generates one-shot, low-resolution previews from the actual editable room
# scenes so the scrapbook postcards stay in sync with the rooms.

const ROOM_SCENES := {
	"library": "res://assets/dev_local/room_layouts/library.tscn",
	"garden": "res://assets/dev_local/room_layouts/garden.tscn",
	"train": "res://assets/dev_local/room_layouts/train.tscn",
	"japanese": "res://assets/dev_local/room_layouts/japanese.tscn",
}

const ROOM_CAMERAS := {
	"library": {
		"position": Vector3(10.5, 6.8, 12.5),
		"target": Vector3(0.0, 1.6, 0.0),
		"fov": 44.0,
	},
	"garden": {
		"position": Vector3(12.0, 8.0, 13.5),
		"target": Vector3(0.0, 1.0, 0.0),
		"fov": 47.0,
	},
	"train": {
		"position": Vector3(4.5, 3.4, 10.0),
		"target": Vector3(0.0, 1.6, 3.5),
		"fov": 46.0,
	},
	"japanese": {
		"position": Vector3(9.0, 6.8, 11.0),
		"target": Vector3(0.0, 1.2, 0.0),
		"fov": 46.0,
	},
}


static func make_preview(
	room_id: String,
	size_value := Vector2i(240, 170)
) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(
		size_value.x,
		size_value.y
	)
	holder.clip_contents = true

	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = size_value
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.own_world_3d = true
	container.add_child(viewport)

	var scene_path := str(
		ROOM_SCENES.get(
			room_id,
			""
		)
	)

	if (
		scene_path.is_empty()
		or not ResourceLoader.exists(scene_path)
	):
		var fallback := ColorRect.new()
		fallback.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		fallback.color = Color("#8c775c")
		holder.add_child(fallback)
		return holder

	var packed := load(scene_path) as PackedScene

	if packed == null:
		return holder

	var room := packed.instantiate()
	room.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(room)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#8a7965")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#ffe7bb")
	environment.ambient_light_energy = 0.85
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var key := (
		room_id
		if ROOM_CAMERAS.has(room_id)
		else "library"
	)

	var camera_data: Dictionary = ROOM_CAMERAS[key]

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(
		-48.0,
		-30.0,
		0.0
	)
	light.light_color = Color("#ffd59a")
	light.light_energy = 1.25
	viewport.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(
		-4.0,
		6.0,
		5.0
	)
	fill.light_color = Color("#fff0cd")
	fill.light_energy = 2.2
	fill.omni_range = 22.0
	viewport.add_child(fill)

	var camera := Camera3D.new()
	camera.position = camera_data["position"]
	camera.fov = float(camera_data["fov"])
	viewport.add_child(camera)
	camera.look_at_from_position(
		camera.position,
		camera_data["target"]
	)
	camera.current = true

	return holder
