extends RefCounted
## StudyTown auth: welcome + email/password login/signup cards (dark).
## Signup collects EMAIL + PASSWORD only. Backend is AuthService
## (local dev adapter unless a production adapter is approved).

const T := preload("res://scripts/ui/study_theme.gd")


static func splash(flow, root: Control) -> void:
	var card := T.modal(root, Rect2(440, 220, 400, 280), false)
	T.label(card, "◈  StudyTown", Rect2(0, 80, 400, 48), 38, T.TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	T.label(card, "A little focus, together.", Rect2(0, 132, 400, 26), 15, T.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func welcome(flow, root: Control) -> void:
	var card := T.modal(root, Rect2(390, 130, 500, 460))
	T.label(card, "◈  StudyTown", Rect2(0, 36, 500, 40), 34, T.TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	T.label(card, "A little focus, together.", Rect2(0, 80, 500, 26), 15, T.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	T.wrap(card, "Settle into a cozy room, take a seat, and focus alongside others.", Rect2(70, 136, 360, 56), 14, T.MUTED)
	T.primary_button(card, "Create account", Rect2(70, 230, 360, 56), func(): flow.auth_mode = "signup"; flow.draw())
	T.button(card, "Log in", Rect2(70, 298, 360, 56), func(): flow.auth_mode = "login"; flow.draw())
	T.wrap(card, "Your progress stays on this device in this build.", Rect2(70, 384, 360, 40), 12, T.FAINT)


static func form(flow, root: Control, mode: String) -> void:
	var is_signup: bool = mode != "login"
	var card := T.modal(root, Rect2(390, 120, 500, 480))
	T.label(card, "Create your account" if is_signup else "Welcome back", Rect2(0, 30, 500, 38), 27, T.TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	T.label(card, "EMAIL", Rect2(70, 100, 200, 22), 12, T.FAINT)
	var email := T.text_field(card, flow.auth_email, "you@example.com", Rect2(70, 124, 360, 52))
	email.text_changed.connect(func(_v: String): flow.auth_email = email.text)
	T.label(card, "PASSWORD", Rect2(70, 190, 200, 22), 12, T.FAINT)
	var password := T.text_field(card, "", "••••••••", Rect2(70, 214, 360, 52), true)
	password.text_changed.connect(func(_v: String): flow.auth_password = password.text)
	var error := T.label(card, flow.auth_error, Rect2(70, 274, 360, 30), 13, T.RED)
	error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cta := T.primary_button(
		card, "…" if flow.auth_busy else ("CREATE ACCOUNT" if is_signup else "LOG IN"),
		Rect2(70, 312, 360, 56),
		func(): flow.submit_auth(mode, email.text, password.text)
	)
	cta.disabled = flow.auth_busy
	T.button(
		card, "Back", Rect2(70, 376, 170, 46),
		func(): flow.auth_mode = "welcome"; flow.auth_error = ""; flow.draw()
	)
	T.button(
		card, "Log in" if is_signup else "Create account", Rect2(250, 376, 180, 46),
		func(): flow.auth_mode = "login" if is_signup else "signup"; flow.auth_error = ""; flow.draw()
	)
	if is_signup:
		T.wrap(card, "Email + password only. No social login.", Rect2(70, 432, 360, 30), 12, T.FAINT)
