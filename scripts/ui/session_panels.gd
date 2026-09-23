extends RefCounted
## Gameplay HUD, seat prompt and session panels.
##
## Level 1 (HUD): compact room identity top-left, global pill top-right,
## music bottom-left, contextual seat prompt bottom-right.
## Level 2/3: session setup + timer cards keep the world visible on the right.
##
## All visuals come from StudyTownTheme; nothing here hand-styles tokens.

const UI := preload("res://scripts/ui/study_theme.gd")
const StudyTheme := preload("res://scripts/ui/study_theme.gd")
const Registry := preload("res://scripts/ui/destination_registry.gd")


static func _room_population() -> String:
	var entry: Dictionary = Registry.for_room_index(GameState.selected_room)
	return str(entry.get("population", "studying"))


static func hud(flow, root: Control, visible_state: int) -> void:
	if visible_state == flow.State.SEAT_TRANSITION:
		StudyTheme.label(
			root, "Settling in…", Rect2(440, 640, 400, 44), 17, StudyTheme.PANEL_2
		).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return

	# ---- TOP LEFT: compact room identity -------------------------------------
	var identity := StudyTheme.hud_pill(root, Rect2(20, 18, 238, 64))
	StudyTheme.label(identity, flow.main.current_room_name, Rect2(16, 8, 206, 28), 20, StudyTheme.TEXT)
	StudyTheme.label(identity, _room_population(), Rect2(16, 34, 206, 22), 13, StudyTheme.FAINT)

	# ---- TOP RIGHT: compact global controls ----------------------------------
	var tools := StudyTheme.hud_pill(root, Rect2(920, 18, 340, 60))
	StudyTheme.label(tools, "◈ %d" % GameState.focus_coins, Rect2(16, 8, 150, 44), 18, StudyTheme.TEXT)
	StudyTheme.icon_button(
		tools, "♫", Rect2(186, 7, 46, 46),
		func():
			flow.radio_expanded = true
			flow.draw(),
		StudyTheme.PANEL, "Music"
	)
	StudyTheme.icon_button(
		tools, "♧", Rect2(232, 7, 46, 46),
		func():
			flow.selected_member = 0
			flow.open_overlay(flow.State.ROOM_MEMBERS),
		StudyTheme.PANEL, "Room members"
	)
	StudyTheme.icon_button(
		tools, "☰", Rect2(278, 7, 46, 46), flow.open_launcher, StudyTheme.PANEL, "StudyTown menu"
	)

	# ---- BOTTOM LEFT: music --------------------------------------------------
	if flow.radio_expanded:
		var widget := StudyTheme.panel(root, Rect2(22, 556, 330, 148), StudyTheme.PANEL, StudyTheme.R_DRAWER)
		StudyTheme.label(widget, "♫  " + str(flow.radio.station), Rect2(18, 12, 220, 30), 17, StudyTheme.TEXT)
		StudyTheme.label(
			widget,
			"No local track linked" if flow.radio.radio_player.stream == null else ("Playing" if flow.radio.playing else "Paused"),
			Rect2(18, 44, 220, 22), 12, StudyTheme.FAINT
		)
		var play := StudyTheme.button(
			widget, "Pause" if flow.radio.playing else "Play", Rect2(18, 76, 140, 52),
			func():
				flow.radio.toggle_playback()
				flow.draw(),
			StudyTheme.GREEN
		)
		play.disabled = flow.radio.radio_player.stream == null
		StudyTheme.icon_button(
			widget, "×", Rect2(272, 12, 44, 44),
			func():
				flow.radio_expanded = false
				flow.draw(),
			StudyTheme.NESTED, "Collapse music"
		)
		var volume := StudyTheme.slider(
			widget, Rect2(18, 92, 294, 32), 0.0, 1.0, 0.01, flow.radio.master, Callable()
		)
		volume.value_changed.connect(
			func(value: float):
				flow.radio.master = value
				flow.radio._update_mix()
		)
		StudyTheme.label(widget, "VOLUME", Rect2(18, 132, 200, 14), 11, StudyTheme.FAINT)
	else:
		StudyTheme.button(
			root, "♫  " + str(flow.radio.station), Rect2(22, 636, 218, 51),
			func():
				flow.radio_expanded = true
				flow.draw(),
			StudyTheme.PANEL
		)

	# ---- BOTTOM RIGHT: contextual seat prompt (exploration only) -------------
	if visible_state == flow.State.ROOM_EXPLORING:
		var prompt := StudyTheme.panel(root, Rect2(878, 622, 382, 66), StudyTheme.PANEL_2, StudyTheme.R_DRAWER)
		prompt.name = "SeatPrompt"
		StudyTheme.keycap(prompt, "E", Rect2(14, 11, 44, 44))
		flow.main.prompt_label = StudyTheme.label(prompt, "", Rect2(70, 11, 298, 44), 18, StudyTheme.TEXT)
		prompt.set_script(preload("res://scripts/ui/seat_prompt.gd"))
		prompt.set("label", flow.main.prompt_label)
		prompt.set_process(true)
		StudyTheme.label(
			root, "WASD move   ·   E take seat   ·   F wave",
			Rect2(640, 694, 620, 20), 12, StudyTheme.PANEL
		).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# ---- ACTIVE SESSION / BREAK: compact timer card (left, world stays clear) -
	if visible_state in [flow.State.ACTIVE_SESSION, flow.State.ACTIVE_BREAK, flow.State.ENDING_SESSION]:
		_timer_card(flow, root)


