extends Control

signal character_chosen(index: int)
signal closed

const ScrapbookUI := preload(
	"res://scripts/ui/scrapbook_ui.gd"
)

const ITEMS_PER_PAGE := 6

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
var _selected_index := 0
var _selected_species := "cat"
var _page := 0
var _groups: Dictionary = {}

var _variant_grid: GridContainer
var _page_label: Label
var _large_preview_holder: Control
var _name_label: Label
var _species_label: Label
var _species_column: VBoxContainer


func configure(
	character_loader: CharacterLoader,
	selected_index: int
) -> void:
	_character_loader = character_loader
	_selected_index = selected_index
	_build_groups()

	var profile: CharacterProfile = _character_loader.get_profile(
		clampi(
			_selected_index,
			0,
			maxi(
				_character_loader.profiles.size() - 1,
				0
			)
		)
	)

	_selected_species = (
		profile.species
		if not profile.species.is_empty()
		else "villager"
	)

	_build_screen()
	_refresh_species_column()
	_refresh_variants()
	_refresh_large_preview(
		_selected_index
	)


func _build_groups() -> void:
	_groups.clear()

	for index: int in range(
		_character_loader.profiles.size()
	):
		var profile: CharacterProfile = _character_loader.get_profile(
			index
		)

		var species := profile.species.strip_edges().to_lower()

		if species.is_empty():
			species = "villager"

		if not _groups.has(species):
			_groups[species] = []

		_groups[species].append(index)


func _build_screen() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	shade.color = Color(
		0.05,
		0.035,
		0.025,
		0.68
	)
	add_child(shade)

	var board := Control.new()
	board.position = Vector2(48, 34)
	board.size = Vector2(1184, 652)
	add_child(board)

	ScrapbookUI.paper(
		board,
		"paper/paper_10.png",
		Vector2(0, 0),
		Vector2(1184, 652),
		-0.4
	)

	ScrapbookUI.sticker(
		board,
		"tape/tape_1.png",
		Vector2(446, -14),
		Vector2(160, 62),
		-2.0
	)

	var title := ScrapbookUI.label(
		"Choose a buddy!",
		33,
		ScrapbookUI.INK,
		true
	)
	title.position = Vector2(34, 28)
	title.size = Vector2(480, 52)
	board.add_child(title)

	var subtitle := ScrapbookUI.label(
		"Same species, different friends.",
		15,
		ScrapbookUI.INK_SOFT
	)
	subtitle.position = Vector2(38, 78)
	subtitle.size = Vector2(460, 36)
	board.add_child(subtitle)

	ScrapbookUI.sticker(
		board,
		"patch/patch_3.png",
		Vector2(852, 18),
		Vector2(198, 116),
		4.0
	)

	_species_column = VBoxContainer.new()
	_species_column.position = Vector2(26, 146)
	_species_column.size = Vector2(130, 370)
	_species_column.add_theme_constant_override(
		"separation",
		8
	)
	board.add_child(_species_column)

	_variant_grid = GridContainer.new()
	_variant_grid.position = Vector2(168, 142)
	_variant_grid.size = Vector2(520, 388)
	_variant_grid.columns = 3
	_variant_grid.add_theme_constant_override(
		"h_separation",
		10
	)
	_variant_grid.add_theme_constant_override(
		"v_separation",
		10
	)
	board.add_child(_variant_grid)

	var right_note := Control.new()
	right_note.position = Vector2(720, 132)
	right_note.size = Vector2(390, 420)
	board.add_child(right_note)

	ScrapbookUI.paper(
		right_note,
		"paper/paper_2.png",
		Vector2(0, 0),
		Vector2(390, 420),
		1.0
	)

	ScrapbookUI.sticker(
		right_note,
		"pin/pin_1.png",
		Vector2(168, -18),
		Vector2(44, 70),
		0.0
	)

	_large_preview_holder = Control.new()
	_large_preview_holder.position = Vector2(46, 44)
	_large_preview_holder.size = Vector2(300, 250)
	right_note.add_child(_large_preview_holder)

	_name_label = ScrapbookUI.label(
		"",
		24,
		ScrapbookUI.INK,
		true
	)
	_name_label.position = Vector2(46, 300)
	_name_label.size = Vector2(300, 40)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_note.add_child(_name_label)

	_species_label = ScrapbookUI.label(
		"",
		15,
		ScrapbookUI.INK_SOFT
	)
	_species_label.position = Vector2(46, 340)
	_species_label.size = Vector2(300, 30)
	_species_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_note.add_child(_species_label)

	var back := Button.new()
	back.text = "←  Back"
	back.position = Vector2(26, 580)
	back.size = Vector2(130, 44)
	ScrapbookUI.apply_text_button(back)
	back.pressed.connect(_close)
	board.add_child(back)

	var previous := Button.new()
	previous.text = "←"
	previous.position = Vector2(220, 560)
	previous.size = Vector2(56, 44)
	ScrapbookUI.apply_paper_button(previous)
	previous.pressed.connect(_previous_page)
	board.add_child(previous)

	_page_label = ScrapbookUI.label(
		"1 / 1",
		15,
		ScrapbookUI.INK
	)
	_page_label.position = Vector2(290, 567)
	_page_label.size = Vector2(140, 30)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(_page_label)

	var next := Button.new()
	next.text = "→"
	next.position = Vector2(444, 560)
	next.size = Vector2(56, 44)
	ScrapbookUI.apply_paper_button(next)
	next.pressed.connect(_next_page)
	board.add_child(next)


