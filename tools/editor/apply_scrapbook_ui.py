#!/usr/bin/env python3
from __future__ import annotations

import shutil
import re
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd()
MAIN_PATH = ROOT / "scripts" / "core" / "main.gd"
BACKUP_DIR = ROOT / "assets" / "dev_local" / "backups" / "scrapbook_ui"

PRELOADS = (
    'const ScrapbookUIScript := preload("res://scripts/ui/scrapbook_ui.gd")\n'
    'const RoomPreviewScript := preload("res://scripts/ui/room_preview.gd")\n'
)

FUNCTIONS: dict[str, str] = {}

FUNCTIONS["_build_menu_world"] = r'''func _build_menu_world() -> void:
	_add_environment(
		Color("#7d6956"),
		Color("#ffe5b4"),
		0.88
	)

	_box(
		world_root,
		Vector3(11.0, 6.2, 0.30),
		Vector3(0.0, 3.0, -2.3),
		mats.paper
	)

	_box(
		world_root,
		Vector3(11.0, 0.34, 8.5),
		Vector3(0.0, -0.28, 0.8),
		mats.wood
	)

	_box(
		world_root,
		Vector3(2.8, 0.22, 1.2),
		Vector3(3.15, 0.70, 1.4),
		mats.wood
	)

	_box(
		world_root,
		Vector3(1.2, 1.4, 1.0),
		Vector3(4.25, 0.7, 1.2),
		mats.cocoa
	)

	for i: int in range(5):
		var sparkle := _sphere(
			world_root,
			Vector3(0.055, 0.055, 0.055),
			Vector3(
				1.5 + float(i) * 0.72,
				3.9 + sin(float(i)) * 0.34,
				-2.05
			),
			mats.gold
		)
		sparkle.name = "MenuWallPin"

	menu_character = _create_character(
		world_root,
		GameState.selected_character,
		false
	)
	menu_character.position = Vector3(
		2.75,
		0.0,
		0.0
	)
	menu_character.scale *= 1.18
	character_loader.play_animation(
		menu_character,
		"Idle",
		0.0
	)

	var camera := Camera3D.new()
	world_root.add_child(camera)
	camera.position = Vector3(
		6.2,
		3.25,
		8.2
	)
	camera.fov = 32.0
	camera.look_at_from_position(
		camera.position,
		Vector3(
			2.75,
			1.55,
			0.0
		)
	)
	camera.current = true

	var key_light := OmniLight3D.new()
	world_root.add_child(key_light)
	key_light.position = Vector3(
		2.6,
		4.8,
		4.6
	)
	key_light.light_color = Color("#ffd28e")
	key_light.light_energy = 5.8
	key_light.omni_range = 12.0
	key_light.shadow_enabled = true
'''

