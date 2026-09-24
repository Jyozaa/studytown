class_name OnboardingUI
extends RefCounted
## Short production onboarding: welcome → character → controls → destination.

enum Page { WELCOME, STEP1, STEP2, STEP3, STEP4 }

const AuthService := preload("res://scripts/services/auth_service.gd")


static func setup(ui, main: Node, root: Control, step: int, data: Dictionary = {}) -> Control:
	return build(ui, main, root, step, data)


static func build(ui, main: Node, root: Control, page: int, data: Dictionary) -> Control:
	var vp := ProductionTheme.vp_size(root)
	var modal := ProductionTheme.modal(root, Rect2(vp.x * 0.5 - 260, vp.y * 0.5 - 250, 520, 500))
	match page:
		Page.WELCOME:
			_welcome(ui, main, modal, data)
		Page.STEP1, Page.STEP2, Page.STEP3, Page.STEP4:
			_step(ui, main, modal, page, data)
	return modal


static func _brand(modal: Control) -> void:
	var b := ProductionTheme.label(modal, "StudyTown", 40, ProductionTheme.INK)
	b.position = Vector2(48, 30)
	b.size = Vector2(424, 62)


static func _welcome(ui, main: Node, modal: Control, data: Dictionary) -> void:
	_brand(modal)
	ProductionTheme.wrap(modal, "A cozy place to focus. Pick a seat\nin a quiet room and settle in —\nthe world stays right here with you.", Rect2(48, 120, 424, 80), 16).position = Vector2(48, 120)
	var email := ProductionTheme.text_field(modal, str(data.get("email", "")), "Email address")
	email.position = Vector2(48, 220)
	email.size = Vector2(424, 48)
	var pw := ProductionTheme.text_field(modal, "", "Password", true)
	pw.position = Vector2(48, 278)
	pw.size = Vector2(424, 48)
	_wire_focus_guard(main, email)
	_wire_focus_guard(main, pw)
	var err := ProductionTheme.label(modal, str(data.get("error", "")), 13, ProductionTheme.CORAL)
	err.position = Vector2(48, 330)
	err.size = Vector2(424, 24)
	var go := ProductionTheme.primary_button(modal, "Continue")
	go.position = Vector2(48, 360)
	go.size = Vector2(424, 54)
	go.pressed.connect(func(): ui.auth_submit(email.text, pw.text, bool(data.get("signup", false))))
	var swap := ProductionTheme.button(modal, "I have an account — log in" if bool(data.get("signup", false)) else "New here — create account")
	swap.position = Vector2(48, 424)
	swap.size = Vector2(424, 44)
	swap.pressed.connect(func(): ui.auth_swap())


static func _step(ui, main: Node, modal: Control, page: int, data: Dictionary) -> void:
	var titles := ["Welcome to StudyTown", "Choose your character", "Basic controls", "Choose where to study"]
	# Hand-broken lines: Label.size clamps to the unwrapped text width, so
	# fixed strings carry their own breaks (longest line < 424px).
	var bodies := [
		"Four quiet rooms share one little town.\nEverything happens in the world itself —\npanels stay small and out of the way.",
		"",
		"Move with WASD. Press E near\na glowing seat to sit. Press F\nto wave. Press Esc to close panels.",
		"Open the map any time to travel.\nYour seat, focus and rewards\ncome with you.",
	]
	var idx := page - Page.STEP1
	ProductionTheme.label(modal, "%d / 4" % (idx + 1), 13, ProductionTheme.INK_FAINT).position = Vector2(48, 24)
	ProductionTheme.label(modal, titles[idx], 30, ProductionTheme.INK).position = Vector2(48, 52)
	if idx == 1:
		_character_row(ui, main, modal, data)
	else:
		ProductionTheme.wrap(modal, bodies[idx], Rect2(48, 130, 424, 120), 16).position = Vector2(48, 130)
	var back := ProductionTheme.button(modal, "‹ Back")
	back.position = Vector2(48, 420)
	back.size = Vector2(140, 50)
	back.pressed.connect(func(): ui.onboarding_goto(idx - 1))
	var next := ProductionTheme.primary_button(modal, "Open map" if idx == 3 else "Next")
	next.position = Vector2(332, 420)
	next.size = Vector2(140, 50)
	next.pressed.connect(func(): ui.onboarding_goto(idx + 2 if idx == 3 else idx + 1))


static func _character_row(ui, main: Node, modal: Control, data: Dictionary) -> void:
	var profiles: Array = main.character_loader.profiles if main.get("character_loader") != null else []
	var current: int = int(data.get("selected_character", 0))
	var row := HBoxContainer.new()
	row.position = Vector2(48, 140)
	row.size = Vector2(424, 200)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	modal.add_child(row)
	for i in mini(4, profiles.size()):
		var profile = profiles[i]
		var name := str(profile.get("display_name", "Buddy")) if profile is Dictionary else str(profile.display_name)
		var chip := ProductionTheme.chip(row, name, i == current, ProductionTheme.AMBER)
		chip.custom_minimum_size = Vector2(0, 44)
		chip.pressed.connect(ui.onboarding_pick_character.bind(i))
	var note := ProductionTheme.label(modal, "Your buddy follows you everywhere.", 13, ProductionTheme.INK_SOFT)
	note.position = Vector2(48, 360)
	note.size = Vector2(424, 24)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func _wire_focus_guard(main: Node, field: LineEdit) -> void:
	field.focus_entered.connect(func(): main._set_movement_enabled(false))
	field.focus_exited.connect(func(): main._set_movement_enabled(not is_instance_valid(main.active_study_spot)))
