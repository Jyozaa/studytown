#!/usr/bin/env python3
from __future__ import annotations

import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd()
MAIN_PATH = ROOT / "scripts" / "core" / "main.gd"
BACKUP_DIR = ROOT / "assets" / "dev_local" / "backups" / "retro_compact_focus_ui"

FUNCTIONS: dict[str, str] = {}

FUNCTIONS["_update_nearest_spot"] = r'''func _update_nearest_spot() -> void:
	if not is_instance_valid(player):
		return

	var best := -1
	var best_distance := INF

	for i: int in range(study_spots.size()):
		if not study_spots[i].is_available():
			continue

		var distance: float = player.global_position.distance_to(
			study_spots[i].standing_position
		)

		if (
			distance <= study_spots[i].interaction_radius
			and distance < best_distance
		):
			best = i
			best_distance = distance

	nearest_spot = best

	if debug_spots_visible:
		for i: int in range(study_spots.size()):
			study_spots[i].update_debug(
				i == best
			)

	if is_instance_valid(prompt_label):
		var visible_now := best >= 0
		prompt_label.visible = visible_now

		var prompt_parent := prompt_label.get_parent()

		if prompt_parent is Control:
			(prompt_parent as Control).visible = visible_now

		if visible_now:
			var nearest = study_spots[best]

			if str(nearest.seat_type) == "tanning_bed":
				prompt_label.text = "E  REST HERE"
			else:
				prompt_label.text = "E  STUDY HERE"
'''

FUNCTIONS["_build_room_ui"] = r'''func _build_room_ui() -> void:
	var room_panel := Panel.new()
	room_panel.position = Vector2(14, 14)
	room_panel.size = Vector2(316, 50)
	room_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.09, 0.29, 0.51, 0.94),
			RetroUIScript.NAVY,
			2,
			10
		)
	)
	ui_root.add_child(room_panel)

	var back := Button.new()
	back.text = "◀ MENU"
	back.position = Vector2(7, 7)
	back.size = Vector2(92, 36)
	RetroUIScript.apply_button(
		back,
		false,
		false,
		false,
		true,
		8
	)
	RetroUIScript.attach_hover_frame(back)
	back.pressed.connect(show_main_menu)
	room_panel.add_child(back)

	var room_name := RetroUIScript.label(
		current_room_name.to_upper(),
		13,
		RetroUIScript.WHITE,
		true
	)
	room_name.position = Vector2(112, 11)
	room_name.size = Vector2(190, 28)
	room_panel.add_child(room_name)

	var focus_panel := Panel.new()
	focus_panel.position = Vector2(1120, 14)
	focus_panel.size = Vector2(146, 50)
	focus_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.09, 0.29, 0.51, 0.94),
			RetroUIScript.NAVY,
			2,
			10
		)
	)
	ui_root.add_child(focus_panel)

	var focus_key := RetroUIScript.label(
		"FOCUS",
		11,
		Color("#dbeaff"),
		true
	)
	focus_key.position = Vector2(12, 5)
	focus_key.size = Vector2(76, 20)
	focus_panel.add_child(focus_key)

	coins_label = RetroUIScript.label(
		str(GameState.focus_coins),
		15,
		RetroUIScript.WHITE,
		true
	)
	coins_label.position = Vector2(88, 9)
	coins_label.size = Vector2(44, 28)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	focus_panel.add_child(coins_label)

	var prompt_panel := Panel.new()
	prompt_panel.position = Vector2(500, 650)
	prompt_panel.size = Vector2(280, 44)
	prompt_panel.visible = false
	prompt_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.92, 0.92, 0.92, 0.96),
			RetroUIScript.BLUE,
			2,
			9
		)
	)
	ui_root.add_child(prompt_panel)

	prompt_label = RetroUIScript.label(
		"E  STUDY HERE",
		12,
		RetroUIScript.INK,
		true
	)
	prompt_label.position = Vector2(12, 9)
	prompt_label.size = Vector2(256, 26)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)

	var hint := RetroUIScript.label(
		"WASD MOVE   E INTERACT   F WAVE",
		10,
		Color("#f4f7ff"),
		true
	)
	hint.position = Vector2(14, 688)
	hint.size = Vector2(350, 22)
	ui_root.add_child(hint)

	debug_label = RetroUIScript.label(
		"DEV  F3 ANCHORS  F4 COLLISION  F5 SHORT FOCUS  F6 PERFORMANCE\nFPS: --   GROUNDED: --",
		10,
		RetroUIScript.WHITE,
		true
	)
	debug_label.position = Vector2(782, 626)
	debug_label.size = Vector2(478, 74)
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	debug_label.visible = false
	ui_root.add_child(debug_label)
'''

