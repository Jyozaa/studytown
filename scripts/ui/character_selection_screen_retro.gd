extends Control

signal character_chosen(index: int)
signal closed

const RetroUI := preload(
	"res://scripts/ui/retro_ui.gd"
)

const RetroCharacterPreview := preload(
	"res://scripts/ui/retro_character_preview.gd"
)

const SPECIES_ORDER: Array[String] = [
	"cat",
	"alligator",
	"goat",
	"squirrel",
	"tiger",
]

const SPECIES_LABELS := {
	"cat": "CATS",
	"alligator": "ALLIGATORS",
	"goat": "GOATS",
	"squirrel": "SQUIRRELS",
	"tiger": "TIGERS",
	"villager": "VILLAGERS",
}

const ITEMS_PER_PAGE := 8

var _character_loader: CharacterLoader
var _selected_index := 0
var _selected_species := "cat"
var _page := 0
var _groups: Dictionary = {}

var _species_row: HBoxContainer
var _variant_grid: GridContainer
var _page_label: Label
var _selected_preview_holder: Control
var _selected_name: Label
var _selected_species_label: Label
var _selected_status: Label


func configure(
	character_loader: CharacterLoader,
	selected_index: int
) -> void:
	_character_loader = character_loader
	_selected_index = selected_index
	_build_groups()

	var selected_profile: CharacterProfile = _character_loader.get_profile(
		clampi(
			selected_index,
			0,
			maxi(
				_character_loader.profiles.size() - 1,
				0
			)
		)
	)

	_selected_species = (
		selected_profile.species
		if not selected_profile.species.is_empty()
		else "villager"
	)

	_build_screen()
	_refresh_species_row()
	_refresh_variants()
	_refresh_selected_preview(_selected_index)


