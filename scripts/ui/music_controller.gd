extends Node

# Local-only audio adapter. Supply licensed streams to these paths to enable
# playback; absent streams are explicitly labelled, never replaced by a URL.
const UI := preload("res://scripts/ui/dark_ui.gd")
const STATIONS := ["Lo-fi", "Dark academia", "Café piano", "Quiet nature"]
const SOUNDS := ["Rain", "Wind", "Fireplace", "Café chatter", "Keyboard"]
var station := "Lo-fi"
var playing := false
var master := 0.7
var muted := false
var radio_player: AudioStreamPlayer
var channels: Dictionary = {}
var volumes: Dictionary = {}


func _ready() -> void:
	station = str(GameState.preferences.get("vibe", "Lo-fi"))
	radio_player = AudioStreamPlayer.new()
	add_child(radio_player)
	for sound in SOUNDS:
		var player := AudioStreamPlayer.new()
		add_child(player)
		channels[sound] = player
		volumes[sound] = 0.0
		var path := "res://assets/audio/ambience/%s.ogg" % sound.to_snake_case()
		if ResourceLoader.exists(path):
			player.stream = load(path)
	_select_station(station)


func _select_station(value: String) -> void:
	station = value
	GameState.preferences.vibe = value
	GameState.save()
	radio_player.stop()
	var path := "res://assets/audio/radio/%s.ogg" % value.to_snake_case()
	radio_player.stream = load(path) if ResourceLoader.exists(path) else null
	if playing and radio_player.stream != null:
		radio_player.play()
	_update_mix()


func _update_mix() -> void:
	var effective := 0.0 if muted else master
	radio_player.volume_db = linear_to_db(maxf(0.0001, effective))
	for sound in SOUNDS:
		var player: AudioStreamPlayer = channels[sound]
		player.volume_db = linear_to_db(maxf(0.0001, float(volumes[sound]) * effective))
		if float(volumes[sound]) > 0 and player.stream != null and not player.playing:
			player.play()
		elif float(volumes[sound]) == 0:
			player.stop()


func toggle_playback() -> void:
	if radio_player.stream == null:
		return
	playing = not playing
	radio_player.stream_paused = not playing
	if playing and not radio_player.playing:
		radio_player.play()


func build(flow, root: Control) -> void:
	var card := UI.panel(root, Rect2(244, 131, 792, 458))
	UI.label(card, "Music & radio", Rect2(28, 20, 600, 40), 27)
	UI.button(card, "×", Rect2(718, 22, 45, 34), flow.close_overlay)
	UI.button(
		card,
		"RADIO",
		Rect2(28, 83, 154, 37),
		func():
			flow.radio_tab = "RADIO"
			flow.draw(),
		UI.BLUE.darkened(0.48) if flow.radio_tab == "RADIO" else UI.NESTED
	)
	UI.button(
		card,
		"SOUNDSCAPE",
		Rect2(196, 83, 177, 37),
		func():
			flow.radio_tab = "SOUNDSCAPE"
			flow.draw(),
		UI.BLUE.darkened(0.48) if flow.radio_tab == "SOUNDSCAPE" else UI.NESTED
	)
	UI.label(card, "♫", Rect2(39, 157, 251, 91), 66, UI.BLUE)
	UI.label(card, station, Rect2(39, 252, 251, 40), 23)
	UI.label(
		card,
		(
			"No local track linked"
			if radio_player.stream == null
			else ("Now playing" if playing else "Paused")
		),
		Rect2(39, 300, 251, 28),
		13,
		UI.MUTED
	)
	var play := UI.button(
		card,
		"Pause" if playing else "Play",
		Rect2(39, 355, 251, 43),
		func():
			toggle_playback()
			flow.draw(),
		UI.BLUE
	)
	play.disabled = radio_player.stream == null
	if flow.radio_tab == "RADIO":
		for i in STATIONS.size():
			var value: String = STATIONS[i]
			UI.button(
				card,
				("✓  " if station == value else "♫  ") + value,
				Rect2(339, 156 + i * 54, 425, 38),
				func():
					_select_station(value)
					flow.draw(),
				UI.BLUE.darkened(0.48) if station == value else UI.NESTED
			)
		UI.label(
			card,
			"Local audio only. No streams or paid services.",
			Rect2(339, 381, 425, 36),
			13,
			UI.MUTED
		)
	else:
		for i in SOUNDS.size():
			var sound: String = SOUNDS[i]
			var player: AudioStreamPlayer = channels[sound]
			UI.label(
				card,
				sound + (" · not linked" if player.stream == null else ""),
				Rect2(339, 141 + i * 43, 425, 25),
				13,
				UI.MUTED
			)
			UI.slider(
				card,
				Rect2(341, 168 + i * 43, 419, 12),
				0,
				1,
				0.01,
				volumes[sound],
				func(value):
					volumes[sound] = value
					_update_mix()
			)
		UI.button(
			card,
			"Reset",
			Rect2(643, 382, 121, 33),
			func():
				for sound in SOUNDS:
					volumes[sound] = 0.0
				_update_mix()
				flow.draw()
		)
	UI.slider(
		card,
		Rect2(39, 421, 547, 14),
		0,
		1,
		0.01,
		master,
		func(value):
			master = value
			_update_mix()
	)
	UI.button(
		card,
		"Unmute" if muted else "Mute",
		Rect2(621, 416, 143, 28),
		func():
			muted = not muted
			_update_mix()
			flow.draw()
	)
