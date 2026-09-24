class_name WorldHUD
extends Control
## Sparse world-first HUD: room chip, action cluster, music pill, seat
## prompt, hover/nearby nameplates, occupant click picking. Ticks cheaply.

var ui = null
var main = null
var prompt_box: Control
var prompt_text: Label
var room_label: Label
var coins_label: Label
var occupants: Array = []
var _hovered: Dictionary = {}
var _motion_cd := 0.0
var _nameplates: Dictionary = {}  # instance_id -> Label3D


func setup(controller, owner_node: Node, parent: Control) -> void:
	ui = controller
	main = owner_node
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	# Top-left room chip.
	var chip := Panel.new()
	chip.add_theme_stylebox_override("panel", ProductionTheme.panel_style(Color(0.13, 0.10, 0.07, 0.72), 18))
	chip.position = Vector2(14, 12)
	chip.size = Vector2(210, 56)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	room_label = Label.new()
	room_label.add_theme_font_size_override("font_size", 17)
	room_label.add_theme_color_override("font_color", Color("#F9F1DC"))
	room_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(room_label)
	# Top-right cluster.
	var cluster := Panel.new()
	cluster.add_theme_stylebox_override("panel", ProductionTheme.panel_style(Color(0.13, 0.10, 0.07, 0.72), 18))
	var vp := ProductionTheme.vp_size(self)
	cluster.position = Vector2(vp.x - 14 - 5 * 52, 12)
	cluster.size = Vector2(5 * 52, 56)
	add_child(cluster)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 15)
	coins_label.add_theme_color_override("font_color", Color("#D9A441"))
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.add_child(coins_label)
	_add_cluster_button(cluster, 1, "M", "Map (M)", func(): ui.open_map())
	_add_cluster_button(cluster, 2, "P", "People", func(): ui.toggle_people())
	_add_cluster_button(cluster, 3, "C", "Chat", func(): ui.toggle_chat())
	_add_cluster_button(cluster, 4, "S", "Settings", func(): ui.toggle_settings())
	# Bottom-left music pill (collapsed).
	var music := ProductionTheme.button(self, "♫", ProductionTheme.PAPER_HI, ProductionTheme.INK)
	music.position = Vector2(14, vp.y - 64)
	music.size = Vector2(52, 52)
	music.tooltip_text = "Music"
	music.pressed.connect(func(): ui.music_ui.toggle_expanded())
	# Seat prompt bottom-center.
	prompt_box = Panel.new()
	prompt_box.add_theme_stylebox_override("panel", ProductionTheme.panel_style(Color(0.13, 0.10, 0.07, 0.85), 14))
	prompt_box.position = Vector2(vp.x * 0.5 - 110, vp.y - 70)
	prompt_box.size = Vector2(220, 52)
	prompt_box.visible = false
	add_child(prompt_box)
	var key := ProductionTheme.keycap(prompt_box, "E")
	key.position = Vector2(12, 8)
	key.size = Vector2(36, 36)
	prompt_text = Label.new()
	prompt_text.text = "Sit"
	prompt_text.add_theme_font_size_override("font_size", 16)
	prompt_text.add_theme_color_override("font_color", Color("#F9F1DC"))
	prompt_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_text.position = Vector2(56, 8)
	prompt_text.size = Vector2(150, 36)
	prompt_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.add_child(prompt_text)
	refresh_static()


func _add_cluster_button(cluster: Control, slot: int, text: String, tip: String, action: Callable) -> void:
	var b := ProductionTheme.button(cluster, text, Color(0, 0, 0, 0), Color("#F9F1DC"))
	b.position = Vector2(slot * 52 + 4, 5)
	b.size = Vector2(44, 46)
	b.tooltip_text = tip
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", ProductionTheme.button_style(Color(1, 1, 1, 0.14), Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("pressed", ProductionTheme.button_style(Color(1, 1, 1, 0.22), Color(0, 0, 0, 0)))
	b.pressed.connect(action)


func refresh_static() -> void:
	room_label.text = str(main.current_room_name)
	coins_label.text = "  ◈ %d" % int(GameState.focus_coins)


func tick() -> void:
	coins_label.text = "  ◈ %d" % int(GameState.focus_coins)
	# Seat prompt: nearest valid available seat, player standing, no session.
	var show := false
	if main.screen == main.Screen.ROOM and not main.gameplay.seated() and not FocusManager.active:
		var idx: int = main.nearest_spot
		if idx >= 0 and idx < main.study_spots.size():
			var spot = main.study_spots[idx]
			if is_instance_valid(spot) and spot.is_available():
				show = true
	prompt_box.visible = show
	_motion_cd -= get_process_delta_time()
	_update_nameplates()


func _occupant_list() -> Array:
	var out: Array = [{"node": main.player, "you": true}]
	for npc in main.npcs:
		if is_instance_valid(npc):
			out.append({"node": npc, "you": false})
	return out


func _update_nameplates() -> void:
	var show_nearby: bool = bool(GameState.preferences.get("show_names", true))
	var seen := {}
	for entry in _occupant_list():
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		var id := node.get_instance_id()
		seen[id] = true
		var want := show_nearby and node.global_position.distance_to(main.player.global_position) < 6.0
		if _hovered.get("id", -1) == id:
			want = true
		if entry.get("you", false):
			want = show_nearby
		if want and not _nameplates.has(id):
			var tag := Label3D.new()
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.font_size = 40
			tag.outline_size = 8
			tag.outline_modulate = Color(0, 0, 0, 0.7)
			tag.modulate = Color("#F9F1DC")
			tag.position = Vector3(0, 2.1, 0)
			node.add_child(tag)
			_nameplates[id] = tag
		if _nameplates.has(id):
			var tag2: Label3D = _nameplates[id]
			if not is_instance_valid(tag2):
				_nameplates.erase(id)
				continue
			tag2.visible = want
			if want:
				tag2.text = _occupant_name(entry)


func _occupant_name(entry: Dictionary) -> String:
	if bool(entry.get("you", false)):
		return str(GameState.profile.get("name", "You"))
	var npc = entry["node"]
	var label := str(npc.get("editor_display_name"))
	return label if label != "" else "Buddy"


func pick_occupant(screen_pos: Vector2) -> Dictionary:
	# Nearest occupant within 44 px of the click (camera projection).
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var best: Dictionary = {}
	var best_d := 44.0
	for entry in _occupant_list():
		var node: Node3D = entry["node"]
		if not is_instance_valid(node) or cam.is_position_behind(node.global_position + Vector3.UP):
			continue
		var p: Vector2 = cam.unproject_position(node.global_position + Vector3.UP * 1.2)
		var d: float = p.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = entry
	return best


func set_hover(entry: Dictionary) -> void:
	_hovered = entry