FUNCTIONS["_build_menu_ui"] = r'''func _build_menu_ui() -> void:
	var title := ScrapbookUIScript.label(
		"STUDY TOWN",
		43,
		ScrapbookUIScript.INK,
		true
	)
	ui_root.add_child(title)
	title.position = Vector2(34, 24)
	title.size = Vector2(440, 62)
	title.rotation = deg_to_rad(-1.0)

	var subtitle := ScrapbookUIScript.label(
		"a small place\nfor brighter days",
		17,
		ScrapbookUIScript.INK_SOFT
	)
	ui_root.add_child(subtitle)
	subtitle.position = Vector2(370, 62)
	subtitle.size = Vector2(220, 70)
	subtitle.rotation = deg_to_rad(-4.0)

	ScrapbookUIScript.sticker(
		ui_root,
		"doodles/doodle_17.png",
		Vector2(500, 18),
		Vector2(58, 66),
		-2.0
	)

	ScrapbookUIScript.sticker(
		ui_root,
		"doodles/doodle_18.png",
		Vector2(552, 14),
		Vector2(58, 66),
		2.0
	)

	var top_note := Control.new()
	ui_root.add_child(top_note)
	top_note.position = Vector2(650, 26)
	top_note.size = Vector2(210, 95)

	ScrapbookUIScript.paper(
		top_note,
		"paper/paper_8.png",
		Vector2.ZERO,
		Vector2(210, 95),
		1.8
	)

	ScrapbookUIScript.sticker(
		top_note,
		"tape/tape_14.png",
		Vector2(66, -18),
		Vector2(80, 42),
		-3.0
	)

	var top_note_text := ScrapbookUIScript.label(
		"pick somewhere nice\nand get to work!",
		15,
		ScrapbookUIScript.INK
	)
	top_note.add_child(top_note_text)
	top_note_text.position = Vector2(27, 22)
	top_note_text.size = Vector2(165, 60)
	top_note_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var room_ids := [
		"library",
		"garden",
		"train",
	]

	var room_names := [
		"Library",
		"Garden",
		"Train",
	]

	var room_descriptions := [
		"tall books,\nlonger thoughts.",
		"fresh air,\nsame focus.",
		"different views,\nsame progress.",
	]

	var room_doodles := [
		"doodles/doodle_19.png",
		"doodles/doodle_9.png",
		"stamp/stamp_5.png",
	]

	for i: int in range(3):
		var card := Control.new()
		ui_root.add_child(card)
		card.position = Vector2(
			32 + float(i) * 220.0,
			146
		)
		card.size = Vector2(
			204,
			306
		)
		card.rotation = deg_to_rad(
			[-1.2, 0.8, -0.7][i]
		)

		ScrapbookUIScript.paper(
			card,
			"paper/paper_1.png",
			Vector2.ZERO,
			Vector2(204, 306),
			0.0
		)

		var preview_frame := Control.new()
		preview_frame.position = Vector2(15, 20)
		preview_frame.size = Vector2(174, 154)
		preview_frame.clip_contents = true
		card.add_child(preview_frame)

		var preview := RoomPreviewScript.make_preview(
			room_ids[i],
			Vector2i(174, 154)
		)
		preview.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		preview_frame.add_child(preview)

		var room_name := ScrapbookUIScript.label(
			room_names[i],
			24,
			ScrapbookUIScript.INK,
			true
		)
		room_name.position = Vector2(18, 184)
		room_name.size = Vector2(168, 38)
		room_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(room_name)

		var description := ScrapbookUIScript.label(
			room_descriptions[i],
			14,
			ScrapbookUIScript.INK_SOFT
		)
		description.position = Vector2(24, 224)
		description.size = Vector2(156, 62)
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(description)

		ScrapbookUIScript.sticker(
			card,
			room_doodles[i],
			Vector2(10, 214),
			Vector2(35, 35),
			-4.0
		)

		if i == 0:
			ScrapbookUIScript.sticker(
				card,
				"pin/pin_7.png",
				Vector2(14, -16),
				Vector2(38, 58),
				-7.0
			)
		else:
			ScrapbookUIScript.sticker(
				card,
				"tape/tape_%d.png" % [1, 4, 8][i],
				Vector2(62, -14),
				Vector2(86, 42),
				2.0 - float(i) * 2.0
			)

		var click := ScrapbookUIScript.make_click_area(
			Vector2.ZERO,
			card.size
		)
		card.add_child(click)
		click.pressed.connect(
			_enter_room.bind(i)
		)

	var side_note := Control.new()
	ui_root.add_child(side_note)
	side_note.position = Vector2(680, 158)
	side_note.size = Vector2(150, 126)

	ScrapbookUIScript.paper(
		side_note,
		"paper/paper_7.png",
		Vector2.ZERO,
		Vector2(150, 126),
		3.0
	)

	var side_note_text := ScrapbookUIScript.label(
		"good\ncoffee —\nbetter\nprogress :)",
		14,
		ScrapbookUIScript.INK_SOFT
	)
	side_note.add_child(side_note_text)
	side_note_text.position = Vector2(30, 18)
	side_note_text.size = Vector2(92, 100)
	side_note_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var mini_menu := Control.new()
	ui_root.add_child(mini_menu)
	mini_menu.position = Vector2(26, 476)
	mini_menu.size = Vector2(180, 188)
	mini_menu.rotation = deg_to_rad(-1.0)

	ScrapbookUIScript.paper(
		mini_menu,
		"paper/paper_9.png",
		Vector2.ZERO,
		Vector2(180, 188),
		0.0
	)

	ScrapbookUIScript.sticker(
		mini_menu,
		"tape/tape_6.png",
		Vector2(49, -13),
		Vector2(82, 42),
		1.0
	)

	var settings := Button.new()
	settings.text = "⚙  Settings"
	settings.position = Vector2(18, 36)
	settings.size = Vector2(145, 38)
	ScrapbookUIScript.apply_text_button(settings)
	settings.pressed.connect(_open_scrapbook_settings)
	mini_menu.add_child(settings)

	var credits := Button.new()
	credits.text = "✿  Credits"
	credits.position = Vector2(18, 78)
	credits.size = Vector2(145, 38)
	ScrapbookUIScript.apply_text_button(credits)
	credits.pressed.connect(_open_scrapbook_credits)
	mini_menu.add_child(credits)

	var quit := Button.new()
	quit.text = "↪  Quit"
	quit.position = Vector2(18, 120)
	quit.size = Vector2(145, 38)
	ScrapbookUIScript.apply_text_button(quit)
	quit.pressed.connect(
		func():
			get_tree().quit()
	)
	mini_menu.add_child(quit)

	var profile: CharacterProfile = character_loader.get_profile(
		GameState.selected_character
	)

	var buddy_note := Control.new()
	ui_root.add_child(buddy_note)
	buddy_note.position = Vector2(860, 500)
	buddy_note.size = Vector2(250, 148)
	buddy_note.rotation = deg_to_rad(-2.0)

	ScrapbookUIScript.paper(
		buddy_note,
		"paper/paper_7.png",
		Vector2.ZERO,
		Vector2(250, 148),
		0.0
	)

	ScrapbookUIScript.sticker(
		buddy_note,
		"tape/tape_3.png",
		Vector2(82, -18),
		Vector2(78, 42),
		2.0
	)

	var buddy_name := ScrapbookUIScript.label(
		profile.display_name,
		23,
		ScrapbookUIScript.INK,
		true
	)
	buddy_name.position = Vector2(28, 23)
	buddy_name.size = Vector2(194, 34)
	buddy_note.add_child(buddy_name)

	var buddy_species := ScrapbookUIScript.label(
		profile.species.capitalize(),
		15,
		ScrapbookUIScript.INK_SOFT
	)
	buddy_species.position = Vector2(30, 63)
	buddy_species.size = Vector2(160, 28)
	buddy_note.add_child(buddy_species)

	ScrapbookUIScript.sticker(
		buddy_note,
		"doodles/doodle_13.png",
		Vector2(188, 20),
		Vector2(38, 38),
		0.0
	)

	var change := Button.new()
	change.text = "Change  →"
	change.position = Vector2(26, 98)
	change.size = Vector2(190, 34)
	ScrapbookUIScript.apply_text_button(change)
	change.pressed.connect(_open_character_selection)
	buddy_note.add_child(change)

	var footer_note := ScrapbookUIScript.label(
		"same place,\nbrighter days :)",
		13,
		Color("#7f6c57")
	)
	ui_root.add_child(footer_note)
	footer_note.position = Vector2(250, 532)
	footer_note.size = Vector2(180, 70)
	footer_note.rotation = deg_to_rad(-5.0)
'''

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
		prompt_label.visible = best >= 0

		var prompt_parent := prompt_label.get_parent()

		if prompt_parent is Control:
			(prompt_parent as Control).visible = best >= 0

		if best >= 0:
			var nearest = study_spots[best]

			if str(nearest.seat_type) == "tanning_bed":
				prompt_label.text = "Press  E  to rest here"
			else:
				prompt_label.text = (
					"Press  E  to study here"
				)