func _refresh_species_column() -> void:
	for child: Node in _species_column.get_children():
		child.queue_free()

	var ordered: Array[String] = []

	for species: String in SPECIES_ORDER:
		if _groups.has(species):
			ordered.append(species)

	for key: Variant in _groups.keys():
		var species := str(key)

		if not ordered.has(species):
			ordered.append(species)

	for species: String in ordered:
		var row := Button.new()
		row.text = _species_name(species)
		row.custom_minimum_size = Vector2(120, 54)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ScrapbookUI.apply_paper_button(
			row,
			species == _selected_species,
			false
		)
		row.pressed.connect(
			_select_species.bind(species)
		)
		_species_column.add_child(row)

		if species == _selected_species:
			var pin := ScrapbookUI.texture(
				"pin/pin_3.png",
				Vector2(94, -4),
				Vector2(28, 44),
				7.0,
				true
			)
			row.add_child(pin)


func _refresh_variants() -> void:
	for child: Node in _variant_grid.get_children():
		child.queue_free()

	var indices: Array = _groups.get(
		_selected_species,
		[]
	)

	var page_count := maxi(
		1,
		ceili(
			float(indices.size())
			/ float(ITEMS_PER_PAGE)
		)
	)

	_page = clampi(
		_page,
		0,
		page_count - 1
	)

	_page_label.text = "%d / %d" % [
		_page + 1,
		page_count,
	]

	var start := _page * ITEMS_PER_PAGE
	var end := mini(
		start + ITEMS_PER_PAGE,
		indices.size()
	)

	for cursor: int in range(start, end):
		var index := int(indices[cursor])
		_variant_grid.add_child(
			_make_variant_card(index)
		)


func _make_variant_card(
	index: int
) -> Button:
	var profile: CharacterProfile = _character_loader.get_profile(
		index
	)

	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(162, 184)
	card.flat = true
	card.focus_mode = Control.FOCUS_ALL

	var paper := ScrapbookUI.texture(
		"paper/paper_7.png",
		Vector2(0, 0),
		Vector2(162, 184),
		-1.0 + float(index % 3),
		true
	)
	card.add_child(paper)

	var preview := _make_character_preview(
		index,
		Vector2i(146, 126)
	)
	preview.position = Vector2(8, 8)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(preview)

	var name := ScrapbookUI.label(
		profile.display_name,
		13,
		ScrapbookUI.INK,
		true
	)
	name.position = Vector2(8, 140)
	name.size = Vector2(146, 28)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name)

	if index == _selected_index:
		var selected_mark := ScrapbookUI.texture(
			"pin/pin_3.png",
			Vector2(132, -8),
			Vector2(28, 44),
			5.0,
			true
		)
		card.add_child(selected_mark)

	card.pressed.connect(
		_choose_variant.bind(index)
	)
	return card


func _make_character_preview(
	index: int,
	size_value: Vector2i
) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(
		size_value.x,
		size_value.y
	)
	container.stretch = true

	var viewport := SubViewport.new()
	viewport.size = size_value
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.own_world_3d = true
	container.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	var character: Node3D = _character_loader.create_character(
		world,
		index,
		Callable(
			self,
			"_preview_fallback"
		),
		false
	)

	if is_instance_valid(character):
		character.rotation.y += PI
		character.scale *= 0.82
		_character_loader.play_animation(
			character,
			"Idle",
			0.0
		)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.TRANSPARENT
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#fff1ce")
	environment.ambient_light_energy = 1.2
	environment_node.environment = environment
	world.add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_color = Color("#ffd69b")
	light.light_energy = 1.35
	world.add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(3.0, 2.5, 5.0)
	camera.fov = 29
	world.add_child(camera)
	camera.look_at_from_position(
		camera.position,
		Vector3(0, 1.35, 0)
	)
	camera.current = true

	return container


func _refresh_large_preview(
	index: int
) -> void:
	for child: Node in _large_preview_holder.get_children():
		child.queue_free()

	var preview := _make_character_preview(
		index,
		Vector2i(300, 250)
	)
	preview.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_large_preview_holder.add_child(preview)

	var profile: CharacterProfile = _character_loader.get_profile(
		index
	)

	_name_label.text = profile.display_name
	_species_label.text = _species_name(
		profile.species
	).trim_suffix("s")


func _select_species(
	species: String
) -> void:
	_selected_species = species
	_page = 0
	_refresh_species_column()
	_refresh_variants()

	var indices: Array = _groups.get(
		species,
		[]
	)

	if not indices.is_empty():
		_refresh_large_preview(
			int(indices[0])
		)


func _choose_variant(
	index: int
) -> void:
	_selected_index = index
	_refresh_variants()
	_refresh_large_preview(index)
	character_chosen.emit(index)


func _previous_page() -> void:
	_page -= 1
	_refresh_variants()


func _next_page() -> void:
	_page += 1
	_refresh_variants()


func _species_name(
	species: String
) -> String:
	return str(
		SPECIES_LABELS.get(
			species,
			species.capitalize() + "s"
		)
	)


func _preview_fallback(
	parent: Node,
	_variant: int,
	_seated: bool
) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.62
	sphere.height = 1.24
	mesh_instance.mesh = sphere
	mesh_instance.position.y = 1.1

	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d9bb83")
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	return root


func _close() -> void:
	closed.emit()


func _unhandled_input(
	event: InputEvent
) -> void:
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()