static func _timer_card(flow, root: Control) -> void:
	var is_break: bool = flow.main.active_session_mode == "break"
	var accent: Color = StudyTheme.ORANGE if is_break else StudyTheme.GREEN
	var timer := StudyTheme.panel(root, Rect2(74, 300, 300, 202), StudyTheme.PANEL, StudyTheme.R_DRAWER)
	timer.add_theme_stylebox_override(
		"panel", StudyTheme.style(StudyTheme.PANEL, StudyTheme.R_DRAWER, accent.darkened(0.25))
	)
	StudyTheme.label(
		timer, "BREAK" if is_break else "FOCUS SESSION", Rect2(20, 16, 260, 20), 12, accent
	).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flow.timer_label = StudyTheme.label(
		timer, StudyTheme.countdown(FocusManager.get_remaining_seconds()), Rect2(10, 42, 280, 68), 52, StudyTheme.TEXT
	)
	flow.timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StudyTheme.label(
		timer, "Breathe a little" if is_break else flow.tag, Rect2(20, 114, 260, 24), 15, StudyTheme.FAINT
	).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pause := StudyTheme.button(timer, "Resume" if FocusManager.paused else "Pause", Rect2(20, 148, 130, 44), Callable())
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = "Resume" if FocusManager.paused else "Pause"
	)
	StudyTheme.button(timer, "End", Rect2(162, 148, 118, 44), flow.request_end, StudyTheme.RED)