FUNCTIONS["_open_focus_setup"] = r'''func _open_focus_setup(spot_index: int) -> void:
	if study_spots.is_empty():
		return

	spot_index = clampi(
		spot_index,
		0,
		study_spots.size() - 1
	)

	var spot = study_spots[spot_index]

	if not spot.reserve(
		"local_player",
		StudySpot.OccupantType.PLAYER
	):
		_show_toast("That seat is occupied")
		return

	pending_study_spot = spot
	_set_movement_enabled(false)

	var overlay := ColorRect.new()
	overlay.name = "FocusSetupOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.02, 0.03, 0.06, 0.38)
	ui_root.add_child(overlay)

	var window := RetroUIScript.create_window(
		overlay,
		Vector2(390, 172),
		Vector2(500, 376),
		"FOCUS SESSION",
		RetroUIScript.BLUE,
		12
	)

	var task_key := RetroUIScript.label(
		"TASK",
		11,
		RetroUIScript.INK,
		true
	)
	task_key.position = Vector2(28, 66)
	task_key.size = Vector2(90, 26)
	window.add_child(task_key)

	task_input = LineEdit.new()
	task_input.position = Vector2(118, 60)
	task_input.size = Vector2(348, 42)
	task_input.placeholder_text = "What are you working on?"
	task_input.max_length = 64
	RetroUIScript.apply_line_edit(task_input, 7)
	window.add_child(task_input)

	var duration_key := RetroUIScript.label(
		"DURATION",
		11,
		RetroUIScript.INK,
		true
	)
	duration_key.position = Vector2(28, 132)
	duration_key.size = Vector2(110, 26)
	window.add_child(duration_key)

	var duration_input := LineEdit.new()
	duration_input.position = Vector2(150, 122)
	duration_input.size = Vector2(200, 58)
	duration_input.text = _focus_seconds_to_hhmm(
		selected_duration
	)
	duration_input.placeholder_text = "00:00"
	duration_input.max_length = 5
	duration_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	duration_input.select_all_on_focus = true
	RetroUIScript.apply_line_edit(duration_input, 8)
	duration_input.add_theme_font_override(
		"font",
		RetroUIScript.mono_font()
	)
	duration_input.add_theme_font_size_override(
		"font_size",
		28
	)
	duration_input.text_changed.connect(
		_on_focus_duration_text_changed.bind(
			duration_input
		)
	)
	window.add_child(duration_input)

	var duration_hint := RetroUIScript.label(
		"HH:MM   ·   TYPE 4 DIGITS   ·   0130 = 01:30",
		10,
		RetroUIScript.MUTED,
		true
	)
	duration_hint.position = Vector2(70, 190)
	duration_hint.size = Vector2(360, 24)
	duration_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.add_child(duration_hint)

	var divider := HSeparator.new()
	divider.position = Vector2(28, 230)
	divider.size = Vector2(444, 2)
	window.add_child(divider)

	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.position = Vector2(104, 274)
	cancel.size = Vector2(132, 46)
	RetroUIScript.apply_button(
		cancel,
		false,
		false,
		false,
		false,
		8
	)
	RetroUIScript.attach_hover_frame(cancel)
	cancel.pressed.connect(_close_focus_setup)
	window.add_child(cancel)

	var start := Button.new()
	start.text = "START FOCUS"
	start.position = Vector2(258, 274)
	start.size = Vector2(160, 46)
	RetroUIScript.apply_button(
		start,
		false,
		true,
		false,
		false,
		8
	)
	RetroUIScript.attach_hover_frame(start)
	start.pressed.connect(
		_begin_focus_from_duration.bind(
			spot_index,
			duration_input
		)
	)
	window.add_child(start)

	task_input.grab_focus()
'''