func _build_groups() -> void:
	_groups.clear()

	for index: int in range(
		_character_loader.profiles.size()
	):
		var profile: CharacterProfile = _character_loader.get_profile(
			index
		)

		var species := str(
			profile.species
		).strip_edges().to_lower()

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

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = RetroUI.BLUE_LIGHT
	add_child(background)

	var top_bar := Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1280, 58)
	top_bar.add_theme_stylebox_override(
		"panel",
		RetroUI.panel_style(
			RetroUI.BLUE,
			RetroUI.NAVY,
			3
		)
	)
	add_child(top_bar)

	var title := RetroUI.label(
		"STUDY BUDDIES",
		24,
		RetroUI.WHITE,
		true
	)
	title.position = Vector2(20, 10)
	title.size = Vector2(420, 38)
	top_bar.add_child(title)

	var subtitle := RetroUI.label(
		"SELECT A SPECIES, THEN CHOOSE YOUR CHARACTER",
		12,
		Color("#d8e8ff"),
		false,
		true
	)
	subtitle.position = Vector2(460, 18)
	subtitle.size = Vector2(550, 28)
	top_bar.add_child(subtitle)

	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(1158, 10)
	close.size = Vector2(102, 38)
	RetroUI.apply_button(
		close,
		false,
		false,
		true,
		true
	)
	RetroUI.attach_hover_frame(close)
	close.pressed.connect(_close)
	top_bar.add_child(close)

	var species_window := RetroUI.create_window(
		self,
		Vector2(18, 76),
		Vector2(938, 160),
		"SPECIES"
	)

	_species_row = HBoxContainer.new()
	_species_row.position = Vector2(12, 48)
	_species_row.size = Vector2(914, 98)
	_species_row.add_theme_constant_override(
		"separation",
		10
	)
	species_window.add_child(_species_row)

	var villager_window := RetroUI.create_window(
		self,
		Vector2(18, 248),
		Vector2(938, 448),
		"VILLAGERS"
	)

	_variant_grid = GridContainer.new()
	_variant_grid.position = Vector2(12, 50)
	_variant_grid.size = Vector2(914, 336)
	_variant_grid.columns = 4
	_variant_grid.add_theme_constant_override(
		"h_separation",
		10
	)
	_variant_grid.add_theme_constant_override(
		"v_separation",
		10
	)
	villager_window.add_child(_variant_grid)

	var previous := Button.new()
	previous.text = "◀"
	previous.position = Vector2(302, 396)
	previous.size = Vector2(60, 38)
	RetroUI.apply_button(
		previous,
		false,
		false,
		false,
		true
	)
	RetroUI.attach_hover_frame(previous)
	previous.pressed.connect(_previous_page)
	villager_window.add_child(previous)

	_page_label = RetroUI.label(
		"1 / 1",
		13,
		RetroUI.INK,
		true
	)
	_page_label.position = Vector2(380, 402)
	_page_label.size = Vector2(130, 28)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	villager_window.add_child(_page_label)

	var next := Button.new()
	next.text = "▶"
	next.position = Vector2(528, 396)
	next.size = Vector2(60, 38)
	RetroUI.apply_button(
		next,
		false,
		false,
		false,
		true
	)
	RetroUI.attach_hover_frame(next)
	next.pressed.connect(_next_page)
	villager_window.add_child(next)

	var selected_window := RetroUI.create_window(
		self,
		Vector2(972, 76),
		Vector2(290, 620),
		"SELECTED"
	)

	var preview_panel := Panel.new()
	preview_panel.position = Vector2(14, 52)
	preview_panel.size = Vector2(262, 308)
	preview_panel.add_theme_stylebox_override(
		"panel",
		RetroUI.panel_style(
			Color("#7b87d4"),
			RetroUI.OUTLINE,
			3
		)
	)
	selected_window.add_child(preview_panel)

	_selected_preview_holder = Control.new()
	_selected_preview_holder.position = Vector2(8, 8)
	_selected_preview_holder.size = Vector2(246, 292)
	preview_panel.add_child(_selected_preview_holder)

	var info_header := Panel.new()
	info_header.position = Vector2(14, 374)
	info_header.size = Vector2(262, 34)
	info_header.add_theme_stylebox_override(
		"panel",
		RetroUI.header_style(
			RetroUI.BLUE
		)
	)
	selected_window.add_child(info_header)

	var info_title := RetroUI.label(
		"CHARACTER INFO",
		12,
		RetroUI.WHITE,
		true
	)
	info_title.position = Vector2(8, 5)
	info_title.size = Vector2(220, 24)
	info_header.add_child(info_title)

	_selected_name = RetroUI.label(
		"",
		20,
		RetroUI.INK,
		true
	)
	_selected_name.position = Vector2(24, 424)
	_selected_name.size = Vector2(240, 34)
	selected_window.add_child(_selected_name)

	_selected_species_label = RetroUI.label(
		"",
		13,
		RetroUI.MUTED
	)
	_selected_species_label.position = Vector2(24, 464)
	_selected_species_label.size = Vector2(240, 28)
	selected_window.add_child(_selected_species_label)

	_selected_status = RetroUI.label(
		"",
		12,
		RetroUI.BLUE,
		true
	)
	_selected_status.position = Vector2(24, 500)
	_selected_status.size = Vector2(240, 28)
	selected_window.add_child(_selected_status)

	var choose := Button.new()
	choose.text = "USE THIS BUDDY"
	choose.position = Vector2(24, 548)
	choose.size = Vector2(242, 46)
	RetroUI.apply_button(
		choose,
		false,
		true,
		false,
		false
	)
	RetroUI.attach_hover_frame(choose)
	choose.pressed.connect(
		func():
			character_chosen.emit(_selected_index)
	)
	selected_window.add_child(choose)