'''

FUNCTIONS["_build_room_ui"] = r'''func _build_room_ui() -> void:
	var room_id := str(
		current_room_config.get(
			"id",
			"library"
		)
	)

	var room_doodle: String = str(
		{
			"library": "doodles/doodle_19.png",
			"garden": "doodles/doodle_9.png",
			"train": "stamp/stamp_5.png",
		}.get(
			room_id,
			"doodles/doodle_17.png"
		)
	)

	var room_note := Control.new()
	ui_root.add_child(room_note)
	room_note.position = Vector2(22, 20)
	room_note.size = Vector2(228, 94)
	room_note.rotation = deg_to_rad(-1.0)

	ScrapbookUIScript.paper(
		room_note,
		"paper/paper_8.png",
		Vector2.ZERO,
		Vector2(228, 94),
		0.0
	)

	ScrapbookUIScript.sticker(
		room_note,
		room_doodle,
		Vector2(170, 11),
		Vector2(42, 42),
		0.0
	)

	var title := ScrapbookUIScript.label(
		current_room_name,
		23,
		ScrapbookUIScript.INK,
		true
	)
	title.position = Vector2(20, 14)
	title.size = Vector2(158, 34)
	room_note.add_child(title)

	var meta := ScrapbookUIScript.label(
		"focus · read · create",
		13,
		ScrapbookUIScript.INK_SOFT
	)
	meta.position = Vector2(21, 51)
	meta.size = Vector2(180, 30)
	room_note.add_child(meta)

	var back := Button.new()
	back.text = "←"
	back.position = Vector2(8, 110)
	back.size = Vector2(54, 38)
	ScrapbookUIScript.apply_paper_button(back)
	back.pressed.connect(show_main_menu)
	ui_root.add_child(back)

	var coin_note := Control.new()
	ui_root.add_child(coin_note)
	coin_note.position = Vector2(1130, 18)
	coin_note.size = Vector2(124, 62)
	coin_note.rotation = deg_to_rad(2.0)

	ScrapbookUIScript.paper(
		coin_note,
		"paper/paper_8.png",
		Vector2.ZERO,
		Vector2(124, 62),
		0.0
	)

	ScrapbookUIScript.sticker(
		coin_note,
		"doodles/doodle_9.png",
		Vector2(8, 12),
		Vector2(34, 30),
		0.0
	)

	coins_label = ScrapbookUIScript.label(
		str(GameState.focus_coins),
		18,
		ScrapbookUIScript.INK,
		true
	)
	coins_label.position = Vector2(48, 14)
	coins_label.size = Vector2(65, 30)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_note.add_child(coins_label)

	var prompt_note := Control.new()
	ui_root.add_child(prompt_note)
	prompt_note.position = Vector2(500, 632)
	prompt_note.size = Vector2(280, 58)
	prompt_note.name = "StudyPromptPaper"
	prompt_note.visible = false

	ScrapbookUIScript.paper(
		prompt_note,
		"paper/paper_8.png",
		Vector2.ZERO,
		Vector2(280, 58),
		0.0
	)

	prompt_label = ScrapbookUIScript.label(
		"Press  E  to study here",
		15,
		ScrapbookUIScript.INK
	)
	prompt_label.position = Vector2(20, 13)
	prompt_label.size = Vector2(240, 32)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_note.add_child(prompt_label)

	var hint_note := ScrapbookUIScript.label(
		"WASD move   ·   E interact   ·   F wave",
		12,
		Color("#f4e4c8")
	)
	ui_root.add_child(hint_note)
	hint_note.position = Vector2(24, 680)
	hint_note.size = Vector2(360, 26)

	debug_label = ScrapbookUIScript.label(
		"DEV  F3 anchors  ·  F4 collision  ·  F5 short focus  ·  F6 performance\nFPS: --   Grounded: --",
		12,
		Color("#fff0d4")
	)
	ui_root.add_child(debug_label)
	debug_label.position = Vector2(820, 610)
	debug_label.size = Vector2(430, 84)
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	debug_label.visible = false
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
	ui_root.add_child(overlay)
	overlay.name = "FocusSetupOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.04, 0.028, 0.018, 0.48)

	var note := Control.new()
	overlay.add_child(note)
	note.position = Vector2(365, 82)
	note.size = Vector2(550, 548)
	note.rotation = deg_to_rad(-0.5)

	ScrapbookUIScript.paper(
		note,
		"paper/paper_10.png",
		Vector2.ZERO,
		Vector2(550, 548),
		0.0
	)

	ScrapbookUIScript.sticker(
		note,
		"pin/pin_1.png",
		Vector2(245, -18),
		Vector2(42, 66),
		0.0
	)

	ScrapbookUIScript.sticker(
		note,
		"doodles/doodle_9.png",
		Vector2(35, 30),
		Vector2(44, 40),
		-5.0
	)

	ScrapbookUIScript.sticker(
		note,
		"doodles/doodle_18.png",
		Vector2(452, 25),
		Vector2(54, 56),
		2.0
	)

	ScrapbookUIScript.sticker(
		note,
		"patch/patch_3.png",
		Vector2(402, 228),
		Vector2(124, 88),
		5.0
	)

	ScrapbookUIScript.sticker(
		note,
		"doodles/doodle_5.png",
		Vector2(30, 448),
		Vector2(54, 60),
		-3.0
	)

	var title := ScrapbookUIScript.label(
		"Focus Session",
		29,
		ScrapbookUIScript.INK,
		true
	)
	title.position = Vector2(90, 30)
	title.size = Vector2(340, 42)
	note.add_child(title)

	var subtitle := ScrapbookUIScript.label(
		"Set a task, pick a time, and\nlet's get to it!",
		14,
		ScrapbookUIScript.INK_SOFT
	)
	subtitle.position = Vector2(92, 72)
	subtitle.size = Vector2(300, 54)
	note.add_child(subtitle)

	var task_label := ScrapbookUIScript.label(
		"Task",
		15,
		ScrapbookUIScript.INK,
		true
	)
	task_label.position = Vector2(78, 143)
	task_label.size = Vector2(120, 30)
	note.add_child(task_label)

	task_input = LineEdit.new()
	task_input.position = Vector2(76, 176)
	task_input.size = Vector2(370, 48)
	task_input.placeholder_text = "What are you working on?"
	task_input.max_length = 64
	ScrapbookUIScript.apply_line_edit(task_input)
	note.add_child(task_input)

	var duration_label := ScrapbookUIScript.label(
		"Duration",
		15,
		ScrapbookUIScript.INK,
		true
	)
	duration_label.position = Vector2(78, 245)
	duration_label.size = Vector2(160, 30)
	note.add_child(duration_label)

	var presets := HBoxContainer.new()
	presets.position = Vector2(76, 282)
	presets.size = Vector2(370, 48)
	presets.add_theme_constant_override("separation", 8)
	note.add_child(presets)

	for data in [
		["25 min", 1500],
		["50 min", 3000],
		["90 min", 5400],
	]:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(86, 44)
		button.set_meta("seconds", data[1])
		ScrapbookUIScript.apply_paper_button(
			button,
			int(data[1]) == selected_duration,
			int(data[1]) == selected_duration
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
	custom.custom_minimum_size = Vector2(94, 44)
	ScrapbookUIScript.apply_spin_box(custom)
	custom.value_changed.connect(
		func(value: float):
			selected_duration = int(value) * 60
	)
	presets.add_child(custom)

	var not_now := Button.new()
	not_now.text = "Not now"
	not_now.position = Vector2(94, 401)
	not_now.size = Vector2(140, 50)
	ScrapbookUIScript.apply_paper_button(not_now)
	not_now.pressed.connect(_close_focus_setup)
	note.add_child(not_now)

	var start := Button.new()
	start.text = "Start Focus"
	start.position = Vector2(252, 397)
	start.size = Vector2(200, 56)
	ScrapbookUIScript.apply_paper_button(
		start,
		true,
		true
	)
	start.pressed.connect(
		_begin_focus.bind(spot_index)
	)
	note.add_child(start)

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

			ScrapbookUIScript.apply_paper_button(
				child as Button,
				chosen,
				chosen
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
	ui_root.add_child(overlay)
	overlay.name = "RestingSetupOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.04, 0.028, 0.018, 0.48)

	var note := Control.new()
	overlay.add_child(note)
	note.position = Vector2(390, 112)
	note.size = Vector2(500, 492)
	note.rotation = deg_to_rad(0.7)

	ScrapbookUIScript.paper(
		note,
		"paper/paper_2.png",
		Vector2.ZERO,
		Vector2(500, 492),
		0.0
	)

	ScrapbookUIScript.sticker(
		note,
		"tape/tape_3.png",
		Vector2(205, -20),
		Vector2(90, 48),
		-2.0
	)

	ScrapbookUIScript.sticker(
		note,
		"doodles/doodle_8.png",
		Vector2(410, 32),
		Vector2(52, 60),
		0.0
	)

	ScrapbookUIScript.sticker(
		note,
		"doodles/doodle_13.png",
		Vector2(370, 304),
		Vector2(72, 72),
		-5.0
	)

	var title := ScrapbookUIScript.label(
		"Take a break?",
		31,
		ScrapbookUIScript.INK,
		true
	)
	title.position = Vector2(50, 50)
	title.size = Vector2(330, 46)
	note.add_child(title)

	var helper := ScrapbookUIScript.label(
		"You've been focusing for a while.\nRest, stretch, and come back stronger!",
		14,
		ScrapbookUIScript.INK_SOFT
	)
	helper.position = Vector2(52, 104)
	helper.size = Vector2(360, 60)
	note.add_child(helper)

	var durations := [
		["5 minutes", 300],
		["10 minutes", 600],
		["15 minutes", 900],
	]

	for i: int in range(durations.size()):
		var button := Button.new()
		button.text = durations[i][0]
		button.position = Vector2(
			72,
			184 + float(i) * 60.0
		)
		button.size = Vector2(250, 46)

		ScrapbookUIScript.apply_paper_button(
			button,
			i == 0,
			i == 0
		)

		var seconds := int(durations[i][1])

		button.pressed.connect(
			_begin_scrapbook_break.bind(
				seconds,
				spot_index
			)
		)

		note.add_child(button)

	var back := Button.new()
	back.text = "Back to work"
	back.position = Vector2(72, 372)
	back.size = Vector2(250, 48)
	ScrapbookUIScript.apply_paper_button(back)
	back.pressed.connect(_close_resting_setup)
	note.add_child(back)

	var reminder := ScrapbookUIScript.label(
		"rest\nis part\nof progress :)",
		13,
		ScrapbookUIScript.INK_SOFT
	)
	reminder.position = Vector2(350, 376)
	reminder.size = Vector2(110, 80)
	reminder.rotation = deg_to_rad(-6.0)
	note.add_child(reminder)
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

			ScrapbookUIScript.apply_paper_button(
				child as Button,
				selected,
				selected
			)
'''

FUNCTIONS["_build_focus_hud"] = r'''func _build_focus_hud(task: String) -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var room_id := str(
		current_room_config.get(
			"id",
			"library"
		)
	)

	var room_doodle: String = str(
		{
			"library": "doodles/doodle_19.png",
			"garden": "doodles/doodle_9.png",
			"train": "stamp/stamp_5.png",
		}.get(
			room_id,
			"doodles/doodle_17.png"
		)
	)

	var room_note := Control.new()
	ui_root.add_child(room_note)
	room_note.position = Vector2(22, 20)
	room_note.size = Vector2(220, 90)

	ScrapbookUIScript.paper(
		room_note,
		"paper/paper_8.png",
		Vector2.ZERO,
		Vector2(220, 90),
		-1.0
	)

	ScrapbookUIScript.sticker(
		room_note,
		room_doodle,
		Vector2(168, 12),
		Vector2(38, 38),
		0.0
	)

	var room_name := ScrapbookUIScript.label(
		current_room_name,
		22,
		ScrapbookUIScript.INK,
		true
	)
	room_name.position = Vector2(20, 16)
	room_name.size = Vector2(150, 30)
	room_note.add_child(room_name)

	var room_meta := ScrapbookUIScript.label(
		"focus · read · create",
		12,
		ScrapbookUIScript.INK_SOFT
	)
	room_meta.position = Vector2(20, 50)
	room_meta.size = Vector2(170, 26)
	room_note.add_child(room_meta)

	var coin_note := Control.new()
	ui_root.add_child(coin_note)
	coin_note.position = Vector2(1132, 18)
	coin_note.size = Vector2(122, 60)

	ScrapbookUIScript.paper(
		coin_note,
		"paper/paper_8.png",
		Vector2.ZERO,
		Vector2(122, 60),
		2.0
	)

	ScrapbookUIScript.sticker(
		coin_note,
		"doodles/doodle_9.png",
		Vector2(8, 12),
		Vector2(30, 28),
		0.0
	)

	var coin_value := ScrapbookUIScript.label(
		str(GameState.focus_coins),
		17,
		ScrapbookUIScript.INK,
		true
	)
	coin_value.position = Vector2(44, 13)
	coin_value.size = Vector2(65, 28)
	coin_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_note.add_child(coin_value)

	var timer_note := Control.new()
	ui_root.add_child(timer_note)
	timer_note.position = Vector2(1004, 470)
	timer_note.size = Vector2(246, 220)
	timer_note.rotation = deg_to_rad(0.8)

	ScrapbookUIScript.paper(
		timer_note,
		"paper/paper_7.png",
		Vector2.ZERO,
		Vector2(246, 220),
		0.0
	)

	ScrapbookUIScript.sticker(
		timer_note,
		"tape/tape_14.png",
		Vector2(78, -16),
		Vector2(90, 44),
		-1.0
	)

	ScrapbookUIScript.sticker(
		timer_note,
		"doodles/doodle_5.png",
		Vector2(185, 24),
		Vector2(38, 42),
		3.0
	)

	var focus_label := ScrapbookUIScript.label(
		"focus time",
		18,
		ScrapbookUIScript.INK,
		true
	)
	focus_label.position = Vector2(24, 25)
	focus_label.size = Vector2(150, 28)
	timer_note.add_child(focus_label)

	focus_time_label = ScrapbookUIScript.label(
		"%02d:%02d" % [
			selected_duration / 60,
			selected_duration % 60,
		],
		40,
		ScrapbookUIScript.INK,
		true
	)
	focus_time_label.position = Vector2(22, 58)
	focus_time_label.size = Vector2(198, 52)
	timer_note.add_child(focus_time_label)

	focus_task_label = ScrapbookUIScript.label(
		task if not task.strip_edges().is_empty() else "Quiet focus",
		14,
		ScrapbookUIScript.INK_SOFT
	)
	focus_task_label.position = Vector2(24, 112)
	focus_task_label.size = Vector2(195, 32)
	focus_task_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	timer_note.add_child(focus_task_label)

	focus_shot_label = ScrapbookUIScript.label(
		"",
		1,
		Color.TRANSPARENT
	)
	focus_shot_label.visible = false
	timer_note.add_child(focus_shot_label)

	var pause := Button.new()
	pause.text = "Ⅱ  Pause"
	pause.position = Vector2(20, 158)
	pause.size = Vector2(102, 42)
	ScrapbookUIScript.apply_paper_button(
		pause,
		true,
		true
	)
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = (
				"▶  Resume"
				if FocusManager.paused
				else "Ⅱ  Pause"
			)
	)
	timer_note.add_child(pause)

	var end := Button.new()
	end.text = "■  End"
	end.position = Vector2(132, 158)
	end.size = Vector2(92, 42)
	ScrapbookUIScript.apply_paper_button(end)
	end.add_theme_stylebox_override(
		"normal",
		ScrapbookUIScript.rough_style(
			Color("#e4b2a6"),
			7,
			1,
			ScrapbookUIScript.RED
		)
	)
	end.pressed.connect(FocusManager.cancel_session)
	timer_note.add_child(end)

	var esc_note := Control.new()
	ui_root.add_child(esc_note)
	esc_note.position = Vector2(24, 656)
	esc_note.size = Vector2(196, 46)

	ScrapbookUIScript.paper(
		esc_note,
		"paper/paper_8.png",
		Vector2.ZERO,
		Vector2(196, 46),
		-1.0
	)

	var esc_text := ScrapbookUIScript.label(
		"Press  Esc  for menu",
		12,
		ScrapbookUIScript.INK
	)
	esc_text.position = Vector2(18, 10)
	esc_text.size = Vector2(160, 26)
	esc_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc_note.add_child(esc_text)
'''

FUNCTIONS["_build_resting_hud"] = r'''func _build_resting_hud() -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var timer_note := Control.new()
	ui_root.add_child(timer_note)
	timer_note.position = Vector2(1010, 470)
	timer_note.size = Vector2(240, 214)

	ScrapbookUIScript.paper(
		timer_note,
		"paper/paper_7.png",
		Vector2.ZERO,
		Vector2(240, 214),
		0.7
	)

	ScrapbookUIScript.sticker(
		timer_note,
		"tape/tape_14.png",
		Vector2(74, -14),
		Vector2(90, 42),
		-2.0
	)

	ScrapbookUIScript.sticker(
		timer_note,
		"doodles/doodle_8.png",
		Vector2(184, 24),
		Vector2(38, 44),
		0.0
	)

	var label := ScrapbookUIScript.label(
		"break time",
		18,
		ScrapbookUIScript.INK,
		true
	)
	label.position = Vector2(22, 24)
	label.size = Vector2(150, 30)
	timer_note.add_child(label)

	focus_time_label = ScrapbookUIScript.label(
		"%02d:%02d" % [
			resting_duration / 60,
			resting_duration % 60,
		],
		40,
		ScrapbookUIScript.INK,
		true
	)
	focus_time_label.position = Vector2(20, 62)
	focus_time_label.size = Vector2(190, 50)
	timer_note.add_child(focus_time_label)

	focus_task_label = ScrapbookUIScript.label(
		"stretch · breathe · reset",
		13,
		ScrapbookUIScript.INK_SOFT
	)
	focus_task_label.position = Vector2(22, 114)
	focus_task_label.size = Vector2(190, 28)
	timer_note.add_child(focus_task_label)

	focus_shot_label = ScrapbookUIScript.label(
		"",
		1,
		Color.TRANSPARENT
	)
	focus_shot_label.visible = false
	timer_note.add_child(focus_shot_label)

	var pause := Button.new()
	pause.text = "Ⅱ Pause"
	pause.position = Vector2(18, 156)
	pause.size = Vector2(104, 40)
	ScrapbookUIScript.apply_paper_button(
		pause,
		true,
		true
	)
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = (
				"▶ Resume"
				if FocusManager.paused
				else "Ⅱ Pause"
			)
	)
	timer_note.add_child(pause)

	var end := Button.new()
	end.text = "Back"
	end.position = Vector2(132, 156)
	end.size = Vector2(86, 40)
	ScrapbookUIScript.apply_paper_button(end)
	end.pressed.connect(FocusManager.cancel_session)
	timer_note.add_child(end)
