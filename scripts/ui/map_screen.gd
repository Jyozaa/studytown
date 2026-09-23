extends RefCounted
## StudyTown Map — stylized world panel over the live game.
## Data-driven from destination_registry. Dark tactile language.

const T := preload("res://scripts/ui/study_theme.gd")
const Registry := preload("res://scripts/ui/destination_registry.gd")


static func current_id(flow) -> String:
	if flow.main.screen == flow.main.Screen.ROOM:
		var entry: Dictionary = Registry.for_room_index(GameState.selected_room)
		if not entry.is_empty():
			return str(entry.id)
	return ""


static func build(flow, root: Control) -> void:
	var dim := ColorRect.new()
	dim.color = T.SCRIM
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	T.label(root, "StudyTown Map", Rect2(0, 30, 1280, 40), 28, T.TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	T.label(root, "Choose somewhere to settle in.", Rect2(0, 70, 1280, 24), 14, T.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var panel := T.panel(root, Rect2(100, 112, 1080, 486), T.PANEL, T.R_MODAL)
	_world_panel(panel, Rect2(24, 24, 660, 438))
	var here: String = current_id(flow)
	var cards := Registry.all()
	var y := 24.0
	for entry in cards:
		_card(flow, panel, entry, Rect2(708, y, 348, 138), str(entry.id) == here)
		y += 150.0
	if not bool(flow.map_via_exit):
		T.button(root, "‹ Back", Rect2(100, 612, 130, 46), flow.close_map)


static func _world_panel(parent: Control, rect: Rect2) -> void:
	# Stylized StudyTown isle, drawn with primitives (see MISSING_UI_ASSETS
	# for the optional illustrated replacement, MAP_ISLE).
	var canvas := MapCanvas.new()
	canvas.position = rect.position
	canvas.size = rect.size
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(canvas)


class MapCanvas extends Control:
	func _draw() -> void:
		var sea := Color("#1A2E3D")
		draw_rect(Rect2(Vector2.ZERO, size), sea, true)
		var sand := Color("#4A4234")
		var grass := Color("#33462F")
		var grass_hi := Color("#3A4F36")
		_draw_blob(Vector2(200, 270), 120.0, sand)
		_draw_blob(Vector2(200, 262), 106.0, grass)
		_draw_blob(Vector2(430, 210), 150.0, sand)
		_draw_blob(Vector2(430, 202), 134.0, grass)
		_draw_blob(Vector2(430, 196), 96.0, grass_hi)
		draw_line(Vector2(120, 262), Vector2(520, 230), sand.darkened(0.1), 22.0)
		var spots := [Vector2(200, 262), Vector2(430, 202), Vector2(552, 300)]
		var cols := [Color("#E8A33D"), Color("#E8A33D"), Color("#4F8DF7")]
		var names := ["Library", "Café", "Train"]
		for i in spots.size():
			draw_circle(spots[i], 15.0, Color("#101114"))
			draw_circle(spots[i], 11.0, cols[i])
			draw_arc(spots[i], 20.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 2.0)
			var font := ThemeDB.fallback_font
			draw_string(font, spots[i] + Vector2(-30, 40), names[i], HORIZONTAL_ALIGNMENT_CENTER, 60, 15, Color("#F2EFE6"))
		# Decorative cloud blob (kept clear of markers/labels).
		for c in [Vector2(150, 356), Vector2(185, 346), Vector2(220, 358), Vector2(185, 368)]:
			draw_circle(c, 26.0, Color(0.95, 0.93, 0.86, 0.9))

	func _draw_blob(center: Vector2, radius: float, color: Color) -> void:
		draw_circle(center, radius, color)
		draw_circle(center + Vector2(radius * 0.55, -radius * 0.2), radius * 0.55, color)
		draw_circle(center + Vector2(-radius * 0.5, radius * 0.25), radius * 0.6, color)


static func _card(flow, parent: Control, entry: Dictionary, rect: Rect2, is_here: bool) -> void:
	var card := T.panel(parent, rect, T.PANEL_2, T.R_CARD)
	var accent: Color = entry.get("accent", T.ACCENT)
	var bar := ColorRect.new()
	bar.color = accent
	bar.position = Vector2(0, 0)
	bar.size = Vector2(6, rect.size.y)
	card.add_child(bar)
	T.label(card, str(entry.display_name), Rect2(20, 12, rect.size.x - 40, 30), 18, T.TEXT)
	T.wrap(card, str(entry.description), Rect2(20, 44, rect.size.x - 40, 44), 12, T.MUTED)
	T.label(card, "● " + str(entry.population), Rect2(20, 92, 180, 22), 12, T.MUTED)
	if is_here:
		T.chip(card, "HERE", Rect2(rect.size.x - 96, 12, 76, 30), true, T.GREEN)
		T.button(card, "Return", Rect2(20, 96, rect.size.x - 40, 40), func(): flow.map_travel(str(entry.id)))
	else:
		T.primary_button(card, "Travel  →", Rect2(20, 96, rect.size.x - 40, 40), func(): flow.map_travel(str(entry.id)))
