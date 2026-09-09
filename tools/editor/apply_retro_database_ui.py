#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd()
MAIN_PATH = ROOT / "scripts" / "core" / "main.gd"
BACKUP_DIR = (
    ROOT
    / "assets"
    / "dev_local"
    / "backups"
    / "retro_ui"
)

RETRO_PRELOADS = (
    'const RetroUIScript := preload("res://scripts/ui/retro_ui.gd")\n'
    'const RetroCharacterPreviewScript := preload("res://scripts/ui/retro_character_preview.gd")\n'
)

FUNCTIONS: dict[str, str] = {}

FUNCTIONS["_build_menu_world"] = r'''func _build_menu_world() -> void:
	# The new menu is intentionally UI-first, like a retro game/database screen.
	# Keep a tiny 3D world alive only so the project always has a valid camera.
	_add_environment(
		Color("#324a7d"),
		Color("#dce5f2"),
		0.48
	)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 6.0)
	camera.current = true
	world_root.add_child(camera)
'''

FUNCTIONS["_build_menu_ui"] = r'''func _build_menu_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = RetroUIScript.BLUE_LIGHT
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(background)

	var top_bar := Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1280, 58)
	top_bar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			RetroUIScript.BLUE,
			RetroUIScript.NAVY,
			3
		)
	)
	ui_root.add_child(top_bar)

	var logo := RetroUIScript.label(
		"STUDYTOWN",
		26,
		RetroUIScript.WHITE,
		true
	)
	logo.position = Vector2(16, 8)
	logo.size = Vector2(260, 40)
	top_bar.add_child(logo)

	var nav := RetroUIScript.label(
		"ROOMS    STATS    HELP",
		14,
		RetroUIScript.WHITE,
		true
	)
	nav.position = Vector2(350, 13)
	nav.size = Vector2(420, 32)
	top_bar.add_child(nav)

	var focus_counter := RetroUIScript.label(
		"FOCUS  %d" % GameState.focus_coins,
		14,
		RetroUIScript.WHITE,
		true
	)
	focus_counter.position = Vector2(1070, 13)
	focus_counter.size = Vector2(190, 32)
	focus_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(focus_counter)

	var sidebar := Panel.new()
	sidebar.position = Vector2(0, 58)
	sidebar.size = Vector2(176, 662)
	sidebar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#6575cf"),
			RetroUIScript.NAVY,
			3
		)
	)
	ui_root.add_child(sidebar)

	var side_header := Panel.new()
	side_header.position = Vector2(4, 4)
	side_header.size = Vector2(168, 32)
	side_header.add_theme_stylebox_override(
		"panel",
		RetroUIScript.header_style(
			RetroUIScript.NAVY
		)
	)
	sidebar.add_child(side_header)

	var side_title := RetroUIScript.label(
		"MENU",
		12,
		RetroUIScript.WHITE,
		true
	)
	side_title.position = Vector2(8, 4)
	side_title.size = Vector2(150, 24)
	side_header.add_child(side_title)

	var menu_entries := [
		["ROOMS", ""],
		["STUDY BUDDY", "_open_character_selection"],
		["SETTINGS", "_open_scrapbook_settings"],
		["CREDITS", "_open_scrapbook_credits"],
	]

	for i: int in range(menu_entries.size()):
		var button := Button.new()
		button.text = menu_entries[i][0]
		button.position = Vector2(
			10,
			50 + float(i) * 48.0
		)
		button.size = Vector2(156, 38)

		RetroUIScript.apply_sidebar_button(
			button,
			i == 0
		)
		RetroUIScript.attach_hover_frame(
			button,
			i == 0
		)

		var method_name := str(
			menu_entries[i][1]
		)

		if not method_name.is_empty():
			button.pressed.connect(
				Callable(
					self,
					method_name
				)
			)

		sidebar.add_child(button)

	var quit := Button.new()
	quit.text = "QUIT"
	quit.position = Vector2(10, 606)
	quit.size = Vector2(156, 38)
	RetroUIScript.apply_button(
		quit,
		false,
		false,
		true,
		true
	)
	RetroUIScript.attach_hover_frame(quit)
	quit.pressed.connect(
		func():
			get_tree().quit()
	)
	sidebar.add_child(quit)

	var rooms_window := RetroUIScript.create_window(
		ui_root,
		Vector2(188, 72),
		Vector2(836, 338),
		"CHOOSE A PLACE"
	)

	var room_ids := [
		"library",
		"garden",
		"train",
	]

	var room_names := [
		"LIBRARY",
		"GARDEN",
		"TRAIN",
	]

	var room_subtitles := [
		"quiet shelves / study desks",
		"open air / cafe / water",
		"moving scenery / compartments",
	]

	for i: int in range(3):
		var card := Button.new()
		card.text = ""
		card.position = Vector2(
			12 + float(i) * 270.0,
			52
		)
		card.size = Vector2(252, 268)
		card.focus_mode = Control.FOCUS_ALL

		card.add_theme_stylebox_override(
			"normal",
			RetroUIScript.panel_style(
				Color("#d3d3d3"),
				RetroUIScript.OUTLINE,
				3
			)
		)

		card.add_theme_stylebox_override(
			"hover",
			RetroUIScript.panel_style(
				Color("#e7e7e7"),
				RetroUIScript.WHITE,
				3
			)
		)

		var header := Panel.new()
		header.position = Vector2(5, 5)
		header.size = Vector2(242, 34)
		header.add_theme_stylebox_override(
			"panel",
			RetroUIScript.header_style(
				RetroUIScript.BLUE_CARD
			)
		)
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(header)

		var card_title := RetroUIScript.label(
			room_names[i],
			12,
			RetroUIScript.WHITE,
			true
		)
		card_title.position = Vector2(8, 5)
		card_title.size = Vector2(226, 24)
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(card_title)

		var preview := RoomPreviewScript.make_preview(
			room_ids[i],
			Vector2i(230, 162)
		)
		preview.position = Vector2(11, 46)
		preview.size = Vector2(230, 162)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(preview)

		var subtitle := RetroUIScript.label(
			room_subtitles[i],
			12,
			RetroUIScript.INK
		)
		subtitle.position = Vector2(12, 220)
		subtitle.size = Vector2(228, 34)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(subtitle)

		RetroUIScript.attach_hover_frame(card)

		card.pressed.connect(
			_enter_room.bind(i)
		)

		rooms_window.add_child(card)

	var info_window := RetroUIScript.create_window(
		ui_root,
		Vector2(188, 422),
		Vector2(836, 280),
		"GAME INFO"
	)

	var labels := [
		["MODE", "STUDY / FOCUS"],
		["PLACES", "LIBRARY / GARDEN / TRAIN"],
		["FOCUS POINTS", str(GameState.focus_coins)],
		["CONTROLS", "WASD MOVE   E INTERACT   F WAVE"],
	]

	for i: int in range(labels.size()):
		var row := Panel.new()
		row.position = Vector2(
			12,
			52 + float(i) * 49.0
		)
		row.size = Vector2(812, 42)
		row.add_theme_stylebox_override(
			"panel",
			RetroUIScript.panel_style(
				(
					RetroUIScript.PANEL_ALT
					if i % 2 == 0
					else RetroUIScript.PANEL_DARK
				),
				Color("#9a9a9a"),
				1
			)
		)
		info_window.add_child(row)

		var key_label := RetroUIScript.label(
			labels[i][0],
			12,
			RetroUIScript.INK,
			true
		)
		key_label.position = Vector2(8, 8)
		key_label.size = Vector2(220, 26)
		row.add_child(key_label)

		var value_label := RetroUIScript.label(
			labels[i][1],
			13,
			RetroUIScript.INK
		)
		value_label.position = Vector2(240, 8)
		value_label.size = Vector2(550, 26)
		row.add_child(value_label)

	var buddy_window := RetroUIScript.create_window(
		ui_root,
		Vector2(1038, 72),
		Vector2(224, 630),
		"STUDY BUDDY"
	)

	var selected_index := clampi(
		GameState.selected_character,
		0,
		maxi(
			character_loader.profiles.size() - 1,
			0
		)
	)

	var preview_panel := Panel.new()
	preview_panel.position = Vector2(10, 50)
	preview_panel.size = Vector2(204, 286)
	preview_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#7784d1"),
			RetroUIScript.OUTLINE,
			3
		)
	)
	buddy_window.add_child(preview_panel)

	var buddy_preview := RetroCharacterPreviewScript.make_character_preview(
		character_loader,
		selected_index,
		Vector2i(192, 274),
		false
	)
	buddy_preview.position = Vector2(6, 6)
	buddy_preview.size = Vector2(192, 274)
	preview_panel.add_child(buddy_preview)

	var profile: CharacterProfile = character_loader.get_profile(
		selected_index
	)

	var name_bar := Panel.new()
	name_bar.position = Vector2(10, 350)
	name_bar.size = Vector2(204, 38)
	name_bar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.header_style(
			RetroUIScript.BLUE_CARD
		)
	)
	buddy_window.add_child(name_bar)

	var buddy_name := RetroUIScript.label(
		profile.display_name.to_upper(),
		12,
		RetroUIScript.WHITE,
		true
	)
	buddy_name.position = Vector2(8, 7)
	buddy_name.size = Vector2(188, 24)
	buddy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_bar.add_child(buddy_name)

	var species := RetroUIScript.label(
		"SPECIES: %s" % profile.species.to_upper(),
		12,
		RetroUIScript.INK
	)
	species.position = Vector2(16, 404)
	species.size = Vector2(190, 26)
	buddy_window.add_child(species)

	var change := Button.new()
	change.text = "CHANGE BUDDY"
	change.position = Vector2(16, 448)
	change.size = Vector2(192, 44)
	RetroUIScript.apply_button(change)
	RetroUIScript.attach_hover_frame(change)
	change.pressed.connect(
		_open_character_selection
	)
	buddy_window.add_child(change)

	var buddy_hint := RetroUIScript.label(
		"Your selected buddy appears\nin every StudyTown room.",
		12,
		RetroUIScript.MUTED
	)
	buddy_hint.position = Vector2(16, 518)
	buddy_hint.size = Vector2(190, 62)
	buddy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buddy_window.add_child(buddy_hint)
'''

