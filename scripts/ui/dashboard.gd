extends RefCounted

const UI := preload("res://scripts/ui/dark_ui.gd")
const RoomPreview := preload("res://scripts/ui/room_preview.gd")
const CharacterPreview := preload("res://scripts/ui/retro_character_preview.gd")


static func build(flow, root: Control) -> void:
	UI.panel(root, Rect2(0, 0, 1280, 720), UI.BG, 0)
	var sidebar := UI.panel(root, Rect2(0, 0, 218, 720), UI.PANEL, 0)
	var buddy := CharacterPreview.make_character_preview(
		flow.main.character_loader,
		GameState.selected_character,
		Vector2i(48, 48),
		true,
		flow.main._create_fallback_character
	)
	buddy.position = Vector2(16, 21)
	buddy.size = Vector2(48, 48)
	sidebar.add_child(buddy)
	UI.label(sidebar, "StudyTown", Rect2(71, 24, 136, 42), 22)
	UI.label(sidebar, "YOUR QUIET CORNER", Rect2(27, 72, 180, 25), 11, UI.MUTED)
	var names := ["Home", "Friends", "Servers", "Stats", "Profile", "Store", "Settings"]
	var symbols := ["⌂", "♧", "▦", "▤", "○", "◇", "⚙"]
	for i in names.size():
		var destination: String = names[i]
		UI.button(
			sidebar,
			"%s   %s" % [symbols[i], destination],
			Rect2(18, 128 + i * 57, 182, 42),
			func():
				flow.dashboard_tab = destination
				flow.draw(),
			UI.BLUE.darkened(0.62) if flow.dashboard_tab == destination else UI.PANEL
		)
	UI.label(sidebar, "JOINED SERVER", Rect2(27, 577, 170, 25), 11, UI.MUTED)
	UI.button(
		sidebar,
		"◈  StudyTown",
		Rect2(18, 613, 182, 46),
		func():
			flow.dashboard_tab = "Servers"
			flow.draw()
	)
	UI.label(sidebar, "●  Local account", Rect2(27, 678, 170, 22), 12, UI.GREEN)
	UI.label(
		root,
		(
			"Welcome to StudyTown"
			if GameState.profile.name == "You"
			else "Good to see you, %s" % GameState.profile.name
		),
		Rect2(250, 22, 720, 40),
		28
	)
	UI.label(root, "Make a little room for what matters.", Rect2(252, 66, 620, 24), 15, UI.MUTED)
	UI.button(
		root,
		"◈ %d points" % GameState.focus_coins,
		Rect2(1060, 31, 184, 42),
		func():
			flow.dashboard_tab = "Stats"
			flow.draw()
	)
	if flow.dashboard_tab != "Home":
		_destination(flow, root)
		return
	var stats := UI.panel(root, Rect2(250, 111, 994, 80), UI.PANEL, 18)
	var values := ["5,694", "1,177", "20,670"]
	var labels := ["Focusing now", "Rooms", "Public servers"]
	for i in 3:
		UI.label(stats, values[i], Rect2(26 + i * 330, 9, 285, 35), 28)
		UI.label(stats, labels[i], Rect2(26 + i * 330, 45, 285, 23), 13, UI.MUTED)
	var feature := UI.panel(root, Rect2(250, 210, 994, 221))
	var preview := RoomPreview.make_preview("library", Vector2i(635, 221))
	preview.position = Vector2(359, 0)
	preview.size = Vector2(635, 221)
	feature.add_child(preview)
	UI.label(feature, "A SPACE TO SETTLE IN", Rect2(24, 20, 330, 25), 11, UI.GREEN)
	UI.label(feature, "Grand Library", Rect2(24, 57, 330, 44), 30)
	UI.label(feature, "395 rooms  ·  1,701 studying", Rect2(24, 109, 330, 24), 14, UI.MUTED)
	UI.button(
		feature, "Find your seat  →", Rect2(24, 156, 299, 43), flow.join_room.bind(0), UI.BLUE
	)
	UI.label(root, "Official StudyTown Server", Rect2(252, 445, 470, 30), 21)
	UI.label(root, "● 1,177 rooms live", Rect2(1006, 449, 238, 25), 13, UI.GREEN)
	UI.label(root, "Quickly join a room and start focusing", Rect2(252, 477, 700, 25), 14, UI.MUTED)
	var room_names := ["Grand Library", "Garden Commons", "Scenic Train"]
	var counts := [
		"395 rooms  ·  1,701 studying", "258 rooms  ·  1,006 studying", "13 rooms  ·  47 studying"
	]
	for i in 3:
		var card := UI.panel(root, Rect2(250 + i * 338, 518, 318, 169), UI.PANEL, 18)
		var thumb := RoomPreview.make_preview(["library", "garden", "train"][i], Vector2i(92, 72))
		thumb.position = Vector2(15, 14)
		thumb.size = Vector2(92, 72)
		card.add_child(thumb)
		UI.label(card, room_names[i], Rect2(120, 15, 188, 30), 19)
		UI.label(card, counts[i], Rect2(120, 49, 188, 41), 12, UI.MUTED).autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		UI.button(card, "Join room  →", Rect2(15, 107, 288, 43), flow.join_room.bind(i), UI.BLUE)
	UI.label(
		root,
		"Local demo • discovery counts are illustrative",
		Rect2(254, 693, 700, 20),
		11,
		UI.MUTED
	)


