extends RefCounted

const UI := preload("res://scripts/ui/dark_ui.gd")


static func hud(flow, root: Control, visible_state: int) -> void:
	if visible_state == flow.State.SEAT_TRANSITION:
		UI.label(root, "Settling in…", Rect2(34, 634, 450, 45), 20)
		return
	UI.button(root, "‹", Rect2(22, 22, 48, 44), flow.back)
	UI.button(
		root,
		"○",
		Rect2(82, 22, 48, 44),
		func():
			flow.selected_member = 0
			flow.open_overlay(flow.State.PLAYER_PROFILE_OVERLAY)
	)
	UI.label(root, flow.main.current_room_name, Rect2(150, 21, 370, 29), 20)
	UI.label(root, "A little focus, together", Rect2(151, 50, 330, 22), 12, Color("D0D3D9"))
	var tools := UI.panel(root, Rect2(883, 20, 375, 54), Color(0.10, 0.11, 0.13, 0.96), 18)
	UI.label(tools, "◈ %d   ◇ 0" % GameState.focus_coins, Rect2(15, 7, 143, 38), 16)
	UI.button(tools, "♫", Rect2(154, 5, 47, 38), flow.open_overlay.bind(flow.State.MUSIC_RADIO))
	UI.button(tools, "Copy room code", Rect2(213, 5, 149, 38), flow.copy_code)
	UI.button(root, "☰", Rect2(18, 335, 47, 48), flow.open_overlay.bind(flow.State.ROOM_CHAT))
	UI.button(root, "♧", Rect2(1213, 335, 47, 48), flow.open_overlay.bind(flow.State.ROOM_MEMBERS))
	if flow.radio_expanded:
		var widget := UI.panel(root, Rect2(22, 599, 342, 91), UI.PANEL, 18)
		UI.label(widget, "♫  " + str(flow.radio.station), Rect2(15, 6, 254, 28), 16)
		UI.button(
			widget,
			"⌄",
			Rect2(286, 9, 40, 25),
			func():
				flow.radio_expanded = false
				flow.draw()
		)
		var play := UI.button(
			widget,
			"Pause" if flow.radio.playing else "Play",
			Rect2(15, 44, 89, 31),
			func():
				flow.radio.toggle_playback()
				flow.draw(),
			UI.BLUE
		)
		play.disabled = flow.radio.radio_player.stream == null
		UI.button(
			widget,
			"Unmute" if flow.radio.muted else "Mute",
			Rect2(117, 44, 89, 31),
			func():
				flow.radio.muted = not flow.radio.muted
				flow.radio._update_mix()
				flow.draw()
		)
		UI.button(
			widget,
			"Settings",
			Rect2(219, 44, 106, 31),
			flow.open_overlay.bind(flow.State.MUSIC_RADIO)
		)
	else:
		UI.button(
			root,
			"♫  " + str(flow.radio.station),
			Rect2(22, 636, 218, 51),
			func():
				flow.radio_expanded = true
				flow.draw()
		)
	if visible_state == flow.State.ROOM_EXPLORING:
		var prompt := UI.panel(root, Rect2(445, 628, 390, 58), Color(0.10, 0.11, 0.13, 0.95), 22)
		flow.main.prompt_label = UI.label(prompt, "", Rect2(15, 5, 360, 44), 17)
		flow.main.prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.set_script(preload("res://scripts/ui/seat_prompt.gd"))
		prompt.set("label", flow.main.prompt_label)
		prompt.set_process(true)
		UI.label(
			root,
			"WASD move   ·   E take seat   ·   F wave",
			Rect2(447, 689, 540, 21),
			12,
			Color("D0D3D9")
		)
	elif (
		visible_state
		in [flow.State.ACTIVE_SESSION, flow.State.ACTIVE_BREAK, flow.State.ENDING_SESSION]
	):
		var is_break: bool = flow.main.active_session_mode == "break"
		var accent := UI.ORANGE if is_break else UI.GREEN
		var timer_x := 730 if flow.state == flow.State.ROOM_MEMBERS else 1088
		var timer := UI.panel(root, Rect2(timer_x, 492, 170, 195), UI.PANEL, 22)
		timer.add_theme_stylebox_override("panel", UI.style(UI.PANEL, 22, accent.darkened(0.28)))
		UI.label(timer, "BREAK" if is_break else "FOCUS SESSION", Rect2(14, 12, 142, 24), 11, accent).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flow.timer_label = UI.label(
			timer, UI.countdown(FocusManager.get_remaining_seconds()), Rect2(10, 44, 150, 46), 31
		)
		flow.timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.label(timer, "Breathe a little" if is_break else flow.tag, Rect2(14, 94, 142, 26), 14, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pause := UI.button(
			timer, "Resume" if FocusManager.paused else "Pause", Rect2(13, 138, 84, 35), Callable()
		)
		pause.pressed.connect(
			func():
				FocusManager.toggle_pause()
				pause.text = "Resume" if FocusManager.paused else "Pause"
		)
		UI.button(timer, "End", Rect2(106, 138, 51, 35), flow.request_end, UI.CORAL.darkened(0.50))


static func setup(flow, root: Control) -> void:
	var card := UI.panel(root, Rect2(74, 143, 464, 457))
	card.name = "SessionSetupPanel"
	UI.label(card, "YOUR NEXT SMALL WIN", Rect2(26, 17, 350, 25), 11, UI.MUTED)
	var field := UI.input(card, UI.hhmm(flow.duration), "00:25", Rect2(26, 56, 412, 77))
	field.name = "DurationInput"
	field.max_length = 5
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 52)
	field.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var total := UI.label(
		card, "TOTAL  ·  %d MINUTES" % (flow.duration / 60), Rect2(26, 135, 412, 28), 12, UI.MUTED
	)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var reward_text := UI.label(card, "", Rect2(44, 319, 365, 30), 20, UI.GREEN)
	var range_slider := UI.slider(
		card, Rect2(30, 180, 404, 22), 5, 120, 5, flow.duration / 60, Callable()
	)
	range_slider.name = "DurationSlider"
	var sync := func(seconds: int):
		flow.duration = seconds
		field.text = UI.hhmm(seconds)
		range_slider.set_value_no_signal(seconds / 60)
		total.text = "TOTAL  ·  %d MINUTES" % (seconds / 60)
		reward_text.text = "◈ %d points   ·   ◇ 0" % GameState.projected_reward(seconds / 60)
	range_slider.value_changed.connect(func(value): sync.call(int(value) * 60))
	field.text_submitted.connect(
		func(value):
			sync.call(UI.parse_duration(value))
			field.release_focus()
	)
	field.focus_exited.connect(func(): sync.call(UI.parse_duration(field.text)))
	field.text_changed.connect(
		func(value):
			if (
				(value.length() == 4 and value.is_valid_int())
				or (value.length() == 5 and value.contains(":"))
			):
				sync.call(UI.parse_duration(value))
	)
	sync.call(flow.duration)
	for marker in [["5m", 0.0], ["25m", 20.0 / 115.0], ["1h", 55.0 / 115.0], ["2h", 1.0]]:
		UI.label(card, marker[0], Rect2(17 + marker[1] * 404, 205, 32, 20), 12, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.button(
		card,
		(
			"▏ %s  ·  %s   ✎"
			% [flow.tag, flow.focus_text if not flow.focus_text.is_empty() else "Set your focus"]
		),
		Rect2(26, 244, 412, 49),
		flow.open_overlay.bind(flow.State.CURRENT_FOCUS_EDITOR)
	)
	UI.button(
		card, "⚙", Rect2(380, 316, 58, 35), flow.open_overlay.bind(flow.State.SESSION_SETTINGS)
	)
	UI.label(
		card,
		"1 point / minute  ·  +5 for 25 minutes or more",
		Rect2(28, 354, 410, 24),
		12,
		UI.MUTED
	)
	UI.button(
		card,
		"Start Session" + ("  ·  10s test" if flow.debug_short else ""),
		Rect2(26, 397, 412, 43),
		flow.start_session,
		UI.BLUE
	)


static func _modal(root: Control, title: String, close: Callable, height := 484) -> Panel:
	var card := UI.panel(root, Rect2(230, (720 - height) / 2, 820, height))
	UI.label(card, title, Rect2(30, 23, 650, 44), 28)
	UI.button(card, "×", Rect2(742, 25, 48, 36), close)
	return card


static func focus_editor(flow, root: Control) -> void:
	var card := _modal(root, "Current Focus", flow.close_overlay, 560)
	UI.label(card, "WHAT ARE YOU FOCUSING ON?", Rect2(30, 83, 510, 25), 11, UI.MUTED)
	var field := UI.input(
		card, flow.focus_text, "One thing you want to make progress on", Rect2(30, 119, 466, 57)
	)
	field.max_length = 120
	var count := UI.label(
		card, "%d / 120" % field.text.length(), Rect2(357, 180, 140, 25), 12, UI.MUTED
	)
	UI.button(
		card,
		"Clear",
		Rect2(30, 184, 80, 30),
		func():
			field.text = ""
			field.text_changed.emit("")
	)
	UI.label(card, "ALL TAGS", Rect2(30, 237, 230, 22), 11, UI.MUTED)
	var tag_input := UI.input(card, "", "Create or rename tag", Rect2(30, 480, 274, 39))
	tag_input.max_length = 24
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 270)
	scroll.size = Vector2(468, 188)
	card.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	var selected := UI.label(card, flow.tag, Rect2(552, 143, 220, 39), 23)
	var preview_text := UI.label(
		card,
		field.text if not field.text.is_empty() else "No current focus",
		Rect2(552, 203, 220, 128),
		18,
		UI.MUTED
	)
	preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(card, "PREVIEW", Rect2(552, 91, 220, 25), 11, UI.MUTED)
	UI.label(card, "▏ Selected", Rect2(552, 342, 215, 30), 14, UI.GREEN)
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
		UI.button(
			row,
			("✓  " if flow.tag == tag_name else "▏  ") + tag_name,
			Rect2(0, 0, 305, 32),
			func():
				flow.tag = tag_name
				flow.draw(),
			UI.BLUE.darkened(0.48) if flow.tag == tag_name else UI.NESTED
		)
		UI.button(
			row,
			"✎",
			Rect2(318, 0, 48, 32),
			func():
				tag_input.text = tag_name
				tag_input.set_meta("editing", tag_name)
				tag_input.grab_focus()
		)
		var delete := UI.button(
			row,
			"×",
			Rect2(378, 0, 48, 32),
			func():
				GameState.tags.erase(tag_name)
				if flow.tag == tag_name:
					flow.tag = str(GameState.tags[0])
				GameState.save()
				flow.draw()
		)
		delete.disabled = GameState.tags.size() <= 1
	UI.button(
		card,
		"Add / save",
		Rect2(320, 480, 175, 39),
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
	UI.button(
		card,
		"Save Settings",
		Rect2(542, 480, 248, 48),
		func():
			flow.save_focus()
			flow.close_overlay(true),
		UI.BLUE
	)


static func settings(flow, root: Control) -> void:
	var card := _modal(root, "Session settings", flow.close_overlay)
	UI.label(card, "BOOSTS", Rect2(30, 94, 430, 24), 11, UI.MUTED)
	UI.button(
		card,
		"Deep focus    " + ("ON" if flow.deep_focus else "OFF"),
		Rect2(30, 137, 425, 49),
		func():
			flow.deep_focus = not flow.deep_focus
			flow.draw()
	)
	UI.label(
		card,
		"A local commitment to keep distractions outside.",
		Rect2(40, 192, 416, 29),
		13,
		UI.MUTED
	)
	var long_session := UI.label(
		card,
		"Long session  ·  " + ("ACTIVE  +5" if flow.duration >= 1500 else "25 minutes to unlock"),
		Rect2(40, 234, 416, 38),
		17,
		UI.GREEN if flow.duration >= 1500 else UI.MUTED
	)
	UI.label(card, "Friend boost  ·  coming later", Rect2(40, 293, 416, 38), 17, UI.MUTED)
	UI.label(
		card, "No extra points are awarded for mock boosts.", Rect2(40, 341, 416, 40), 13, UI.MUTED
	)
	UI.label(card, "FOCUS TIME", Rect2(510, 96, 280, 24), 11, UI.MUTED)
	var time_label := UI.label(card, UI.hhmm(flow.duration), Rect2(510, 142, 280, 72), 47)
	var points := UI.label(
		card,
		"◈ %d points  ·  ◇ 0" % GameState.projected_reward(flow.duration / 60),
		Rect2(510, 287, 280, 40),
		19,
		UI.GREEN
	)
	UI.slider(
		card,
		Rect2(510, 230, 273, 24),
		5,
		120,
		5,
		flow.duration / 60,
		func(value):
			flow.duration = int(value) * 60
			time_label.text = UI.hhmm(flow.duration)
			long_session.text = (
				"Long session  ·  "
				+ ("ACTIVE  +5" if flow.duration >= 1500 else "25 minutes to unlock")
			)
			long_session.add_theme_color_override(
				"font_color", UI.GREEN if flow.duration >= 1500 else UI.MUTED
			)
			points.text = "◈ %d points  ·  ◇ 0" % GameState.projected_reward(int(value))
	)
	UI.button(
		card,
		"Save Settings",
		Rect2(510, 386, 280, 48),
		func():
			flow.save_focus()
			flow.close_overlay(true),
		UI.BLUE
	)


static func ending(flow, root: Control) -> void:
	var card := UI.panel(root, Rect2(74, 227, 464, 279))
	UI.label(card, "ENDING SESSION", Rect2(28, 24, 408, 27), 12, UI.CORAL)
	UI.label(card, "Leaving already?", Rect2(28, 66, 408, 49), 31)
	UI.label(
		card,
		"Only completed focus minutes earn points.\nYou can stay here and keep going.",
		Rect2(28, 124, 408, 58),
		16,
		UI.MUTED
	)
	UI.button(card, "Leave room", Rect2(28, 210, 191, 42), flow.end_early, UI.CORAL.darkened(0.42))
	UI.button(card, "Continue", Rect2(235, 210, 201, 42), flow.continue_session, UI.BLUE)


static func complete(flow, root: Control) -> void:
	var card := UI.panel(root, Rect2(74, 184, 464, 367))
	UI.label(card, "SESSION COMPLETE", Rect2(28, 26, 408, 25), 12, UI.GREEN)
	UI.label(card, "+%d points" % flow.reward, Rect2(28, 77, 408, 58), 43, UI.GREEN)
	UI.label(card, "A little progress looks good on you.", Rect2(28, 151, 408, 37), 19)
	UI.label(
		card,
		(
			"%s  ·  %s\n%d minutes  ·  %s"
			% [flow.tag, FocusManager.task, flow.elapsed_minutes, flow.main.current_room_name]
		),
		Rect2(28, 203, 408, 73),
		15,
		UI.MUTED
	)
	UI.button(
		card,
		"Take a little break  →",
		Rect2(28, 295, 408, 43),
		flow.navigate.bind(flow.State.BREAK_SETUP),
		UI.ORANGE.darkened(0.20)
	)


static func break_setup(flow, root: Control) -> void:
	var card := UI.panel(root, Rect2(74, 172, 464, 425))
	UI.label(card, "BREAK TIME", Rect2(28, 23, 408, 25), 12, UI.ORANGE)
	UI.label(card, "Take a break", Rect2(28, 58, 408, 48), 32)
	UI.label(
		card,
		"Step away for a moment. Your seat stays yours.",
		Rect2(28, 110, 408, 37),
		15,
		UI.MUTED
	)
	var time := UI.label(card, UI.hhmm(flow.break_duration), Rect2(28, 156, 408, 64), 44)
	UI.slider(
		card,
		Rect2(30, 244, 402, 22),
		1,
		30,
		1,
		flow.break_duration / 60,
		func(value):
			flow.break_duration = int(value) * 60
			time.text = UI.hhmm(flow.break_duration),
		UI.ORANGE
	)
	UI.label(card, "1m", Rect2(30, 269, 70, 21), 12, UI.MUTED)
	UI.label(card, "30m", Rect2(394, 269, 44, 21), 12, UI.MUTED)
	var lounger: bool = (
		is_instance_valid(flow.main.active_study_spot)
		and flow.main.active_study_spot.seat_type == "tanning_bed"
	)
	UI.button(
		card,
		"Back to room" if lounger else "Another Session",
		Rect2(28, 307, 196, 39),
		flow.leave_seat.bind(false) if lounger else flow.another_session
	)
	UI.button(card, "Finish & Leave", Rect2(240, 307, 196, 39), flow.leave_seat.bind(true))
	UI.button(
		card, "Start Break", Rect2(28, 368, 408, 39), flow.start_break, UI.ORANGE.darkened(0.16)
	)