FUNCTIONS["_build_focus_hud"] = r'''func _build_focus_hud(task: String) -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var room_panel := Panel.new()
	room_panel.position = Vector2(14, 14)
	room_panel.size = Vector2(230, 42)
	room_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.09, 0.29, 0.51, 0.92),
			RetroUIScript.NAVY,
			2,
			9
		)
	)
	ui_root.add_child(room_panel)

	var room_text := RetroUIScript.label(
		current_room_name.to_upper(),
		11,
		RetroUIScript.WHITE,
		true
	)
	room_text.position = Vector2(12, 8)
	room_text.size = Vector2(206, 24)
	room_panel.add_child(room_text)

	var timer := RetroUIScript.create_window(
		ui_root,
		Vector2(1038, 76),
		Vector2(224, 174),
		"FOCUS",
		RetroUIScript.BLUE,
		12
	)

	focus_time_label = RetroUIScript.label(
		_format_focus_countdown(
			selected_duration
		),
		31,
		RetroUIScript.INK,
		false,
		true
	)
	focus_time_label.position = Vector2(14, 52)
	focus_time_label.size = Vector2(196, 42)
	focus_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_child(focus_time_label)

	focus_task_label = RetroUIScript.label(
		task if not task.strip_edges().is_empty() else "Quiet focus",
		12,
		RetroUIScript.INK
	)
	focus_task_label.position = Vector2(16, 96)
	focus_task_label.size = Vector2(192, 24)
	focus_task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_task_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	timer.add_child(focus_task_label)

	focus_shot_label = RetroUIScript.label(
		"",
		1,
		Color.TRANSPARENT
	)
	focus_shot_label.visible = false
	timer.add_child(focus_shot_label)

	var pause := Button.new()
	pause.text = "PAUSE"
	pause.position = Vector2(14, 128)
	pause.size = Vector2(92, 34)
	RetroUIScript.apply_button(
		pause,
		false,
		true,
		false,
		true,
		7
	)
	RetroUIScript.attach_hover_frame(pause)
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = (
				"RESUME"
				if FocusManager.paused
				else "PAUSE"
			)
	)
	timer.add_child(pause)

	var end := Button.new()
	end.text = "END"
	end.position = Vector2(118, 128)
	end.size = Vector2(92, 34)
	RetroUIScript.apply_button(
		end,
		false,
		false,
		true,
		true,
		7
	)
	RetroUIScript.attach_hover_frame(end)
	end.pressed.connect(FocusManager.cancel_session)
	timer.add_child(end)

	var esc := RetroUIScript.label(
		"ESC  MENU",
		10,
		RetroUIScript.WHITE,
		true
	)
	esc.position = Vector2(18, 688)
	esc.size = Vector2(140, 22)
	ui_root.add_child(esc)
'''

FUNCTIONS["_open_resting_setup"] = r'''func _open_resting_setup(spot_index: int) -> void:
	if study_spots.is_empty():
		return

	spot_index = clampi(
		spot_index,
		0,
		study_spots.size() - 1
	)

	var spot = study_spots[spot_index]

	if not spot.reserve(
		"local_player",
		StudySpot.OccupantType.PLAYER
	):
		_show_toast("That lounger is occupied")
		return

	pending_study_spot = spot
	_set_movement_enabled(false)

	var overlay := ColorRect.new()
	overlay.name = "RestingSetupOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.02, 0.03, 0.06, 0.38)
	ui_root.add_child(overlay)

	var window := RetroUIScript.create_window(
		overlay,
		Vector2(420, 180),
		Vector2(440, 360),
		"BREAK TIMER",
		RetroUIScript.GREEN_DARK,
		12
	)

	var helper := RetroUIScript.label(
		"TAKE A SHORT BREAK",
		13,
		RetroUIScript.INK,
		true
	)
	helper.position = Vector2(24, 62)
	helper.size = Vector2(392, 28)
	helper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.add_child(helper)

	var durations := [
		["5 MINUTES", 300],
		["10 MINUTES", 600],
		["15 MINUTES", 900],
	]

	for i: int in range(durations.size()):
		var button := Button.new()
		button.text = durations[i][0]
		button.position = Vector2(
			88,
			112 + float(i) * 54.0
		)
		button.size = Vector2(264, 40)

		RetroUIScript.apply_button(
			button,
			i == 0,
			i == 0,
			false,
			true,
			7
		)
		RetroUIScript.attach_hover_frame(
			button,
			i == 0
		)

		var seconds := int(durations[i][1])

		button.pressed.connect(
			_begin_scrapbook_break.bind(
				seconds,
				spot_index
			)
		)

		window.add_child(button)

	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(150, 292)
	back.size = Vector2(140, 40)
	RetroUIScript.apply_button(
		back,
		false,
		false,
		false,
		true,
		7
	)
	RetroUIScript.attach_hover_frame(back)
	back.pressed.connect(_close_resting_setup)
	window.add_child(back)
'''