static func setup(flow, root: Control) -> void:
	var card := StudyTheme.panel(root, Rect2(74, 112, 474, 496), StudyTheme.PANEL, StudyTheme.R_MODAL)
	card.name = "SessionSetupPanel"
	StudyTheme.label(card, "Start focus session", Rect2(28, 22, 418, 40), 28, StudyTheme.TEXT)

	# Duration: 5 min – 2 hr, large current value.
	var field := StudyTheme.text_field(card, UI.hhmm(flow.duration), "00:25", Rect2(28, 74, 418, 74))
	field.name = "DurationInput"
	field.max_length = 5
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 48)
	field.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	field.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var total := StudyTheme.label(
		card, "%d minutes" % (flow.duration / 60), Rect2(28, 148, 418, 24), 13, StudyTheme.FAINT
	)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var range_slider := StudyTheme.slider(card, Rect2(32, 182, 410, 24), 5, 120, 5, flow.duration / 60, Callable())
	range_slider.name = "DurationSlider"
	StudyTheme.label(card, "5 min", Rect2(32, 206, 60, 18), 12, StudyTheme.FAINT)
	StudyTheme.label(card, "2 hr", Rect2(392, 206, 50, 18), 12, StudyTheme.FAINT).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var reward_text := StudyTheme.label(card, "", Rect2(28, 330, 418, 30), 20, StudyTheme.GREEN)
	reward_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sync := func(seconds: int):
		flow.duration = seconds
		field.text = UI.hhmm(seconds)
		range_slider.set_value_no_signal(seconds / 60)
		total.text = "%d minutes" % (seconds / 60)
		reward_text.text = "Reward  ◈ +%d" % GameState.projected_reward(seconds / 60)
	range_slider.value_changed.connect(func(value): sync.call(int(value) * 60))
	field.text_submitted.connect(
		func(value):
			sync.call(UI.parse_duration(value))
			field.release_focus()
	)
	field.focus_exited.connect(func(): sync.call(UI.parse_duration(field.text)))
	field.text_changed.connect(
		func(value):
			if (value.length() == 4 and value.is_valid_int()) or (value.length() == 5 and value.contains(":")):
				sync.call(UI.parse_duration(value))
	)
	sync.call(flow.duration)

	# Tag chips: Study / Reading / Work / Creative.
	for i in mini(GameState.tags.size(), 4):
		var tag_name := str(GameState.tags[i])
		var chip := StudyTheme.chip(
			card, tag_name, Rect2(28 + i * 106, 244, 100, 40), flow.tag == tag_name
		)
		chip.pressed.connect(
			func():
				flow.tag = tag_name
				flow.draw()
		)

	StudyTheme.button(
		card,
		"✎  %s" % (flow.focus_text if not flow.focus_text.is_empty() else "Set your focus"),
		Rect2(28, 292, 300, 38),
		flow.open_overlay.bind(flow.State.CURRENT_FOCUS_EDITOR)
	)
	StudyTheme.icon_button(
		card, "⚙", Rect2(342, 292, 44, 38), flow.open_overlay.bind(flow.State.SESSION_SETTINGS),
		StudyTheme.NESTED, "Session settings"
	)

	StudyTheme.primary_button(card, "START SESSION", Rect2(28, 372, 418, 54), flow.start_session)
	StudyTheme.label(
		card, "1 point / minute  ·  +5 for 25 minutes or more",
		Rect2(28, 434, 418, 22), 12, StudyTheme.FAINT
	).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StudyTheme.button(card, "‹  Leave seat", Rect2(28, 460, 418, 30), flow.back)


static func _modal(root: Control, title: String, close: Callable, height := 484) -> Panel:
	# The application flow already owns the world scrim for exclusive overlays;
	# this only builds the warm surface + a short scale-in.
	var card := StudyTheme.panel(root, Rect2(230, (720 - height) / 2, 820, height), StudyTheme.PANEL, StudyTheme.R_MODAL)
	card.scale = Vector2(0.97, 0.97)
	card.pivot_offset = card.size * 0.5
	card.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(
		card, "scale", Vector2.ONE, StudyTheme.T_MODAL
	)
	StudyTheme.label(card, title, Rect2(30, 23, 650, 44), 28, StudyTheme.TEXT)
	StudyTheme.icon_button(card, "×", Rect2(742, 25, 48, 44), close, StudyTheme.NESTED, "Close")
	return card


