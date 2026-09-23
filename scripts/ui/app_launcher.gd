extends RefCounted
## App launcher drawer + Settings (incl. persistent Seat Availability View).

const T := preload("res://scripts/ui/study_theme.gd")


static func launcher(flow, root: Control) -> void:
	var panel := T.drawer(root, 1, 360.0)
	T.label(panel, "StudyTown", Rect2(24, 20, 300, 34), 22, T.TEXT)
	T.label(panel, "Where to?", Rect2(24, 56, 300, 22), 13, T.MUTED)
	var y := 104.0
	for entry in [
		["◈   Map", func(): flow.close_launcher(); flow.open_map()],
		["♧   Friends", func(): flow.close_launcher(); flow.open_overlay(flow.State.ROOM_MEMBERS)],
		["⏱   Focus", func(): flow.close_launcher(); flow.open_overlay(flow.State.CURRENT_FOCUS_EDITOR)],
		["⚙   Settings", func(): flow.launcher_page = "settings"; flow.draw()],
	]:
		T.button(panel, entry[0], Rect2(24, y, 312, 52), entry[1])
		y += 62.0
	T.button(panel, "Close", Rect2(24, 486, 312, 46), func(): flow.close_launcher())


static func settings(flow, root: Control) -> void:
	var panel := T.drawer(root, 1, 360.0)
	T.label(panel, "Settings", Rect2(24, 20, 300, 34), 22, T.TEXT)
	T.section(panel, "Gameplay", Rect2(24, 70, 300, 22))
	T.label(panel, "Seat availability view", Rect2(24, 100, 220, 30), 15, T.TEXT)
	T.toggle(
		panel, Rect2(252, 98, 84, 38),
		bool(GameState.preferences.get("seat_availability_view", true)),
		func(on: bool):
			GameState.preferences["seat_availability_view"] = on
			GameState.save()
			T.toast(flow.main.ui_root, "Seat availability " + ("on" if on else "off"))
	)
	T.wrap(panel, "Soft highlight on free seats. Hidden while seated.", Rect2(24, 142, 312, 44), 13, T.MUTED)
	T.section(panel, "Interface", Rect2(24, 222, 300, 22))
	T.label(panel, "Deep focus", Rect2(24, 252, 220, 30), 15, T.TEXT)
	T.toggle(
		panel, Rect2(252, 250, 84, 38),
		bool(GameState.preferences.get("deep_focus", false)),
		func(on: bool):
			GameState.preferences["deep_focus"] = on
			GameState.save()
	)
	T.button(panel, "‹ Launcher", Rect2(24, 486, 150, 46), func(): flow.launcher_page = "menu"; flow.draw())
	T.button(panel, "Close", Rect2(186, 486, 150, 46), func(): flow.close_launcher())