FUNCTIONS["_build_room_ui"] = r'''func _build_room_ui() -> void:
	var top_bar := Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1280, 46)
	top_bar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.09, 0.29, 0.51, 0.94),
			RetroUIScript.NAVY,
			3
		)
	)
	ui_root.add_child(top_bar)

	var back := Button.new()
	back.text = "◀ MENU"
	back.position = Vector2(8, 7)
	back.size = Vector2(104, 32)
	RetroUIScript.apply_button(
		back,
		false,
		false,
		false,
		true
	)
	RetroUIScript.attach_hover_frame(back)
	back.pressed.connect(show_main_menu)
	top_bar.add_child(back)

	var room_name := RetroUIScript.label(
		current_room_name.to_upper(),
		14,
		RetroUIScript.WHITE,
		true
	)
	room_name.position = Vector2(132, 10)
	room_name.size = Vector2(430, 28)
	top_bar.add_child(room_name)

	coins_label = RetroUIScript.label(
		"FOCUS  %d" % GameState.focus_coins,
		13,
		RetroUIScript.WHITE,
		true
	)
	coins_label.position = Vector2(1060, 10)
	coins_label.size = Vector2(202, 28)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(coins_label)

	var prompt_panel := Panel.new()
	prompt_panel.position = Vector2(488, 646)
	prompt_panel.size = Vector2(304, 48)
	prompt_panel.visible = false
	prompt_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.91, 0.91, 0.91, 0.96),
			RetroUIScript.BLUE,
			3
		)
	)
	ui_root.add_child(prompt_panel)

	prompt_label = RetroUIScript.label(
		"Press E to study here",
		13,
		RetroUIScript.INK,
		true
	)
	prompt_label.position = Vector2(12, 10)
	prompt_label.size = Vector2(280, 28)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)

	var hint := RetroUIScript.label(
		"WASD MOVE   E INTERACT   F WAVE",
		11,
		Color("#f4f7ff"),
		true
	)
	hint.position = Vector2(14, 684)
	hint.size = Vector2(360, 24)
	ui_root.add_child(hint)

	debug_label = RetroUIScript.label(
		"DEV  F3 ANCHORS  F4 COLLISION  F5 SHORT FOCUS  F6 PERFORMANCE\nFPS: --   GROUNDED: --",
		11,
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
	overlay.color = Color(0.02, 0.03, 0.06, 0.68)
	ui_root.add_child(overlay)

	var window := RetroUIScript.create_window(
		overlay,
		Vector2(330, 120),
		Vector2(620, 480),
		"FOCUS SESSION"
	)

	var task_key := RetroUIScript.label(
		"TASK",
		12,
		RetroUIScript.INK,
		true
	)
	task_key.position = Vector2(24, 68)
	task_key.size = Vector2(130, 28)
	window.add_child(task_key)

	task_input = LineEdit.new()
	task_input.position = Vector2(154, 64)
	task_input.size = Vector2(430, 40)
	task_input.placeholder_text = "What are you working on?"
	task_input.max_length = 64
	RetroUIScript.apply_line_edit(task_input)
	window.add_child(task_input)

	var duration_key := RetroUIScript.label(
		"DURATION",
		12,
		RetroUIScript.INK,
		true
	)
	duration_key.position = Vector2(24, 128)
	duration_key.size = Vector2(130, 28)
	window.add_child(duration_key)

	var presets := HBoxContainer.new()
	presets.position = Vector2(154, 120)
	presets.size = Vector2(430, 44)
	presets.add_theme_constant_override(
		"separation",
		8
	)
	window.add_child(presets)

	for data in [
		["25 MIN", 1500],
		["50 MIN", 3000],
		["90 MIN", 5400],
	]:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(94, 40)
		button.set_meta("seconds", data[1])

		var chosen := int(data[1]) == selected_duration

		RetroUIScript.apply_button(
			button,
			chosen,
			chosen,
			false,
			true
		)
		RetroUIScript.attach_hover_frame(
			button,
			chosen
		)

		button.pressed.connect(
			_choose_duration.bind(
				int(data[1]),
				presets
			)
		)

		presets.add_child(button)

	var custom := SpinBox.new()
	custom.min_value = 1
	custom.max_value = 180
	custom.value = clampi(
		selected_duration / 60,
		1,
		180
	)
	custom.suffix = " min"
	custom.custom_minimum_size = Vector2(112, 40)
	RetroUIScript.apply_spin_box(custom)
	custom.value_changed.connect(
		func(value: float):
			selected_duration = int(value) * 60
	)
	presets.add_child(custom)

	var info := Panel.new()
	info.position = Vector2(24, 200)
	info.size = Vector2(560, 140)
	info.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			RetroUIScript.PANEL_ALT,
			Color("#9a9a9a"),
			1
		)
	)
	window.add_child(info)

	var info_title := RetroUIScript.label(
		"SESSION INFO",
		11,
		RetroUIScript.BLUE,
		true
	)
	info_title.position = Vector2(12, 10)
	info_title.size = Vector2(180, 24)
	info.add_child(info_title)

	var info_text := RetroUIScript.label(
		"Focus mode locks movement and switches to study cameras.\nPause or end the session at any time from the timer panel.",
		13,
		RetroUIScript.INK
	)
	info_text.position = Vector2(12, 44)
	info_text.size = Vector2(530, 74)
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(info_text)

	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.position = Vector2(280, 386)
	cancel.size = Vector2(130, 46)
	RetroUIScript.apply_button(cancel)
	RetroUIScript.attach_hover_frame(cancel)
	cancel.pressed.connect(_close_focus_setup)
	window.add_child(cancel)

	var start := Button.new()
	start.text = "START FOCUS"
	start.position = Vector2(428, 386)
	start.size = Vector2(156, 46)
	RetroUIScript.apply_button(
		start,
		false,
		true
	)
	RetroUIScript.attach_hover_frame(start)
	start.pressed.connect(
		_begin_focus.bind(spot_index)
	)
	window.add_child(start)

	task_input.grab_focus()
'''