static func _destination(flow, root: Control) -> void:
	var card := UI.panel(root, Rect2(250, 116, 994, 570))
	var tab: String = flow.dashboard_tab
	UI.label(card, tab, Rect2(30, 25, 800, 45), 32)
	match tab:
		"Friends":
			UI.label(card, "Quiet company makes a difference.", Rect2(30, 94, 850, 40), 22)
			UI.label(
				card,
				"Friends are a local preview. Online invitations aren't connected yet.",
				Rect2(30, 147, 890, 50),
				17,
				UI.MUTED
			)
			for i in 3:
				UI.button(
					card,
					["Jamie  ·  Reading", "Pip  ·  Studying", "Mina  ·  Taking a break"][i],
					Rect2(30, 231 + i * 73, 620, 50),
					func():
						flow.toast(
							"This is a preview friend. Join a room to meet the local study buddies."
						)
				)
		"Servers":
			UI.label(card, "Official StudyTown Server", Rect2(30, 105, 900, 44), 27)
			UI.label(
				card,
				"Local rooms, familiar faces. No invite needed.",
				Rect2(30, 161, 900, 40),
				18,
				UI.MUTED
			)
			for i in GameState.ROOMS.size():
				UI.button(
					card,
					"Join  ·  " + GameState.ROOMS[i],
					Rect2(30, 229 + i * 68, 650, 46),
					flow.join_room.bind(i),
					UI.BLUE.darkened(0.35)
				)
		"Stats":
			UI.label(
				card,
				(
					"%d minutes       %d sessions       %d points"
					% [
						GameState.total_focus_minutes,
						GameState.completed_sessions,
						GameState.focus_coins
					]
				),
				Rect2(30, 98, 925, 50),
				28,
				UI.GREEN
			)
			UI.label(card, "RECENT FOCUS", Rect2(30, 171, 500, 25), 12, UI.MUTED)
			if GameState.recent_sessions.is_empty():
				UI.label(
					card, "Your first small win starts with a seat.", Rect2(30, 218, 900, 50), 22
				)
			for i in mini(6, GameState.recent_sessions.size()):
				var session: Dictionary = GameState.recent_sessions[i]
				UI.label(
					card,
					"%s  ·  %dm  ·  %s" % [session.task, session.minutes, session.room],
					Rect2(30, 219 + i * 48, 920, 42),
					17
				)
		"Profile":
			var preview := CharacterPreview.make_character_preview(
				flow.main.character_loader,
				GameState.selected_character,
				Vector2i(320, 350),
				false,
				flow.main._create_fallback_character
			)
			preview.position = Vector2(595, 100)
			preview.size = Vector2(320, 350)
			card.add_child(preview)
			UI.label(card, "DISPLAY NAME", Rect2(30, 102, 440, 25), 12, UI.MUTED)
			var name_input := UI.input(
				card, str(GameState.profile.name), "Your name", Rect2(30, 137, 495, 48)
			)
			UI.label(card, "SUBJECT", Rect2(30, 211, 440, 25), 12, UI.MUTED)
			var subject := UI.input(
				card,
				str(GameState.profile.subject),
				"What you're learning",
				Rect2(30, 247, 495, 48)
			)
			UI.button(
				card,
				"Save profile",
				Rect2(30, 333, 495, 48),
				func():
					GameState.profile.name = (
						name_input.text.strip_edges().left(24)
						if not name_input.text.strip_edges().is_empty()
						else "You"
					)
					GameState.profile.subject = subject.text.left(60)
					GameState.save()
					flow.draw(),
				UI.BLUE
			)
			UI.button(
				card,
				"Change study buddy",
				Rect2(30, 411, 495, 48),
				func():
					flow.editing_buddy = true
					flow.onboarding_step = 2
					flow.navigate(flow.State.ONBOARDING)
			)
		"Store":
			UI.label(card, "A little collection of your own", Rect2(30, 108, 900, 45), 28)
			(
				UI
				. label(
					card,
					"Your animal companions are already available.\nNo purchases, subscriptions or premium gates.",
					Rect2(30, 170, 900, 85),
					20,
					UI.MUTED
				)
			)
			UI.button(
				card,
				"Meet your study buddies",
				Rect2(30, 300, 520, 50),
				func():
					flow.editing_buddy = true
					flow.onboarding_step = 2
					flow.navigate(flow.State.ONBOARDING),
				UI.BLUE
			)
		"Settings":
			UI.button(
				card,
				"Music & soundscape",
				Rect2(30, 110, 580, 50),
				flow.open_overlay.bind(flow.State.MUSIC_RADIO)
			)
			UI.button(
				card,
				"Reminders: " + ("on" if GameState.preferences.notifications else "off"),
				Rect2(30, 188, 580, 50),
				func():
					GameState.preferences.notifications = not GameState.preferences.notifications
					GameState.save()
					flow.draw()
			)
			UI.label(
				card,
				"Preferences and progress are saved locally on this device.",
				Rect2(30, 282, 920, 40),
				17,
				UI.MUTED
			)
			UI.button(
				card,
				"Replay onboarding (keep progress)",
				Rect2(30, 362, 580, 50),
				func():
					GameState.reset_onboarding()
					flow.onboarding_step = 0
					flow.home()
			)
			UI.label(
				card,
				"Developer: F5 in a room sets up a ten-second test session.",
				Rect2(30, 457, 920, 35),
				14,
				UI.MUTED
			)