static func focus_editor(flow, root: Control) -> void:
	var card := _modal(root, "Current Focus", flow.close_overlay, 560)
	StudyTheme.label(card, "WHAT ARE YOU FOCUSING ON?", Rect2(30, 83, 510, 22), 12, StudyTheme.FAINT)
	var field := StudyTheme.text_field(card, flow.focus_text, "One thing you want to make progress on", Rect2(30, 115, 466, 57))
	field.max_length = 120
	var count := StudyTheme.label(card, "%d / 120" % field.text.length(), Rect2(357, 176, 140, 24), 12, StudyTheme.FAINT)
	StudyTheme.button(
		card, "Clear", Rect2(30, 180, 80, 40),
		func():
			field.text = ""
			field.text_changed.emit("")
	)
	StudyTheme.label(card, "ALL TAGS", Rect2(30, 237, 230, 22), 12, StudyTheme.FAINT)
	var tag_input := StudyTheme.text_field(card, "", "Create or rename tag", Rect2(30, 480, 274, 44))
	tag_input.max_length = 24
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 270)
	scroll.size = Vector2(468, 188)
	card.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	var selected := StudyTheme.label(card, flow.tag, Rect2(552, 143, 220, 39), 23, StudyTheme.PURPLE)
	var preview_text := StudyTheme.label(
		card, field.text if not field.text.is_empty() else "No current focus", Rect2(552, 203, 220, 128), 18, StudyTheme.FAINT
	)
	preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	StudyTheme.label(card, "PREVIEW", Rect2(552, 91, 220, 25), 12, StudyTheme.FAINT)
	StudyTheme.label(card, "▏ Selected", Rect2(552, 342, 215, 30), 14, StudyTheme.GREEN)
	field.text_changed.connect(
		func(value):
			count.text = "%d / 120" % value.length()
			preview_text.text = value
			flow.focus_text = value
	)
	for tag_value in GameState.tags:
		var tag_name := str(tag_value)
		var row := Control.new()
		row.custom_minimum_size = Vector2(444, 39)
		rows.add_child(row)
		StudyTheme.button(
			row, ("✓  " if flow.tag == tag_name else "▏  ") + tag_name, Rect2(0, 0, 305, 39),
			func():
				flow.tag = tag_name
				flow.draw(),
			StudyTheme.PURPLE if flow.tag == tag_name else StudyTheme.NESTED
		)
		StudyTheme.button(
			row, "✎", Rect2(318, 0, 48, 39),
			func():
				tag_input.text = tag_name
				tag_input.set_meta("editing", tag_name)
				tag_input.grab_focus()
		)
		var delete := StudyTheme.button(
			row, "×", Rect2(378, 0, 48, 39),
			func():
				GameState.tags.erase(tag_name)
				if flow.tag == tag_name:
					flow.tag = str(GameState.tags[0])
				GameState.save()
				flow.draw()
		)
		delete.disabled = GameState.tags.size() <= 1
	StudyTheme.button(
		card, "Add / save", Rect2(320, 480, 175, 44),
		func():
			var value := tag_input.text.strip_edges()
			if value.is_empty() or GameState.tags.has(value):
				return
			var old := str(tag_input.get_meta("editing", ""))
			if not old.is_empty():
				GameState.tags.erase(old)
			GameState.tags.append(value)
			flow.tag = value
			GameState.save()
			flow.draw()
	)
	StudyTheme.primary_button(
		card, "Save Settings", Rect2(542, 480, 248, 48),
		func():
			flow.save_focus()
			flow.close_overlay(true)
	)


static func settings(flow, root: Control) -> void:
	var card := _modal(root, "Session settings", flow.close_overlay)
	StudyTheme.label(card, "BOOSTS", Rect2(30, 94, 430, 24), 12, StudyTheme.FAINT)
	StudyTheme.button(
		card, "Deep focus    " + ("ON" if flow.deep_focus else "OFF"), Rect2(30, 137, 425, 54),
		func():
			flow.deep_focus = not flow.deep_focus
			flow.draw()
	)
	StudyTheme.label(
		card, "A local commitment to keep distractions outside.", Rect2(40, 196, 416, 29), 13, StudyTheme.FAINT
	)
	var long_session := StudyTheme.label(
		card,
		"Long session  ·  " + ("ACTIVE  +5" if flow.duration >= 1500 else "25 minutes to unlock"),
		Rect2(40, 238, 416, 38), 17,
		StudyTheme.GREEN if flow.duration >= 1500 else StudyTheme.FAINT
	)
	StudyTheme.label(card, "Friend boost  ·  coming later", Rect2(40, 297, 416, 38), 17, StudyTheme.FAINT)
	StudyTheme.label(
		card, "No extra points are awarded for mock boosts.", Rect2(40, 345, 416, 40), 13, StudyTheme.FAINT
	)
	StudyTheme.label(card, "FOCUS TIME", Rect2(510, 96, 280, 24), 12, StudyTheme.FAINT)
	var time_label := StudyTheme.label(card, UI.hhmm(flow.duration), Rect2(510, 142, 280, 72), 47, StudyTheme.TEXT)
	var points := StudyTheme.label(
		card, "◈ %d points" % GameState.projected_reward(flow.duration / 60), Rect2(510, 287, 280, 40), 19, StudyTheme.GREEN
	)
	StudyTheme.slider(
		card, Rect2(510, 230, 273, 24), 5, 120, 5, flow.duration / 60,
		func(value):
			flow.duration = int(value) * 60
			time_label.text = UI.hhmm(flow.duration)
			long_session.text = "Long session  ·  " + ("ACTIVE  +5" if flow.duration >= 1500 else "25 minutes to unlock")
			long_session.add_theme_color_override(
				"font_color", StudyTheme.GREEN if flow.duration >= 1500 else StudyTheme.FAINT
			)
			points.text = "◈ %d points" % GameState.projected_reward(int(value))
	)
	StudyTheme.primary_button(
		card, "Save Settings", Rect2(510, 386, 280, 48),
		func():
			flow.save_focus()
			flow.close_overlay(true)
	)