FUNCTIONS["_choose_duration"] = r'''func _choose_duration(
	seconds: int,
	grid: Container
) -> void:
	selected_duration = seconds

	for child: Node in grid.get_children():
		if child is Button:
			var chosen := (
				int(
					child.get_meta(
						"seconds",
						0
					)
				) == seconds
			)

			RetroUIScript.apply_button(
				child as Button,
				chosen,
				chosen,
				false,
				true
			)
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
	overlay.color = Color(0.02, 0.03, 0.06, 0.68)
	ui_root.add_child(overlay)

	var window := RetroUIScript.create_window(
		overlay,
		Vector2(390, 150),
		Vector2(500, 420),
		"BREAK TIMER",
		RetroUIScript.GREEN_DARK
	)

	var helper := RetroUIScript.label(
		"TAKE A SHORT BREAK",
		14,
		RetroUIScript.INK,
		true
	)
	helper.position = Vector2(28, 64)
	helper.size = Vector2(440, 30)
	window.add_child(helper)

	var sub := RetroUIScript.label(
		"Rest, stretch, reset, then return to your study spot.",
		13,
		RetroUIScript.MUTED
	)
	sub.position = Vector2(28, 100)
	sub.size = Vector2(440, 34)
	window.add_child(sub)

	var durations := [
		["5 MINUTES", 300],
		["10 MINUTES", 600],
		["15 MINUTES", 900],
	]

	for i: int in range(durations.size()):
		var button := Button.new()
		button.text = durations[i][0]
		button.position = Vector2(
			70,
			158 + float(i) * 58.0
		)
		button.size = Vector2(360, 44)

		RetroUIScript.apply_button(
			button,
			i == 0,
			i == 0
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
	back.text = "BACK TO ROOM"
	back.position = Vector2(170, 344)
	back.size = Vector2(160, 42)
	RetroUIScript.apply_button(back)
	RetroUIScript.attach_hover_frame(back)
	back.pressed.connect(_close_resting_setup)
	window.add_child(back)
'''

