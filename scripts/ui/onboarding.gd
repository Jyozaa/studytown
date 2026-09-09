extends RefCounted

const UI := preload("res://scripts/ui/dark_ui.gd")
const Preview := preload("res://scripts/ui/retro_character_preview.gd")
const TITLES := [
	"Create your profile",
	"What brings you here?",
	"Meet your study buddy",
	"What are you focusing on?",
	"A gentle reminder",
	"Make yourself at home",
	"Pick a username",
	"Find your study vibe",
	"How did you hear about us?",
	"What are you learning?",
	"When will you focus?",
	"You're in good company"
]
const DESCRIPTIONS := [
	"A little about you, before we settle in.",
	"Small steps feel better together.",
	"Choose an animal. Your buddy goes everywhere with you.",
	"Give your next quiet hour a little direction.",
	"Choose whether you'd like study reminders.",
	"Your progress stays on this device.",
	"A name for your little corner of StudyTown.",
	"A soundtrack for getting into the zone.",
	"One last bit before your first session.",
	"Make this space feel like yours.",
	"There is no perfect time. Just a little time.",
	"Your space is ready. Let's make a little progress."
]


static func build(flow, root: Control) -> void:
	UI.panel(root, Rect2(0, 0, 1280, 720), UI.BG, 0)
	UI.label(root, "◈  StudyTown", Rect2(38, 25, 240, 40), 24)
	UI.label(root, "A little focus. A little company.", Rect2(40, 652, 420, 30), 15, UI.MUTED)
	var step: int = flow.onboarding_step
	var card := UI.panel(root, Rect2(360, 100, 560, 520))
	UI.label(card, "%02d / 12" % (step + 1), Rect2(32, 22, 150, 24), 13, UI.MUTED)
	UI.label(card, TITLES[step], Rect2(32, 60, 496, 45), 28)
	UI.label(card, DESCRIPTIONS[step], Rect2(32, 107, 496, 42), 14, UI.MUTED).autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	var next := UI.button(
		card,
		(
			"Save buddy"
			if flow.editing_buddy
			else ("Enter StudyTown" if step == 11 else "Continue  →")
		),
		Rect2(32, 438, 496, 48),
		func():
			if flow.editing_buddy:
				flow.editing_buddy = false
				GameState.save()
				flow.home()
			elif step == 11:
				GameState.onboarding_complete = true
				GameState.save()
				flow.home()
			else:
				flow.onboarding_step += 1
				GameState.save()
				flow.draw(),
		UI.BLUE
	)
	if step > 0 and not flow.editing_buddy:
		UI.button(
			card,
			"‹",
			Rect2(470, 18, 56, 34),
			func():
				flow.onboarding_step -= 1
				flow.draw()
		)
	match step:
		0:
			UI.label(card, "DISPLAY NAME", Rect2(32, 166, 250, 24), 12, UI.MUTED)
			var name_input := UI.input(
				card, str(GameState.profile.name), "Your name", Rect2(32, 196, 496, 48)
			)
			name_input.max_length = 24
			name_input.text_changed.connect(
				func(value):
					GameState.profile.name = value.strip_edges()
					next.disabled = value.strip_edges().is_empty()
			)
			UI.label(card, "COUNTRY / REGION (OPTIONAL)", Rect2(32, 267, 450, 24), 12, UI.MUTED)
			var country := UI.input(
				card, str(GameState.profile.country), "e.g. GB", Rect2(32, 297, 496, 48)
			)
			country.max_length = 2
			country.text_changed.connect(func(value): GameState.profile.country = value.to_upper())
		1:
			_choices(
				flow,
				card,
				[
					"Build a routine",
					"Find quiet company",
					"Feel less distracted",
					"Make time for myself"
				],
				"reason"
			)
		2:
			var count: int = maxi(1, flow.main.character_loader.profiles.size())
			GameState.selected_character = clampi(GameState.selected_character, 0, count - 1)
			var species := ["cat", "alligator", "goat", "squirrel", "tiger"]
			var species_names := ["Cats", "Gators", "Goats", "Squirrels", "Tigers"]
			for i in species.size():
				var kind: String = species[i]
				UI.button(
					card,
					species_names[i],
					Rect2(32 + i * 101, 154, 92, 31),
					func():
						for index in count:
							if flow.main.character_loader.get_profile(index).species == kind:
								GameState.selected_character = index
								flow.draw()
								break
				)
			var preview := Preview.make_character_preview(
				flow.main.character_loader,
				GameState.selected_character,
				Vector2i(240, 198),
				false,
				flow.main._create_fallback_character
			)
			preview.position = Vector2(160, 193)
			preview.size = Vector2(240, 198)
			card.add_child(preview)
			UI.button(
				card,
				"‹",
				Rect2(35, 244, 60, 48),
				func():
					GameState.selected_character = posmod(GameState.selected_character - 1, count)
					flow.draw()
			)
			UI.button(
				card,
				"›",
				Rect2(465, 244, 60, 48),
				func():
					GameState.selected_character = (GameState.selected_character + 1) % count
					flow.draw()
			)
			UI.label(card, flow.main.character_loader.get_profile(GameState.selected_character).display_name, Rect2(145, 399, 300, 25), 15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		3:
			_choices(
				flow,
				card,
				["Studying for class", "Reading more", "Deep work", "A creative project"],
				"intention"
			)
		4:
			UI.label(card, "Reminders are a local preference.\nNo browser or system permission is requested.", Rect2(32, 170, 496, 90), 18).autowrap_mode = (
				TextServer.AUTOWRAP_WORD_SMART
			)
			UI.button(
				card,
				"Reminders on" if GameState.preferences.notifications else "Reminders off",
				Rect2(32, 285, 496, 48),
				func():
					GameState.preferences.notifications = not GameState.preferences.notifications
					flow.draw()
			)
		5:
			UI.panel(card, Rect2(32, 176, 496, 185), UI.NESTED, 18)
			UI.label(card, "Your own local account", Rect2(56, 197, 450, 42), 23)
			(
				UI
				. label(
					card,
					"No sign-in or email needed.\nYour buddy, tags and focus history save here.\nOnline accounts are not connected in this build.",
					Rect2(56, 247, 444, 90),
					16,
					UI.MUTED
				)
			)
		6:
			UI.label(card, "USERNAME", Rect2(32, 190, 440, 28), 12, UI.MUTED)
			var username := UI.input(
				card, str(GameState.profile.username), "study_buddy", Rect2(32, 228, 496, 50)
			)
			username.max_length = 24
			username.text_changed.connect(
				func(value):
					var valid: bool = (
						value.length() >= 3 and value.replace("_", "").is_valid_identifier()
					)
					next.disabled = not valid
					if valid:
						GameState.profile.username = value
			)
			UI.label(
				card,
				"3–24 letters, numbers or underscores. Local only.",
				Rect2(32, 295, 496, 45),
				14,
				UI.MUTED
			)
		7:
			_choices(flow, card, ["Lo-fi", "Dark academia", "Café piano", "Quiet nature"], "vibe")
		8:
			_choices(
				flow, card, ["A friend", "Social media", "Search", "Just exploring"], "referral"
			)
		9:
			_choices(
				flow,
				card,
				["Arts & humanities", "Science & technology", "Languages", "Independent study"],
				"subject"
			)
		10:
			_choices(
				flow,
				card,
				["Right now", "Later today", "Tomorrow", "When I have a moment"],
				"schedule"
			)
		11:
			UI.label(
				card, "Hello, %s." % GameState.profile.name, Rect2(32, 191, 496, 45), 30, UI.GREEN
			)
			(
				UI
				. label(
					card,
					"Pick a room. Find a seat.\nGive one thing your attention.\nWe'll keep you company.",
					Rect2(32, 254, 496, 130),
					22
				)
			)
	UI.fade(card)


static func _choices(flow, card: Control, choices: Array, key: String) -> void:
	var selected := str(GameState.profile.get(key, GameState.preferences.get(key, choices[0])))
	for i in choices.size():
		var value := str(choices[i])
		UI.button(
			card,
			("✓  " if selected == value else "") + value,
			Rect2(32, 168 + i * 61, 496, 46),
			func():
				if key == "vibe":
					GameState.preferences[key] = value
				else:
					GameState.profile[key] = value
				flow.draw(),
			UI.BLUE.darkened(0.48) if selected == value else UI.NESTED
		)
