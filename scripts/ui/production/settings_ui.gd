class_name SettingsUI
extends Control
## Compact settings drawer: persisted via GameState.preferences.

var ui = null
var main = null


func setup(controller, owner_node: Node, parent: Control) -> void:
	ui = controller
	main = owner_node
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	var d := ProductionTheme.drawer(self, 1, 340.0)
	var y := 20.0
	ProductionTheme.label(d, "Settings", 23, ProductionTheme.INK).position = Vector2(20, y)
	y += 40.0
	_add_section(d, "Seats", y)
	y += 26.0
	y = _add_toggle_row(d, y, "Seat availability view", "seat_availability_view", true)
	y = _add_toggle_row(d, y, "Show nearby names", "show_names", true)
	y += 10.0
	_add_section(d, "Motion", y)
	y += 26.0
	y = _add_toggle_row(d, y, "Reduced motion", "reduced_motion", false)
	y += 10.0
	_add_section(d, "Audio", y)
	y += 26.0
	y = _add_toggle_row(d, y, "Mute all", "music_muted", false, _on_mute_all)
	var close := ProductionTheme.button(d, "Close")
	close.position = Vector2(20, 560.0 - 64.0)
	close.size = Vector2(300, 46)
	close.pressed.connect(func(): queue_free())


func _add_section(d: Control, text: String, y: float) -> void:
	var s := ProductionTheme.section(d, text)
	s.position = Vector2(20, y)
	s.size = Vector2(200, 20)


func _add_toggle_row(d: Control, y: float, text: String, key: String, default: bool, extra: Callable = Callable()) -> float:
	ProductionTheme.label(d, text, 16, ProductionTheme.INK).position = Vector2(20, y)
	var t := ProductionTheme.toggle(d, bool(GameState.preferences.get(key, default)))
	t.position = Vector2(340 - 20 - 58, y - 3)
	t.size = Vector2(58, 32)
	t.toggled.connect(func(on: bool):
		GameState.preferences[key] = on
		GameState.save()
		ProductionTheme.toast(get_parent(), "Settings saved.")
		if extra.is_valid():
			extra.call(on))
	return y + 42.0


func _on_mute_all(on: bool) -> void:
	if ui != null and ui.music_ui != null:
		var backend = ui.music_ui.backend
		if backend != null:
			backend.set("muted", on)
			if backend.has_method("_update_mix"):
				backend._update_mix()