FUNCTIONS["_choose_resting_duration"] = r'''func _choose_resting_duration(
	seconds: int,
	grid: GridContainer
) -> void:
	resting_duration = seconds

	for child: Node in grid.get_children():
		if child is Button:
			var selected := (
				int(
					child.get_meta(
						"seconds",
						0
					)
				) == seconds
			)

			RetroUIScript.apply_button(
				child as Button,
				selected,
				selected,
				false,
				true
			)
'''

FUNCTIONS["_build_focus_hud"] = r'''func _build_focus_hud(task: String) -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var room_bar := Panel.new()
	room_bar.position = Vector2(14, 14)
	room_bar.size = Vector2(340, 46)
	room_bar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.09, 0.29, 0.51, 0.94),
			RetroUIScript.NAVY,
			3
		)
	)
	ui_root.add_child(room_bar)

	var room_text := RetroUIScript.label(
		current_room_name.to_upper(),
		13,
		RetroUIScript.WHITE,
		true
	)
	room_text.position = Vector2(12, 10)
	room_text.size = Vector2(310, 26)
	room_bar.add_child(room_text)

	var timer := RetroUIScript.create_window(
		ui_root,
		Vector2(984, 470),
		Vector2(278, 220),
		"FOCUS SESSION"
	)

	focus_time_label = RetroUIScript.label(
		"%02d:%02d" % [
			selected_duration / 60,
			selected_duration % 60,
		],
		34,
		RetroUIScript.INK,
		false,
		true
	)
	focus_time_label.position = Vector2(18, 58)
	focus_time_label.size = Vector2(242, 48)
	focus_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_child(focus_time_label)

	focus_task_label = RetroUIScript.label(
		task if not task.strip_edges().is_empty() else "Quiet focus",
		13,
		RetroUIScript.INK
	)
	focus_task_label.position = Vector2(18, 110)
	focus_task_label.size = Vector2(242, 28)
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
	pause.position = Vector2(18, 158)
	pause.size = Vector2(112, 42)
	RetroUIScript.apply_button(
		pause,
		false,
		true
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
	end.position = Vector2(148, 158)
	end.size = Vector2(112, 42)
	RetroUIScript.apply_button(
		end,
		false,
		false,
		true
	)
	RetroUIScript.attach_hover_frame(end)
	end.pressed.connect(FocusManager.cancel_session)
	timer.add_child(end)

	var esc := RetroUIScript.label(
		"ESC  MENU",
		11,
		RetroUIScript.WHITE,
		true
	)
	esc.position = Vector2(18, 686)
	esc.size = Vector2(140, 24)
	ui_root.add_child(esc)
'''

