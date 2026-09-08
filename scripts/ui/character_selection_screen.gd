extends Control

signal character_chosen(index: int)
signal closed

const CREAM := Color("#fff4d6")
const INK := Color("#2d211c")
const COCOA := Color("#533528")
const WOOD := Color("#9f582d")
const HONEY := Color("#dc8e3d")
const GREEN := Color("#3f8f58")

const SPECIES_ORDER: Array[String] = [
	"cat",
	"alligator",
	"goat",
	"squirrel",
	"tiger",
]

const SPECIES_LABELS := {
	"cat": "Cats",
	"alligator": "Alligators",
	"goat": "Goats",
	"squirrel": "Squirrels",
	"tiger": "Tigers",
	"villager": "Villagers",
}

var _character_loader: CharacterLoader
var _selected_index: int = 0
var _groups: Dictionary = {}

var _panel: PanelContainer
var _header_title: Label
var _header_subtitle: Label
var _body: VBoxContainer
var _back_button: Button


func configure(
	character_loader: CharacterLoader,
	selected_index: int
) -> void:
	_character_loader = character_loader
	_selected_index = selected_index

	_build_groups()
	_build_shell()
	_show_species_screen()


func _build_groups() -> void:
	_groups.clear()

	if _character_loader == null:
		return

	for index: int in range(
		_character_loader.profiles.size()
	):
		var profile: CharacterProfile = _character_loader.get_profile(
			index
		)

		var species: String = str(
			profile.species
		).strip_edges().to_lower()

		if species.is_empty():
			species = "villager"

		if not _groups.has(
			species
		):
			_groups[
				species
			] = []

		_groups[
			species
		].append(
			index
		)


func _build_shell() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	backdrop.color = Color(
		0.055,
		0.040,
		0.030,
		0.92
	)
	add_child(
		backdrop
	)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	_panel.offset_left = 56.0
	_panel.offset_top = 40.0
	_panel.offset_right = -56.0
	_panel.offset_bottom = -40.0
	_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color("#fff5dc"),
			30,
			7,
			Color("#e6b66b")
		)
	)
	add_child(
		_panel
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		30
	)
	margin.add_theme_constant_override(
		"margin_right",
		30
	)
	margin.add_theme_constant_override(
		"margin_top",
		24
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		24
	)
	_panel.add_child(
		margin
	)

	var root_stack := VBoxContainer.new()
	root_stack.add_theme_constant_override(
		"separation",
		16
	)
	margin.add_child(
		root_stack
	)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(
		"separation",
		12
	)
	root_stack.add_child(
		header
	)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override(
		"separation",
		2
	)
	header.add_child(
		title_stack
	)

	var eyebrow := _label(
		"STUDY BUDDY",
		13,
		GREEN
	)
	title_stack.add_child(
		eyebrow
	)

	_header_title = _label(
		"Choose a character type",
		30,
		INK
	)
	title_stack.add_child(
		_header_title
	)

	_header_subtitle = _label(
		"Pick a species first, then choose the villager you want to use.",
		15,
		COCOA
	)
	title_stack.add_child(
		_header_subtitle
	)

	_back_button = _small_button(
		"← Types"
	)
	_back_button.visible = false
	_back_button.pressed.connect(
		_show_species_screen
	)
	header.add_child(
		_back_button
	)

	var close_button := _small_button(
		"Close"
	)
	close_button.pressed.connect(
		_close
	)
	header.add_child(
		close_button
	)

	var separator := HSeparator.new()
	separator.modulate = Color("#d8bd88")
	root_stack.add_child(
		separator
	)

	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_stack.add_child(
		_body
	)


func _show_species_screen() -> void:
	_clear_body()

	_back_button.visible = false
	_header_title.text = "Choose a character type"
	_header_subtitle.text = (
		"Pick a species first. Each card uses an actual character model from that group."
	)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(
		scroll
	)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(
		"h_separation",
		16
	)
	grid.add_theme_constant_override(
		"v_separation",
		16
	)
	scroll.add_child(
		grid
	)

	var ordered_species: Array[String] = []

	for species: String in SPECIES_ORDER:
		if _groups.has(
			species
		):
			ordered_species.append(
				species
			)

	for key_variant: Variant in _groups.keys():
		var species: String = str(
			key_variant
		)

		if not ordered_species.has(
			species
		):
			ordered_species.append(
				species
			)

	for species: String in ordered_species:
		var indices: Array = _groups[
			species
		]

		if indices.is_empty():
			continue

		var representative_index: int = int(
			indices[
				0
			]
		)

		var label_text: String = _species_label(
			species
		)

		var card := _make_character_card(
			representative_index,
			label_text,
			"%d variants" % indices.size(),
			false
		)

		card.pressed.connect(
			_show_variant_screen.bind(
				species
			)
		)

		grid.add_child(
			card
		)


func _show_variant_screen(
	species: String
) -> void:
	_clear_body()

	_back_button.visible = true

	var label_text: String = _species_label(
		species
	)

	_header_title.text = (
		"Choose your %s" % label_text.trim_suffix(
			"s"
		)
	)
	_header_subtitle.text = (
		"Choose one variant. You can change your study buddy again from the main menu."
	)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(
		scroll
	)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(
		"h_separation",
		14
	)
	grid.add_theme_constant_override(
		"v_separation",
		14
	)
	scroll.add_child(
		grid
	)

	var indices: Array = _groups.get(
		species,
		[]
	)

	for index_variant: Variant in indices:
		var index: int = int(
			index_variant
		)

		var profile: CharacterProfile = _character_loader.get_profile(
			index
		)

		var card := _make_character_card(
			index,
			profile.display_name,
			(
				"Selected"
					if index == _selected_index
					else label_text.trim_suffix(
						"s"
					)
			),
			index == _selected_index
		)

		card.pressed.connect(
			_choose_character.bind(
				index
			)
		)

		grid.add_child(
			card
		)