FUNCTIONS["_build_resting_hud"] = r'''func _build_resting_hud() -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var timer := RetroUIScript.create_window(
		ui_root,
		Vector2(1038, 76),
		Vector2(224, 166),
		"BREAK",
		RetroUIScript.GREEN_DARK,
		12
	)

	focus_time_label = RetroUIScript.label(
		_format_focus_countdown(
			resting_duration
		),
		31,
		RetroUIScript.INK,
		false,
		true
	)
	focus_time_label.position = Vector2(14, 52)
	focus_time_label.size = Vector2(196, 42)
	focus_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_child(focus_time_label)

	focus_task_label = RetroUIScript.label(
		"REST / RESET",
		10,
		RetroUIScript.MUTED,
		true
	)
	focus_task_label.position = Vector2(16, 96)
	focus_task_label.size = Vector2(192, 22)
	focus_task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_child(focus_task_label)

	focus_shot_label = RetroUIScript.label(
		"",
		1,
		Color.TRANSPARENT
	)
	focus_shot_label.visible = false
	timer.add_child(focus_shot_label)

	var pause := Button.new()
	pause.text = "PAUSE"
	pause.position = Vector2(14, 124)
	pause.size = Vector2(92, 32)
	RetroUIScript.apply_button(
		pause,
		false,
		true,
		false,
		true,
		7
	)
	RetroUIScript.attach_hover_frame(pause)
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = (
				"RESUME"
				if FocusManager.paused
				else "PAUSE"
			)
	)
	timer.add_child(pause)

	var end := Button.new()
	end.text = "END"
	end.position = Vector2(118, 124)
	end.size = Vector2(92, 32)
	RetroUIScript.apply_button(
		end,
		false,
		false,
		true,
		true,
		7
	)
	RetroUIScript.attach_hover_frame(end)
	end.pressed.connect(FocusManager.cancel_session)
	timer.add_child(end)
'''

FUNCTIONS["_show_completion"] = r'''func _show_completion(
	minutes: int,
	reward: int
) -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.02, 0.03, 0.06, 0.42)
	ui_root.add_child(overlay)

	var window := RetroUIScript.create_window(
		overlay,
		Vector2(405, 190),
		Vector2(470, 330),
		"SESSION RESULTS",
		RetroUIScript.GREEN_DARK,
		12
	)

	var complete := RetroUIScript.label(
		"COMPLETE",
		17,
		RetroUIScript.INK,
		true
	)
	complete.position = Vector2(24, 60)
	complete.size = Vector2(190, 34)
	window.add_child(complete)

	var reward_panel := Panel.new()
	reward_panel.position = Vector2(278, 54)
	reward_panel.size = Vector2(166, 44)
	reward_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#a7d5b0"),
			RetroUIScript.GREEN_DARK,
			2,
			8
		)
	)
	window.add_child(reward_panel)

	var reward_label := RetroUIScript.label(
		"+%d FOCUS" % reward,
		13,
		RetroUIScript.INK,
		true
	)
	reward_label.position = Vector2(8, 8)
	reward_label.size = Vector2(150, 26)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_panel.add_child(reward_label)

	var rows := [
		["TASK", FocusManager.task],
		[
			"TIME",
			_focus_seconds_to_hhmm(
				maxi(
					60,
					minutes * 60
				)
			)
		],
		["ROOM", current_room_name.to_upper()],
	]

	for i: int in range(rows.size()):
		var row := Panel.new()
		row.position = Vector2(
			24,
			120 + float(i) * 42.0
		)
		row.size = Vector2(420, 36)
		row.add_theme_stylebox_override(
			"panel",
			RetroUIScript.panel_style(
				(
					RetroUIScript.PANEL_ALT
					if i % 2 == 0
					else RetroUIScript.PANEL_DARK
				),
				Color("#9a9a9a"),
				1,
				5
			)
		)
		window.add_child(row)

		var key_label := RetroUIScript.label(
			rows[i][0],
			10,
			RetroUIScript.INK,
			true
		)
		key_label.position = Vector2(10, 7)
		key_label.size = Vector2(92, 22)
		row.add_child(key_label)

		var value_label := RetroUIScript.label(
			str(rows[i][1]),
			12,
			RetroUIScript.INK
		)
		value_label.position = Vector2(112, 6)
		value_label.size = Vector2(294, 24)
		value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(value_label)

	var again := Button.new()
	again.text = "STUDY AGAIN"
	again.position = Vector2(58, 262)
	again.size = Vector2(160, 42)
	RetroUIScript.apply_button(
		again,
		false,
		true,
		false,
		true,
		8
	)
	RetroUIScript.attach_hover_frame(again)
	again.pressed.connect(
		build_room.bind(
			GameState.selected_room
		)
	)
	window.add_child(again)

	var places := Button.new()
	places.text = "PLACES"
	places.position = Vector2(252, 262)
	places.size = Vector2(160, 42)
	RetroUIScript.apply_button(
		places,
		false,
		false,
		false,
		true,
		8
	)
	RetroUIScript.attach_hover_frame(places)
	places.pressed.connect(show_main_menu)
	window.add_child(places)
'''