FUNCTIONS["_build_resting_hud"] = r'''func _build_resting_hud() -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var timer := RetroUIScript.create_window(
		ui_root,
		Vector2(984, 470),
		Vector2(278, 220),
		"BREAK TIMER",
		RetroUIScript.GREEN_DARK
	)

	focus_time_label = RetroUIScript.label(
		"%02d:%02d" % [
			resting_duration / 60,
			resting_duration % 60,
		],
		34,
		RetroUIScript.INK,
		false,
		true
	)
	focus_time_label.position = Vector2(18, 58)
	focus_time_label.size = Vector2(242, 48)
	focus_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_child(focus_time_label)

	focus_task_label = RetroUIScript.label(
		"REST / STRETCH / RESET",
		12,
		RetroUIScript.MUTED,
		true
	)
	focus_task_label.position = Vector2(18, 112)
	focus_task_label.size = Vector2(242, 28)
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
	pause.position = Vector2(18, 158)
	pause.size = Vector2(112, 42)
	RetroUIScript.apply_button(
		pause,
		false,
		true
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
	end.position = Vector2(148, 158)
	end.size = Vector2(112, 42)
	RetroUIScript.apply_button(
		end,
		false,
		false,
		true
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
	overlay.color = Color(0.02, 0.03, 0.06, 0.70)
	ui_root.add_child(overlay)

	var window := RetroUIScript.create_window(
		overlay,
		Vector2(380, 170),
		Vector2(520, 390),
		"SESSION COMPLETE",
		RetroUIScript.GREEN_DARK
	)

	var result := RetroUIScript.label(
		"FOCUS COMPLETE",
		22,
		RetroUIScript.INK,
		true
	)
	result.position = Vector2(24, 62)
	result.size = Vector2(470, 34)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.add_child(result)

	var reward_row := Panel.new()
	reward_row.position = Vector2(56, 116)
	reward_row.size = Vector2(408, 66)
	reward_row.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#a7d5b0"),
			RetroUIScript.GREEN_DARK,
			2
		)
	)
	window.add_child(reward_row)

	var reward_label := RetroUIScript.label(
		"+%d FOCUS" % reward,
		20,
		RetroUIScript.INK,
		true
	)
	reward_label.position = Vector2(12, 17)
	reward_label.size = Vector2(384, 32)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_row.add_child(reward_label)

	var task_row := RetroUIScript.label(
		"TASK: %s\nTIME: %d MINUTES"
		% [
			FocusManager.task,
			minutes,
		],
		13,
		RetroUIScript.INK
	)
	task_row.position = Vector2(76, 210)
	task_row.size = Vector2(370, 66)
	task_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.add_child(task_row)

	var again := Button.new()
	again.text = "STUDY AGAIN"
	again.position = Vector2(72, 308)
	again.size = Vector2(174, 46)
	RetroUIScript.apply_button(
		again,
		false,
		true
	)
	RetroUIScript.attach_hover_frame(again)
	again.pressed.connect(
		build_room.bind(
			GameState.selected_room
		)
	)
	window.add_child(again)

	var places := Button.new()
	places.text = "BACK TO PLACES"
	places.position = Vector2(272, 308)
	places.size = Vector2(176, 46)
	RetroUIScript.apply_button(places)
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
	overlay.color = Color(0.02, 0.03, 0.06, 0.70)
	ui_root.add_child(overlay)

	var window := RetroUIScript.create_window(
		overlay,
		Vector2(420, 205),
		Vector2(440, 320),
		"BREAK COMPLETE",
		RetroUIScript.GREEN_DARK
	)

	var title := RetroUIScript.label(
		"READY TO CONTINUE",
		20,
		RetroUIScript.INK,
		true
	)
	title.position = Vector2(24, 72)
	title.size = Vector2(392, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.add_child(title)

	var detail := RetroUIScript.label(
		"%d MINUTES RESTING" % minutes,
		13,
		RetroUIScript.MUTED,
		true
	)
	detail.position = Vector2(24, 126)
	detail.size = Vector2(392, 30)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.add_child(detail)

	var return_button := Button.new()
	return_button.text = "BACK TO WORK"
	return_button.position = Vector2(120, 214)
	return_button.size = Vector2(200, 48)
	RetroUIScript.apply_button(
		return_button,
		false,
		true
	)
	RetroUIScript.attach_hover_frame(return_button)
	return_button.pressed.connect(
		build_room.bind(
			GameState.selected_room
		)
	)
	window.add_child(return_button)
'''