func _make_character_card(
	index: int,
	title_text: String,
	detail_text: String,
	selected: bool
) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(
		205,
		252
	)
	card.clip_contents = true
	card.text = ""
	card.focus_mode = Control.FOCUS_ALL

	card.add_theme_stylebox_override(
		"normal",
		_panel_style(
			(
				Color("#ffe0a0")
					if selected
					else Color("#f8e9c8")
			),
			22,
			(
				4
					if selected
					else 2
			),
			(
				HONEY
					if selected
					else Color("#e0c48f")
			)
		)
	)

	card.add_theme_stylebox_override(
		"hover",
		_panel_style(
			Color("#ffe6b1"),
			22,
			3,
			HONEY
		)
	)

	card.add_theme_stylebox_override(
		"pressed",
		_panel_style(
			Color("#f4cd82"),
			22,
			3,
			WOOD
		)
	)

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	stack.offset_left = 10.0
	stack.offset_top = 10.0
	stack.offset_right = -10.0
	stack.offset_bottom = -10.0
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override(
		"separation",
		7
	)
	card.add_child(
		stack
	)

	var preview := _make_preview(
		index
	)
	preview.custom_minimum_size = Vector2(
		180,
		148
	)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(
		preview
	)

	var title := _label(
		title_text,
		17,
		INK
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(
		title
	)

	var detail := _label(
		detail_text,
		12,
		COCOA
	)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.custom_minimum_size = Vector2(
		0,
		22
	)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(
		detail
	)

	return card


func _make_preview(
	index: int
) -> SubViewportContainer:
	var container := SubViewportContainer.new()

	var viewport := SubViewport.new()
	viewport.size = Vector2i(
		220,
		176
	)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.own_world_3d = true
	container.add_child(
		viewport
	)

	var world := Node3D.new()
	viewport.add_child(
		world
	)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(
		0.0,
		0.0,
		0.0,
		0.0
	)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#fff0d0")
	environment.ambient_light_energy = 1.15
	environment_node.environment = environment
	world.add_child(
		environment_node
	)

	var character: Node3D = _character_loader.create_character(
		world,
		index,
		Callable(
			self,
			"_create_preview_fallback"
		),
		false
	)

	if is_instance_valid(
		character
	):
		# Runtime characters face canonical -Z. The selector camera sits on +Z,
		# so rotate only the preview 180 degrees to show the character's face.
		character.rotation.y += PI
		character.scale *= 0.88

		_character_loader.play_animation(
			character,
			"Idle",
			0.0
		)

	var light := DirectionalLight3D.new()
	light.light_color = Color("#ffd79a")
	light.light_energy = 1.35
	light.rotation_degrees = Vector3(
		-38.0,
		-28.0,
		0.0
	)
	world.add_child(
		light
	)

	var fill := OmniLight3D.new()
	fill.position = Vector3(
		-2.2,
		2.8,
		3.4
	)
	fill.light_color = Color("#ffe8c3")
	fill.light_energy = 2.0
	fill.omni_range = 8.0
	world.add_child(
		fill
	)

	var camera := Camera3D.new()
	camera.position = Vector3(
		3.3,
		2.55,
		5.4
	)
	camera.fov = 28.0
	world.add_child(
		camera
	)
	camera.look_at_from_position(
		camera.position,
		Vector3(
			0.0,
			1.35,
			0.0
		)
	)
	camera.current = true

	return container


func _create_preview_fallback(
	parent: Node,
	_variant: int,
	_seated: bool
) -> Node3D:
	var root := Node3D.new()
	parent.add_child(
		root
	)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.3
	mesh_instance.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d7b27a")
	mesh_instance.material_override = material
	mesh_instance.position.y = 1.1
	root.add_child(
		mesh_instance
	)

	return root


func _choose_character(
	index: int
) -> void:
	_selected_index = index

	character_chosen.emit(
		index
	)


func _close() -> void:
	closed.emit()


func _clear_body() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(
			child
		)
		child.queue_free()


func _species_label(
	species: String
) -> String:
	return str(
		SPECIES_LABELS.get(
			species,
			species.capitalize() + "s"
		)
	)


func _label(
	text_value: String,
	size_value: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override(
		"font_size",
		size_value
	)
	label.add_theme_color_override(
		"font_color",
		color
	)
	return label


func _small_button(
	text_value: String
) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(
		92,
		44
	)
	button.add_theme_font_size_override(
		"font_size",
		14
	)
	button.add_theme_color_override(
		"font_color",
		INK
	)
	button.add_theme_color_override(
		"font_hover_color",
		INK
	)
	button.add_theme_stylebox_override(
		"normal",
		_panel_style(
			Color("#f4e3bf"),
			16,
			2,
			Color("#d8bd88")
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(
			Color("#ffd681"),
			16,
			3,
			HONEY
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_panel_style(
			Color("#e9ae4c"),
			16,
			3,
			WOOD
		)
	)
	return button


func _panel_style(
	color: Color,
	radius: int,
	border_width: int = 0,
	border_color: Color = Color.TRANSPARENT
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color

	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color

	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0

	style.shadow_color = Color(
		0.08,
		0.04,
		0.02,
		0.22
	)
	style.shadow_size = 6
	style.shadow_offset = Vector2(
		0.0,
		3.0
	)

	return style


func _unhandled_input(
	event: InputEvent
) -> void:
	if event.is_action_pressed(
		"menu"
	):
		get_viewport().set_input_as_handled()

		if _back_button.visible:
			_show_species_screen()
		else:
			_close()