FUNCTIONS["_show_resting_completion"] = r'''func _show_resting_completion(
	minutes: int
) -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.02, 0.03, 0.06, 0.40)
	ui_root.add_child(overlay)

	var window := RetroUIScript.create_window(
		overlay,
		Vector2(430, 220),
		Vector2(420, 280),
		"BREAK RESULTS",
		RetroUIScript.GREEN_DARK,
		12
	)

	var title := RetroUIScript.label(
		"READY TO CONTINUE",
		16,
		RetroUIScript.INK,
		true
	)
	title.position = Vector2(24, 70)
	title.size = Vector2(372, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.add_child(title)

	var row := Panel.new()
	row.position = Vector2(54, 122)
	row.size = Vector2(312, 42)
	row.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			RetroUIScript.PANEL_ALT,
			Color("#9a9a9a"),
			1,
			6
		)
	)
	window.add_child(row)

	var detail := RetroUIScript.label(
		"BREAK TIME     %02d:%02d"
		% [
			minutes / 60,
			minutes % 60,
		],
		11,
		RetroUIScript.INK,
		true
	)
	detail.position = Vector2(12, 9)
	detail.size = Vector2(288, 24)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(detail)

	var return_button := Button.new()
	return_button.text = "BACK TO WORK"
	return_button.position = Vector2(110, 202)
	return_button.size = Vector2(200, 42)
	RetroUIScript.apply_button(
		return_button,
		false,
		true,
		false,
		true,
		8
	)
	RetroUIScript.attach_hover_frame(return_button)
	return_button.pressed.connect(
		build_room.bind(
			GameState.selected_room
		)
	)
	window.add_child(return_button)
'''

OPTIONAL_TICK = r'''func _on_focus_tick(
	remaining_seconds: int
) -> void:
	if is_instance_valid(focus_time_label):
		focus_time_label.text = _format_focus_countdown(
			remaining_seconds
		)
'''