FUNCTIONS["_open_scrapbook_settings"] = r'''func _open_scrapbook_settings() -> void:
	_show_scrapbook_note(
		"SETTINGS",
		"DISPLAY  Retro database UI\nCONTROLS  WASD / E / F / ESC\nFOCUS     Timer supports pause and resume\n\nMore settings can be connected here later."
	)
'''

FUNCTIONS["_open_scrapbook_credits"] = r'''func _open_scrapbook_credits() -> void:
	_show_scrapbook_note(
		"CREDITS",
		"STUDYTOWN\nBuilt with Godot.\n\nRooms, characters, focus timers and multiplayer systems remain unchanged by this UI pass."
	)
'''

FUNCTIONS["_show_scrapbook_note"] = r'''func _show_scrapbook_note(
	title_text: String,
	body_text: String
) -> void:
	var overlay := ColorRect.new()
	overlay.name = "RetroInfoOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.02, 0.03, 0.06, 0.72)
	ui_root.add_child(overlay)

	var window := RetroUIScript.create_window(
		overlay,
		Vector2(390, 180),
		Vector2(500, 360),
		title_text
	)

	var body := RetroUIScript.label(
		body_text,
		14,
		RetroUIScript.INK
	)
	body.position = Vector2(28, 70)
	body.size = Vector2(444, 190)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window.add_child(body)

	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(170, 286)
	close.size = Vector2(160, 44)
	RetroUIScript.apply_button(close)
	RetroUIScript.attach_hover_frame(close)
	close.pressed.connect(
		func():
			overlay.queue_free()
	)
	window.add_child(close)
'''


