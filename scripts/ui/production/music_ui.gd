class_name MusicUI
extends Control
## Bottom-left music player: collapsed pill + expandable drawer.
## Uses the existing music backend (no fake playback states).

var ui = null
var main = null
var backend = null
var _expanded: Control = null


func setup(controller, owner_node: Node, parent: Control) -> void:
	ui = controller
	main = owner_node
	backend = main.dev_music if main.get("dev_music") != null else null
	if backend == null and main.get("application_flow") != null and main.application_flow.get("radio") != null:
		backend = main.application_flow.radio
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	if backend != null:
		backend.set("master", float(GameState.preferences.get("music_volume", 0.7)))
		backend.set("muted", bool(GameState.preferences.get("music_muted", false)))
		if backend.has_method("_update_mix"):
			backend._update_mix()
	refresh_collapsed()


func refresh_collapsed() -> void:
	pass  # collapsed pill lives in WorldHUD; this owns the expanded drawer.


func toggle_expanded() -> void:
	if _expanded != null and is_instance_valid(_expanded):
		_expanded.queue_free()
		_expanded = null
		return
	_expanded = ProductionTheme.drawer(self, -1, 330.0)
	var y := 20.0
	ProductionTheme.label(_expanded, "Music", 23, ProductionTheme.INK).position = Vector2(20, y)
	y += 36.0
	var track := "No track linked"
	if backend != null and backend.get("radio_player") != null and backend.radio_player.stream != null:
		track = str(backend.get("station"))
	ProductionTheme.label(_expanded, track, 19, ProductionTheme.INK).position = Vector2(20, y)
	y += 34.0
	var state := "Paused"
	if backend != null and bool(backend.get("playing")):
		state = "Now playing" if _stream_ok() else "Paused"
	ProductionTheme.label(_expanded, state, 13, ProductionTheme.INK_SOFT).position = Vector2(20, y)
	y += 30.0
	var row := HBoxContainer.new()
	row.position = Vector2(20, y)
	row.size = Vector2(290, 48)
	row.add_theme_constant_override("separation", 10)
	_expanded.add_child(row)
	var play := ProductionTheme.button(row, "Pause" if _is_playing() else "Play")
	play.custom_minimum_size = Vector2(90, 48)
	play.pressed.connect(func():
		if backend != null and backend.has_method("toggle_playback"):
			backend.toggle_playback()
		toggle_expanded()
		toggle_expanded())
	var mute := ProductionTheme.button(row, "Unmute" if _is_muted() else "Mute")
	mute.custom_minimum_size = Vector2(90, 48)
	mute.pressed.connect(func():
		if backend != null:
			backend.set("muted", not bool(backend.get("muted")))
			if backend.has_method("_update_mix"):
				backend._update_mix()
		_persist_music()
		toggle_expanded()
		toggle_expanded())
	y += 60.0
	ProductionTheme.label(_expanded, "Volume", 13, ProductionTheme.INK_SOFT).position = Vector2(20, y)
	y += 24.0
	var vol := ProductionTheme.slider(_expanded, 0.0, 1.0, 0.05, _volume())
	vol.position = Vector2(20, y)
	vol.size = Vector2(290, 26)
	vol.value_changed.connect(func(v: float):
		if backend != null:
			backend.set("master", v)
			if backend.has_method("_update_mix"):
				backend._update_mix()
		_persist_music())
	y += 40.0
	var sec := ProductionTheme.section(_expanded, "Stations")
	sec.position = Vector2(20, y)
	y += 24.0
	for station in ["Lo-fi", "Dark academia", "Café piano", "Quiet nature"]:
		var b := ProductionTheme.button(_expanded, station)
		b.position = Vector2(20, y)
		b.size = Vector2(290, 40)
		b.pressed.connect(_on_station.bind(station))
		y += 48.0


func _stream_ok() -> bool:
	return backend != null and backend.get("radio_player") != null and backend.radio_player.stream != null


func _is_playing() -> bool:
	return backend != null and bool(backend.get("playing"))


func _is_muted() -> bool:
	return backend != null and bool(backend.get("muted"))


func _volume() -> float:
	if backend != null:
		return float(backend.get("master"))
	return float(GameState.preferences.get("music_volume", 0.7))


func _persist_music() -> void:
	if backend != null:
		GameState.preferences["music_volume"] = float(backend.get("master"))
		GameState.preferences["music_muted"] = bool(backend.get("muted"))
		GameState.save()


func _on_station(station: String) -> void:
	if backend != null and backend.has_method("_select_station"):
		backend._select_station(station)
	GameState.preferences["vibe"] = station
	GameState.save()
	toggle_expanded()
	toggle_expanded()