HELPERS = r'''func _focus_duration_digits(
	text_value: String
) -> String:
	var digits := ""

	for i: int in range(
		text_value.length()
	):
		var codepoint := text_value.unicode_at(i)

		if codepoint >= 48 and codepoint <= 57:
			digits += text_value.substr(
				i,
				1
			)

	return digits


func _focus_seconds_to_hhmm(
	seconds: int
) -> String:
	var total_minutes := maxi(
		0,
		ceili(
			float(seconds)
			/ 60.0
		)
	)

	var hours := total_minutes / 60
	var minutes := total_minutes % 60

	return "%02d:%02d" % [
		hours,
		minutes,
	]


func _format_focus_countdown(
	seconds: int
) -> String:
	var safe_seconds := maxi(
		0,
		seconds
	)

	var hours := safe_seconds / 3600
	var minutes := (
		safe_seconds % 3600
	) / 60
	var secs := safe_seconds % 60

	if hours > 0:
		return "%02d:%02d:%02d" % [
			hours,
			minutes,
			secs,
		]

	return "%02d:%02d" % [
		minutes,
		secs,
	]


func _on_focus_duration_text_changed(
	new_text: String,
	input: LineEdit
) -> void:
	var digits := _focus_duration_digits(
		new_text
	)

	if digits.length() > 4:
		digits = digits.substr(
			0,
			4
		)

	var formatted := digits

	if digits.length() > 2:
		formatted = (
			digits.substr(
				0,
				2
			)
			+ ":"
			+ digits.substr(
				2
			)
		)

	if input.text != formatted:
		input.text = formatted
		input.caret_column = formatted.length()


func _parse_focus_duration_text(
	text_value: String
) -> int:
	var digits := _focus_duration_digits(
		text_value
	)

	if digits.is_empty():
		return -1

	var hours := 0
	var minutes := 0

	if digits.length() <= 2:
		minutes = int(digits)
	elif digits.length() == 3:
		hours = int(
			digits.substr(
				0,
				1
			)
		)
		minutes = int(
			digits.substr(
				1,
				2
			)
		)
	else:
		hours = int(
			digits.substr(
				0,
				2
			)
		)
		minutes = int(
			digits.substr(
				2,
				2
			)
		)

	if minutes > 59:
		return -1

	var seconds := (
		hours * 3600
		+ minutes * 60
	)

	if seconds < 60 or seconds > 10800:
		return -1

	return seconds


func _begin_focus_from_duration(
	spot_index: int,
	duration_input: LineEdit
) -> void:
	var seconds := _parse_focus_duration_text(
		duration_input.text
	)

	if seconds < 0:
		_show_toast(
			"Enter 00:01 to 03:00"
		)
		duration_input.grab_focus()
		duration_input.select_all()
		return

	selected_duration = seconds
	_begin_focus(spot_index)
'''


def backup(path: Path, timestamp: str) -> None:
    BACKUP_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    shutil.copy2(
        path,
        BACKUP_DIR
        / (
            path.stem
            + "_before_compact_focus_ui_"
            + timestamp
            + path.suffix
            + ".backup.txt"
        ),
    )


def replace_function(
    text: str,
    function_name: str,
    replacement: str,
    required: bool = True,
) -> str:
    marker = f"func {function_name}("
    start = text.find(marker)

    if start < 0:
        if required:
            raise RuntimeError(
                f"Could not find {function_name}() in main.gd"
            )
        return text

    next_func = text.find(
        "\nfunc ",
        start + len(marker),
    )

    end = len(text) if next_func < 0 else next_func + 1

    return (
        text[:start]
        + replacement.rstrip()
        + "\n\n"
        + text[end:]
    )


def insert_helpers(text: str) -> str:
    if "func _focus_duration_digits(" in text:
        return text

    anchor = "\nfunc _begin_focus("
    index = text.find(anchor)

    if index < 0:
        raise RuntimeError(
            "Could not locate _begin_focus() for helper insertion."
        )

    return (
        text[:index]
        + "\n"
        + HELPERS.rstrip()
        + "\n\n"
        + text[index + 1 :]
    )


def main() -> None:
    if not MAIN_PATH.is_file():
        raise FileNotFoundError(MAIN_PATH)

    if not (ROOT / "scripts" / "ui" / "retro_ui.gd").is_file():
        raise FileNotFoundError(
            ROOT / "scripts" / "ui" / "retro_ui.gd"
        )

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    backup(MAIN_PATH, timestamp)

    text = MAIN_PATH.read_text(encoding="utf-8")

    if "RetroUIScript" not in text:
        raise RuntimeError(
            "The retro database UI must be applied before this patch."
        )

    text = insert_helpers(text)

    for function_name, replacement in FUNCTIONS.items():
        text = replace_function(
            text,
            function_name,
            replacement,
            True,
        )

    MAIN_PATH.write_text(
        text,
        encoding="utf-8",
    )

    print("")
    print("# STUDYTOWN COMPACT FOCUS UI V2")
    print("")
    print("Room HUD:        compact floating modules")
    print("Focus duration:  direct HH:MM entry")
    print("Focus setup:     smaller + rounded")
    print("Focus timer:     compact + rounded")
    print("Completion:      compact result rows + rounded")
    print("Break UI:        compact + rounded")
    print(f"Backup:          {BACKUP_DIR}")
    print("")
    print("DONE")
    print("")


if __name__ == "__main__":
    main()