func _refresh_species_row() -> void:
	for child: Node in _species_row.get_children():
		child.queue_free()

	var ordered: Array[String] = []

	for species: String in SPECIES_ORDER:
		if _groups.has(species):
			ordered.append(species)

	for key_variant: Variant in _groups.keys():
		var species := str(key_variant)

		if not ordered.has(species):
			ordered.append(species)

	for species: String in ordered:
		var indices: Array = _groups.get(
			species,
			[]
		)

		if indices.is_empty():
			continue

		var representative := int(indices[0])

		var card := Button.new()
		card.text = ""
		card.custom_minimum_size = Vector2(170, 92)
		card.focus_mode = Control.FOCUS_ALL

		var selected := species == _selected_species

		card.add_theme_stylebox_override(
			"normal",
			RetroUI.panel_style(
				(
					Color("#6573c8")
					if selected
					else Color("#747fce")
				),
				(
					RetroUI.WHITE
					if selected
					else RetroUI.OUTLINE
				),
				3
			)
		)

		card.add_theme_stylebox_override(
			"hover",
			RetroUI.panel_style(
				Color("#818ddb"),
				RetroUI.WHITE,
				3
			)
		)

		var preview := RetroCharacterPreview.make_character_preview(
			_character_loader,
			representative,
			Vector2i(72, 68),
			true
		)
		preview.position = Vector2(6, 10)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(preview)

		var label := RetroUI.label(
			_species_label(species),
			10,
			RetroUI.WHITE,
			true
		)
		label.position = Vector2(80, 20)
		label.size = Vector2(84, 44)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)

		RetroUI.attach_hover_frame(
			card,
			selected
		)

		card.pressed.connect(
			_select_species.bind(species)
		)

		_species_row.add_child(card)


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

	for cursor: int in range(
		start,
		end
	):
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
	card.custom_minimum_size = Vector2(218, 158)
	card.focus_mode = Control.FOCUS_ALL

	var selected := index == _selected_index

	card.add_theme_stylebox_override(
		"normal",
		RetroUI.panel_style(
			(
				Color("#6876c9")
				if selected
				else Color("#d5d5d5")
			),
			(
				RetroUI.WHITE
				if selected
				else RetroUI.OUTLINE
			),
			3
		)
	)

	card.add_theme_stylebox_override(
		"hover",
		RetroUI.panel_style(
			Color("#7e8bd9"),
			RetroUI.WHITE,
			3
		)
	)

	var header := Panel.new()
	header.position = Vector2(4, 4)
	header.size = Vector2(210, 28)
	header.add_theme_stylebox_override(
		"panel",
		RetroUI.header_style(
			RetroUI.BLUE_CARD
		)
	)
	card.add_child(header)

	var title := RetroUI.label(
		profile.display_name,
		10,
		RetroUI.WHITE,
		true
	)
	title.position = Vector2(6, 4)
	title.size = Vector2(198, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)

	var preview := RetroCharacterPreview.make_character_preview(
		_character_loader,
		index,
		Vector2i(204, 116),
		false
	)
	preview.position = Vector2(7, 35)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(preview)

	RetroUI.attach_hover_frame(
		card,
		selected
	)

	card.pressed.connect(
		_preview_variant.bind(index)
	)

	return card


func _select_species(
	species: String
) -> void:
	_selected_species = species
	_page = 0

	_refresh_species_row()
	_refresh_variants()

	var indices: Array = _groups.get(
		species,
		[]
	)

	if not indices.is_empty():
		_preview_variant(
			int(indices[0])
		)


func _preview_variant(
	index: int
) -> void:
	_selected_index = index
	_refresh_variants()
	_refresh_selected_preview(index)


func _refresh_selected_preview(
	index: int
) -> void:
	for child: Node in _selected_preview_holder.get_children():
		child.queue_free()

	var preview := RetroCharacterPreview.make_character_preview(
		_character_loader,
		index,
		Vector2i(246, 292),
		false
	)

	preview.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_selected_preview_holder.add_child(preview)

	var profile: CharacterProfile = _character_loader.get_profile(
		index
	)

	_selected_name.text = profile.display_name
	_selected_species_label.text = (
		"Species: %s"
		% _species_label(profile.species).capitalize()
	)

	_selected_status.text = (
		"CURRENTLY SELECTED"
		if index == GameState.selected_character
		else "READY TO SELECT"
	)


func _previous_page() -> void:
	_page -= 1
	_refresh_variants()


func _next_page() -> void:
	_page += 1
	_refresh_variants()


func _species_label(
	species: String
) -> String:
	return str(
		SPECIES_LABELS.get(
			species,
			species.to_upper()
		)
	)


func _close() -> void:
	closed.emit()


func _unhandled_input(
	event: InputEvent
) -> void:
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()
