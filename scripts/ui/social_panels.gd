extends RefCounted

const UI := preload("res://scripts/ui/dark_ui.gd")
const Preview := preload("res://scripts/ui/retro_character_preview.gd")


static func build(flow, root: Control) -> void:
	match flow.state:
		flow.State.ROOM_MEMBERS:
			_members(flow, root)
		flow.State.ROOM_CHAT:
			_chat(flow, root)
		flow.State.PLAYER_PROFILE_OVERLAY:
			_profile(flow, root)


static func _drawer(flow, root: Control, title: String, right: bool) -> Panel:
	var x := 922.0 if right else 18.0
	var panel := UI.panel(root, Rect2(x, 92, 340, 528), Color(0.10, 0.11, 0.13, 0.98))
	UI.label(panel, title, Rect2(22, 19, 260, 37), 24)
	UI.button(panel, "×", Rect2(280, 20, 40, 33), flow.close_overlay)
	panel.position.x += 45 if right else -45
	panel.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(
		panel, "position:x", x, 0.22
	)
	return panel


static func _members(flow, root: Control) -> void:
	var panel := _drawer(flow, root, "Room members", true)
	UI.button(panel, "Copy Room Code", Rect2(20, 79, 300, 39), flow.copy_code, UI.BLUE)
	UI.label(panel, "FRIENDS STUDYING", Rect2(22, 143, 295, 24), 11, UI.MUTED)
	UI.button(
		panel,
		"Invite a friend",
		Rect2(20, 178, 300, 37),
		func():
			flow.copy_code()
			flow.toast("Invite link copied as a room code. Online friends are not connected.")
	)
	var members: Array = flow.members()
	UI.label(panel, "IN THIS ROOM  ·  %d" % members.size(), Rect2(22, 239, 295, 24), 11, UI.MUTED)
	var scroller := ScrollContainer.new()
	scroller.position = Vector2(20, 276)
	scroller.size = Vector2(300, 209)
	panel.add_child(scroller)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroller.add_child(list)
	for i in members.size():
		var member: Dictionary = members[i]
		var row := Control.new()
		row.custom_minimum_size = Vector2(279, 42)
		list.add_child(row)
		var status := "YOU" if i == 0 else ("BREAK" if (i - 1) % 5 == 3 else "%dm" % member.minutes)
		UI.button(
			row,
			"%s   %s   ·   %s" % [member.country, member.name, status],
			Rect2(0, 0, 279, 35),
			func():
				flow.selected_member = i
				flow.open_overlay(flow.State.PLAYER_PROFILE_OVERLAY)
		)
	UI.label(panel, "Local buddies • simulated presence", Rect2(22, 493, 295, 22), 11, UI.MUTED)


static func _profile(flow, root: Control) -> void:
	var members: Array = flow.members()
	flow.selected_member = posmod(flow.selected_member, members.size())
	var member: Dictionary = members[flow.selected_member]
	var card := UI.panel(root, Rect2(480, 99, 418, 476), Color(0.10, 0.11, 0.13, 0.97))
	UI.button(card, "×", Rect2(355, 20, 40, 33), flow.close_overlay)
	UI.flag(card, str(member.country), Rect2(24, 38, 30, 18))
	UI.label(card, member.name, Rect2(65, 27, 266, 37), 25)
	UI.label(
		card,
		"YOU" if flow.selected_member == 0 else "LOCAL STUDY BUDDY",
		Rect2(24, 70, 320, 25),
		11,
		UI.GREEN
	)
	var portrait := Preview.make_character_preview(
		flow.main.character_loader,
		int(member.character),
		Vector2i(132, 128),
		true,
		flow.main._create_fallback_character
	)
	portrait.position = Vector2(259, 109)
	portrait.size = Vector2(132, 128)
	card.add_child(portrait)
	var minutes: int = (
		GameState.total_focus_minutes if flow.selected_member == 0 else member.minutes
	)
	UI.label(
		card,
		(
			"%.1fh  ·  %d day streak"
			% [minutes / 60.0, GameState.streak_days() if flow.selected_member == 0 else 3]
		),
		Rect2(24, 124, 221, 35),
		17
	)
	UI.label(card, "%d focus minutes" % minutes, Rect2(24, 177, 221, 34), 15, UI.MUTED)
	UI.label(
		card,
		(
			str(GameState.profile.subject)
			if flow.selected_member == 0
			else "Independent study · demo profile"
		),
		Rect2(24, 238, 370, 31),
		14,
		UI.MUTED
	)
	UI.label(card, member.tag, Rect2(24, 282, 370, 33), 21, UI.GREEN)
	UI.label(card, member.task if not str(member.task).is_empty() else "Finding a little focus", Rect2(24, 325, 370, 63), 17).autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	UI.button(
		card,
		"‹  Previous",
		Rect2(24, 412, 174, 38),
		func():
			flow.selected_member -= 1
			flow.draw()
	)
	UI.button(
		card,
		"Next  ›",
		Rect2(218, 412, 174, 38),
		func():
			flow.selected_member += 1
			flow.draw()
	)


static func _chat(flow, root: Control) -> void:
	var panel := _drawer(flow, root, "Room chat", false)
	UI.label(panel, "Activity & quiet conversation", Rect2(22, 63, 295, 29), 13, UI.MUTED)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 114)
	scroll.size = Vector2(300, 297)
	panel.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 13)
	scroll.add_child(lines)
	for message in flow.messages:
		var line := UI.label(lines, message, Rect2(0, 0, 280, 42), 14, UI.MUTED)
		line.custom_minimum_size = Vector2(278, 42)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var input := UI.input(panel, "", "Send a message…", Rect2(20, 445, 239, 44))
	input.max_length = 240
	var send := func():
		if input.text.strip_edges().is_empty():
			return
		flow.messages.append("%s: %s" % [GameState.profile.name, input.text.strip_edges()])
		flow.draw()
	UI.button(panel, "↑", Rect2(272, 445, 48, 44), send, UI.BLUE)
	input.text_submitted.connect(func(_value): send.call())
	UI.label(
		panel, "Local chat · messages aren't sent online", Rect2(22, 494, 298, 20), 11, UI.MUTED
	)
	if not flow.chat_acknowledged:
		var safety := UI.panel(panel, Rect2(20, 164, 300, 210), UI.NESTED, 18)
		UI.label(safety, "Keep chat safe", Rect2(18, 16, 264, 35), 23, UI.GREEN)
		UI.label(safety, "Be kind. Keep personal details private.\nMake room for everyone's quiet time.", Rect2(18, 66, 264, 72), 15).autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		UI.button(
			safety,
			"Got it",
			Rect2(18, 155, 264, 35),
			func():
				flow.chat_acknowledged = true
				flow.draw(),
			UI.BLUE
		)


static func install_nameplates(flow) -> void:
	var node := preload("res://scripts/ui/room_nameplates.gd").new()
	node.flow = flow
	flow.main.world_root.add_child(node)