def backup(path: Path, timestamp: str) -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    shutil.copy2(
        path,
        BACKUP_DIR
        / (
            path.stem
            + "_before_retro_ui_"
            + timestamp
            + path.suffix
            + ".backup.txt"
        ),
    )


def replace_function(
    text: str,
    function_name: str,
    replacement: str,
) -> str:
    marker = f"func {function_name}("
    start = text.find(marker)

    if start < 0:
        raise RuntimeError(
            f"Could not find {function_name}() in scripts/core/main.gd"
        )

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


def replace_preloads(text: str) -> str:
    text = re.sub(
        r'const CharacterSelectionScreenScript := preload\(\s*'
        r'"res://scripts/ui/[^"]+"\s*\)\n',
        (
            'const CharacterSelectionScreenScript := preload(\n'
            '\t"res://scripts/ui/character_selection_screen.gd"\n'
            ')\n'
        ),
        text,
        count=1,
        flags=re.MULTILINE,
    )

    text = re.sub(
        r'^const (ScrapbookUIScript|StationeryUIScript) := preload\([^\n]+\)\n',
        "",
        text,
        flags=re.MULTILINE,
    )

    text = re.sub(
        r'^const MAIN_MENU_STAGE_SCENE := preload\([^\n]+\)\n',
        "",
        text,
        flags=re.MULTILINE,
    )

    text = re.sub(
        r'^const RetroUIScript := preload\([^\n]+\)\n',
        "",
        text,
        flags=re.MULTILINE,
    )

    text = re.sub(
        r'^const RetroCharacterPreviewScript := preload\([^\n]+\)\n',
        "",
        text,
        flags=re.MULTILINE,
    )

    anchor = (
        'const RoomPreviewScript := preload('
        '"res://scripts/ui/room_preview.gd")\n'
    )

    if anchor not in text:
        raise RuntimeError(
            "Could not locate RoomPreviewScript preload in main.gd."
        )

    return text.replace(
        anchor,
        RETRO_PRELOADS + anchor,
        1,
    )