static func ending(flow, root: Control) -> void:
	var card := StudyTheme.panel(root, Rect2(74, 227, 464, 279), StudyTheme.PANEL, StudyTheme.R_DRAWER)
	StudyTheme.label(card, "ENDING SESSION", Rect2(28, 24, 408, 24), 12, StudyTheme.RED)
	StudyTheme.label(card, "Leaving already?", Rect2(28, 60, 408, 49), 31, StudyTheme.TEXT)
	StudyTheme.label(
		card,
		"Only completed focus minutes earn points.\nYou can stay here and keep going.",
		Rect2(28, 120, 408, 58), 16, StudyTheme.MUTED
	)
	StudyTheme.button(card, "Leave room", Rect2(28, 210, 191, 48), flow.end_early, StudyTheme.RED)
	StudyTheme.primary_button(card, "Continue", Rect2(235, 210, 201, 48), flow.continue_session)


static func complete(flow, root: Control) -> void:
	var card := StudyTheme.panel(root, Rect2(74, 184, 464, 367), StudyTheme.PANEL, StudyTheme.R_DRAWER)
	StudyTheme.label(card, "SESSION COMPLETE", Rect2(28, 26, 408, 24), 12, StudyTheme.GREEN)
	StudyTheme.label(card, "+%d points" % flow.reward, Rect2(28, 70, 408, 58), 43, StudyTheme.GREEN)
	StudyTheme.label(card, "A little progress looks good on you.", Rect2(28, 145, 408, 37), 19, StudyTheme.TEXT)
	StudyTheme.label(
		card,
		"%s  ·  %s\n%d minutes  ·  %s" % [flow.tag, FocusManager.task, flow.elapsed_minutes, flow.main.current_room_name],
		Rect2(28, 197, 408, 73), 15, StudyTheme.FAINT
	)
	StudyTheme.button(
		card, "Take a little break  →", Rect2(28, 295, 408, 48),
		flow.navigate.bind(flow.State.BREAK_SETUP), StudyTheme.ORANGE
	)


static func break_setup(flow, root: Control) -> void:
	var card := StudyTheme.panel(root, Rect2(74, 172, 464, 425), StudyTheme.PANEL, StudyTheme.R_DRAWER)
	StudyTheme.label(card, "BREAK TIME", Rect2(28, 23, 408, 24), 12, StudyTheme.ORANGE)
	StudyTheme.label(card, "Take a break", Rect2(28, 56, 408, 48), 32, StudyTheme.TEXT)
	StudyTheme.label(
		card, "Step away for a moment. Your seat stays yours.", Rect2(28, 108, 408, 37), 15, StudyTheme.FAINT
	)
	var time := StudyTheme.label(card, UI.hhmm(flow.break_duration), Rect2(28, 154, 408, 64), 44, StudyTheme.TEXT)
	StudyTheme.slider(
		card, Rect2(30, 244, 402, 24), 1, 30, 1, flow.break_duration / 60,
		func(value):
			flow.break_duration = int(value) * 60
			time.text = UI.hhmm(flow.break_duration)
	)
	StudyTheme.label(card, "1m", Rect2(30, 269, 70, 21), 12, StudyTheme.FAINT)
	StudyTheme.label(card, "30m", Rect2(394, 269, 44, 21), 12, StudyTheme.FAINT)
	var lounger: bool = (
		is_instance_valid(flow.main.active_study_spot)
		and flow.main.active_study_spot.seat_type == "tanning_bed"
	)
	StudyTheme.button(
		card, "Back to room" if lounger else "Another Session", Rect2(28, 307, 196, 44),
		flow.leave_seat.bind(false) if lounger else flow.another_session
	)
	StudyTheme.button(card, "Finish & Leave", Rect2(240, 307, 196, 44), flow.leave_seat.bind(true))
	StudyTheme.button(
		card, "Start Break", Rect2(28, 368, 408, 44), flow.start_break, StudyTheme.ORANGE
	)