'''

FUNCTIONS["_show_completion"] = r'''func _show_completion(
	minutes: int,
	reward: int
) -> void:
	var overlay := ColorRect.new()
	ui_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.035, 0.024, 0.016, 0.44)

	var note := Control.new()
	overlay.add_child(note)
	note.position = Vector2(405, 120)
	note.size = Vector2(470, 500)
	note.rotation = deg_to_rad(-0.4)

	ScrapbookUIScript.paper(
		note,
		"paper/paper_2.png",
		Vector2.ZERO,
		Vector2(470, 500),
		0.0
	)

	ScrapbookUIScript.sticker(
		note,
		"tape/tape_3.png",
		Vector2(182, -18),
		Vector2(92, 44),
		-1.0
	)

	ScrapbookUIScript.sticker(
		note,
		"doodles/doodle_14.png",
		Vector2(32, 42),
		Vector2(44, 44),
		-5.0
	)

	ScrapbookUIScript.sticker(
		note,
		"stamp/stamp_1.png",
		Vector2(340, 18),
		Vector2(98, 98),
		8.0
	)

	var title := ScrapbookUIScript.label(
		"Nice work!",
		31,
		ScrapbookUIScript.INK,
		true
	)
	title.position = Vector2(90, 50)
	title.size = Vector2(240, 44)
	note.add_child(title)

	var subtitle := ScrapbookUIScript.label(
		"You stayed focused.",
		14,
		ScrapbookUIScript.INK_SOFT
	)
	subtitle.position = Vector2(92, 94)
	subtitle.size = Vector2(240, 30)
	note.add_child(subtitle)

	var reward_note := Control.new()
	reward_note.position = Vector2(92, 142)
	reward_note.size = Vector2(286, 76)
	note.add_child(reward_note)

	ScrapbookUIScript.paper(
		reward_note,
		"paper/paper_8.png",
		Vector2.ZERO,
		Vector2(286, 76),
		0.0
	)

	ScrapbookUIScript.sticker(
		reward_note,
		"doodles/doodle_9.png",
		Vector2(32, 18),
		Vector2(38, 34),
		0.0
	)

	var reward_text := ScrapbookUIScript.label(
		"+%d focus" % reward,
		24,
		ScrapbookUIScript.INK,
		true
	)
	reward_text.position = Vector2(88, 19)
	reward_text.size = Vector2(160, 34)
	reward_note.add_child(reward_text)

	var task_text := ScrapbookUIScript.label(
		"%s\n%d minutes"
		% [
			FocusManager.task,
			minutes,
		],
		15,
		ScrapbookUIScript.INK_SOFT
	)
	task_text.position = Vector2(82, 246)
	task_text.size = Vector2(306, 64)
	task_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_child(task_text)

	var again := Button.new()
	again.text = "Study again"
	again.position = Vector2(72, 340)
	again.size = Vector2(150, 48)
	ScrapbookUIScript.apply_paper_button(
		again,
		true,
		true
	)
	again.pressed.connect(
		build_room.bind(
			GameState.selected_room
		)
	)
	note.add_child(again)

	var places := Button.new()
	places.text = "Back to places"
	places.position = Vector2(242, 340)
	places.size = Vector2(158, 48)
	ScrapbookUIScript.apply_paper_button(places)
	places.pressed.connect(show_main_menu)
	note.add_child(places)

	var footer := ScrapbookUIScript.label(
		"progress lives here :)",
		13,
		ScrapbookUIScript.INK_SOFT
	)
	footer.position = Vector2(190, 420)
	footer.size = Vector2(210, 34)
	footer.rotation = deg_to_rad(-4.0)
	note.add_child(footer)
