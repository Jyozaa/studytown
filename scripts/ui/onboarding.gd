extends RefCounted
## Short StudyTown onboarding (spec 60): friendly paper cards, one idea per
## screen, one obvious CTA, then the Map. No account profile questions —
## signup already collected email + password only.

const StudyTheme := preload("res://scripts/ui/study_theme.gd")
const Preview := preload("res://scripts/ui/retro_character_preview.gd")

const STEPS := [
	{
		"title": "Welcome to StudyTown",
		"body": "A cozy place to focus alongside other people.\nNo pressure, no noise — just a little time.",
		"cta": "Continue  →",
	},
	{
		"title": "Choose your study buddy",
		"body": "Pick an animal companion. They travel with you between rooms.",
		"cta": "Continue  →",
	},
	{
		"title": "Choose somewhere to study",
		"body": "The map shows every room. Walk in, and the world stays with you.",
		"cta": "Continue  →",
	},
	{
		"title": "Take an available seat",
		"body": "Soft highlights show free seats. Press E to sit, then start a focus session.",
		"cta": "Open the map",
	},
]


static func build(flow, root: Control) -> void:
	var step: int = clampi(flow.onboarding_step, 0, STEPS.size() - 1)
	var info: Dictionary = STEPS[step]

	# World + warm scrim + large paper card (spec 17).
	var dim := ColorRect.new()
	dim.color = StudyTheme.SCRIM
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var card := StudyTheme.panel(root, Rect2(370, 96, 540, 528), StudyTheme.PANEL, StudyTheme.R_MODAL)
	card.name = "OnboardingCard"
	StudyTheme.label(card, "◈  StudyTown", Rect2(0, 30, 540, 34), 24, StudyTheme.TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StudyTheme.label(card, "%d / %d" % [step + 1, STEPS.size()], Rect2(0, 68, 540, 20), 12, StudyTheme.FAINT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StudyTheme.label(card, str(info.title), Rect2(36, 104, 468, 56), 32 if step != 0 else 36, StudyTheme.TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body_label := StudyTheme.wrap(card, str(info.body), Rect2(56, 166, 428, 96), 16, StudyTheme.MUTED)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var advance := func():
		if flow.editing_buddy:
			flow.editing_buddy = false
			GameState.save()
			flow.home()
			return
		if step >= STEPS.size() - 1:
			GameState.onboarding_complete = true
			GameState.save()
			flow.navigate(flow.State.MAP)
			return
		flow.onboarding_step = step + 1
		flow.draw()

	StudyTheme.primary_button(
		card, "Save buddy" if flow.editing_buddy else str(info.cta), Rect2(56, 430, 428, 56), advance
	)
	if step == 1:
		_buddy_picker(flow, card)

	if step > 0 and not flow.editing_buddy:
		StudyTheme.button(
			card, "‹  Back", Rect2(56, 386, 140, 40),
			func():
				flow.onboarding_step = step - 1
				flow.draw()
		)


static func _buddy_picker(flow, card: Control) -> void:
	var count: int = maxi(1, flow.main.character_loader.profiles.size())
	GameState.selected_character = clampi(GameState.selected_character, 0, count - 1)
	var preview := Preview.make_character_preview(
		flow.main.character_loader, GameState.selected_character, Vector2i(200, 150), false, flow.main._create_fallback_character
	)
	preview.position = Vector2(170, 258)
	preview.size = Vector2(200, 150)
	card.add_child(preview)
	StudyTheme.icon_button(
		card, "‹", Rect2(120, 300, 44, 44),
		func():
			GameState.selected_character = posmod(GameState.selected_character - 1, count)
			flow.draw(),
		StudyTheme.NESTED, "Previous buddy"
	)
	StudyTheme.icon_button(
		card, "›", Rect2(376, 300, 44, 44),
		func():
			GameState.selected_character = (GameState.selected_character + 1) % count
			flow.draw(),
		StudyTheme.NESTED, "Next buddy"
	)
	StudyTheme.label(
		card,
		flow.main.character_loader.get_profile(GameState.selected_character).display_name,
		Rect2(36, 262, 468, 24), 15, StudyTheme.TEXT
	).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