def validate_files() -> None:
    required = [
        ROOT / "scripts" / "ui" / "retro_ui.gd",
        ROOT / "scripts" / "ui" / "retro_hover_frame.gd",
        ROOT / "scripts" / "ui" / "retro_character_preview.gd",
        ROOT / "scripts" / "ui" / "character_selection_screen.gd",
    ]

    missing = [
        str(path.relative_to(ROOT))
        for path in required
        if not path.is_file()
    ]

    if missing:
        raise FileNotFoundError(
            "Install the new retro UI files first:\n- "
            + "\n- ".join(missing)
        )


def main() -> None:
    validate_files()

    if not MAIN_PATH.is_file():
        raise FileNotFoundError(MAIN_PATH)

    timestamp = datetime.now().strftime(
        "%Y-%m-%d_%H-%M-%S"
    )

    backup(
        MAIN_PATH,
        timestamp,
    )

    text = MAIN_PATH.read_text(
        encoding="utf-8"
    )

    text = replace_preloads(text)

    for function_name, replacement in FUNCTIONS.items():
        text = replace_function(
            text,
            function_name,
            replacement,
        )

    if "ScrapbookUIScript" in text:
        raise RuntimeError(
            "A ScrapbookUIScript reference remains in main.gd. "
            "No changes were written."
        )

    if "StationeryUIScript" in text:
        raise RuntimeError(
            "A StationeryUIScript reference remains in main.gd. "
            "No changes were written."
        )

    MAIN_PATH.write_text(
        text,
        encoding="utf-8",
    )

    print("")
    print("# STUDYTOWN RETRO DATABASE UI")
    print("")
    print("Main menu:          retro database layout")
    print("Rooms:              animated-border room cards")
    print("Character picker:   species cards + villager grid")
    print("Room HUD:           compact blue status bar")
    print("Focus setup:        retro configuration window")
    print("Focus timer:        matching compact status panel")
    print("Break UI:           matching green status panels")
    print("Completion:         retro results window")
    print("Old image assets:   no longer referenced")
    print(f"Backup:             {BACKUP_DIR}")
    print("")
    print("DONE")
    print("")


if __name__ == "__main__":
    main()