'''

FUNCTIONS["_show_resting_completion"] = r'''func _show_resting_completion(
	minutes: int
) -> void:
	var overlay := ColorRect.new()
	ui_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.035, 0.024, 0.016, 0.42)

	var note := Control.new()
	overlay.add_child(note)
	note.position = Vector2(430, 170)
	note.size = Vector2(420, 390)

	ScrapbookUIScript.paper(
		note,
		"paper/paper_2.png",
		Vector2.ZERO,
		Vector2(420, 390),
		-0.6
	)

	ScrapbookUIScript.sticker(
		note,
		"stamp/stamp_4.png",
		Vector2(296, 24),
		Vector2(88, 88),
		5.0
	)

	var title := ScrapbookUIScript.label(
		"Break complete!",
		30,
		ScrapbookUIScript.INK,
		true
	)
	title.position = Vector2(50, 60)
	title.size = Vector2(300, 46)
	note.add_child(title)

	var detail := ScrapbookUIScript.label(
		"%d minutes resting\nready when you are." % minutes,
		15,
		ScrapbookUIScript.INK_SOFT
	)
	detail.position = Vector2(55, 126)
	detail.size = Vector2(300, 60)
	note.add_child(detail)

	var return_button := Button.new()
	return_button.text = "Back to work"
	return_button.position = Vector2(92, 235)
	return_button.size = Vector2(236, 52)
	ScrapbookUIScript.apply_paper_button(
		return_button,
		true,
		true
	)
	return_button.pressed.connect(
		build_room.bind(
			GameState.selected_room
		)
	)
	note.add_child(return_button)
'''

EXTRA_FUNCTIONS = r'''func _begin_scrapbook_break(
	seconds: int,
	spot_index: int
) -> void:
	resting_duration = seconds
	_begin_resting(spot_index)


func _open_scrapbook_settings() -> void:
	_show_scrapbook_note(
		"Settings",
		"Keep things simple.\n\nUse Esc to leave a room.\nF3/F4/F5/F6 remain available for development tools."
	)


func _open_scrapbook_credits() -> void:
	_show_scrapbook_note(
		"Credits",
		"StudyTown\n\nBuilt with Godot.\nCozy rooms, little study buddies,\nand a lot of paper scraps."
	)


func _show_scrapbook_note(
	title_text: String,
	body_text: String
) -> void:
	var overlay := ColorRect.new()
	ui_root.add_child(overlay)
	overlay.name = "ScrapbookInfoOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.035, 0.024, 0.016, 0.40)

	var note := Control.new()
	overlay.add_child(note)
	note.position = Vector2(430, 170)
	note.size = Vector2(420, 360)

	ScrapbookUIScript.paper(
		note,
		"paper/paper_2.png",
		Vector2.ZERO,
		Vector2(420, 360),
		-0.5
	)

	ScrapbookUIScript.sticker(
		note,
		"tape/tape_14.png",
		Vector2(155, -12),
		Vector2(100, 46),
		-1.0
	)

	var title := ScrapbookUIScript.label(
		title_text,
		30,
		ScrapbookUIScript.INK,
		true
	)
	title.position = Vector2(48, 54)
	title.size = Vector2(320, 46)
	note.add_child(title)

	var body := ScrapbookUIScript.label(
		body_text,
		15,
		ScrapbookUIScript.INK_SOFT
	)
	body.position = Vector2(52, 120)
	body.size = Vector2(316, 140)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(body)

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(130, 278)
	close.size = Vector2(160, 48)
	ScrapbookUIScript.apply_paper_button(
		close,
		true,
		true
	)
	close.pressed.connect(
		func():
			overlay.queue_free()
	)
	note.add_child(close)
'''


def backup(path: Path, timestamp: str) -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    shutil.copy2(
        path,
        BACKUP_DIR
        / (
            path.stem
            + "_before_scrapbook_ui_"
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


def ensure_preloads(text: str) -> str:
    if (
        "ScrapbookUIScript" in text
        and "RoomPreviewScript" in text
    ):
        return text

    anchor = (
        'const AssetLoaderScript := preload('
        '"res://scripts/assets/asset_loader.gd")\n'
    )

    if anchor not in text:
        raise RuntimeError(
            "Could not locate AssetLoaderScript preload in main.gd."
        )

    return text.replace(
        anchor,
        PRELOADS + anchor,
        1,
    )


def insert_extra_functions(text: str) -> str:
    if "func _open_scrapbook_settings()" in text:
        return text

    anchor = "\nfunc _select_character("
    index = text.find(anchor)

    if index < 0:
        raise RuntimeError(
            "Could not locate _select_character() for helper insertion."
        )

    return (
        text[:index]
        + "\n"
        + EXTRA_FUNCTIONS.strip()
        + "\n\n"
        + text[index + 1 :]
    )


def main() -> None:
    ui_root = ROOT / "assets" / "ui_elements"

    if not ui_root.is_dir():
        raise FileNotFoundError(
            "Expected scrapbook assets at assets/ui_elements. "
            "Copy ~/Downloads/ui_elements there before running this patch."
        )

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

    text = ensure_preloads(text)

    text = re.sub(
        r'^const StationeryUIScript := preload\("res://scripts/ui/stationery_ui\.gd"\)\n',
        "",
        text,
        flags=re.MULTILINE,
    )

    for function_name, replacement in FUNCTIONS.items():
        text = replace_function(
            text,
            function_name,
            replacement,
        )

    text = insert_extra_functions(text)

    MAIN_PATH.write_text(
        text,
        encoding="utf-8",
    )

    print("")
    print("# STUDYTOWN SCRAPBOOK UI")
    print("")
    print("Main menu:          taped room postcards + 3D buddy + paper menu")
    print("Character picker:   handled by character_selection_screen.gd")
    print("Room HUD:           torn room label + focus counter")
    print("Focus setup:        pinned paper note + handmade controls")
    print("Focus timer:        corner paper timer + pause/end")
    print("Break UI:           torn break note + 5/10/15 minute choices")
    print("Completion:         GOOD WORK stamp + reward note")
    print(f"Backup:             {BACKUP_DIR}")
    print("")
    print("DONE")
    print("")


if __name__ == "__main__":
    main()
