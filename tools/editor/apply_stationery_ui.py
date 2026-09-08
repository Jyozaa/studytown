#!/usr/bin/env python3
from __future__ import annotations

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
    / "stationery_ui"
)

PRELOAD_LINE = (
    'const StationeryUIScript := preload('
    '"res://scripts/ui/stationery_ui.gd")\n'
)

FUNCTIONS = {}

FUNCTIONS["_build_menu_ui"] = r'''func _build_menu_ui() -> void:
	var wash := ColorRect.new()
	ui_root.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.04, 0.035, 0.03, 0.10)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var paper := PanelContainer.new()
	ui_root.add_child(paper)
	paper.position = Vector2(24, 22)
	paper.size = Vector2(520, 676)
	paper.add_theme_stylebox_override(
		"panel",
		StationeryUIScript.paper_style(
			Color(0.976, 0.949, 0.882, 0.97),
			22,
			1,
			StationeryUIScript.LINE,
			0
		)
	)

	var margin := MarginContainer.new()
	paper.add_child(margin)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)

	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_theme_constant_override("separation", 10)

	var brand := _label(
		"S  T  U  D  Y  T  O  W  N",
		12,
		StationeryUIScript.MOSS
	)
	StationeryUIScript.apply_body(
		brand,
		12,
		StationeryUIScript.MOSS
	)
	stack.add_child(brand)

	var greeting := _label(
		"A quieter place to be.",
		13,
		StationeryUIScript.MUTED
	)
	StationeryUIScript.apply_body(
		greeting,
		13,
		StationeryUIScript.MUTED
	)
	stack.add_child(greeting)

	var title := _label(
		"Where are we\nstudying today?",
		34,
		StationeryUIScript.INK
	)
	StationeryUIScript.apply_heading(
		title,
		34,
		StationeryUIScript.INK
	)
	stack.add_child(title)

	var room_intro := _label(
		"Choose a place and settle in.",
		14,
		StationeryUIScript.MUTED
	)
	StationeryUIScript.apply_body(
		room_intro,
		14,
		StationeryUIScript.MUTED
	)
	stack.add_child(room_intro)

	var separator := HSeparator.new()
	separator.modulate = StationeryUIScript.LINE
	stack.add_child(separator)

	var room_names := [
		"Grand Library",
		"Garden Café",
		"Scenic Train",
		"Japanese Study Room",
	]

	var descriptors := [
		"Tall books, longer thoughts.",
		"Fresh air, same focus.",
		"Different views, same progress.",
		"Quiet, slow, deliberate.",
	]

	for i: int in range(room_names.size()):
		var card := Button.new()
		card.text = (
			"%02d    %s\n        %s"
			% [
				i + 1,
				room_names[i],
				descriptors[i],
			]
		)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(0, 68)
		card.focus_mode = Control.FOCUS_ALL

		StationeryUIScript.apply_room_button(
			card,
			i == GameState.selected_room
		)

		card.pressed.connect(
			_enter_room.bind(i)
		)
		stack.add_child(card)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)

	var character_line := HSeparator.new()
	character_line.modulate = StationeryUIScript.LINE
	stack.add_child(character_line)

	var selected_profile = character_loader.get_profile(
		clampi(
			GameState.selected_character,
			0,
			maxi(
				character_loader.profiles.size() - 1,
				0
			)
		)
	)

	var buddy_row := HBoxContainer.new()
	buddy_row.add_theme_constant_override("separation", 12)
	stack.add_child(buddy_row)

	var buddy_copy := VBoxContainer.new()
	buddy_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buddy_copy.add_theme_constant_override("separation", 1)
	buddy_row.add_child(buddy_copy)

	var buddy_eyebrow := _label(
		"STUDY BUDDY",
		10,
		StationeryUIScript.MOSS
	)
	StationeryUIScript.apply_body(
		buddy_eyebrow,
		10,
		StationeryUIScript.MOSS
	)
	buddy_copy.add_child(buddy_eyebrow)

	var buddy_name := _label(
		selected_profile.display_name,
		17,
		StationeryUIScript.INK
	)
	StationeryUIScript.apply_body(
		buddy_name,
		17,
		StationeryUIScript.INK
	)
	buddy_copy.add_child(buddy_name)

	var species_text := str(
		selected_profile.species
	).capitalize()

	if species_text.is_empty():
		species_text = "Villager"

	var buddy_species := _label(
		species_text,
		12,
		StationeryUIScript.MUTED
	)
	StationeryUIScript.apply_body(
		buddy_species,
		12,
		StationeryUIScript.MUTED
	)
	buddy_copy.add_child(buddy_species)

	var change := Button.new()
	change.text = "Change  →"
	change.custom_minimum_size = Vector2(112, 46)
	StationeryUIScript.apply_soft_button(change, false)
	change.pressed.connect(_open_character_selection)
	buddy_row.add_child(change)
'''

FUNCTIONS["_build_room_ui"] = r'''func _build_room_ui() -> void:
	var back := Button.new()
	ui_root.add_child(back)
	back.text = "←  Places"
	back.position = Vector2(24, 22)
	back.size = Vector2(108, 42)
	StationeryUIScript.apply_dark_button(back)
	back.pressed.connect(show_main_menu)

	var room_copy := VBoxContainer.new()
	ui_root.add_child(room_copy)
	room_copy.position = Vector2(24, 76)
	room_copy.size = Vector2(380, 70)
	room_copy.add_theme_constant_override("separation", 1)

	var room_title := _label(
		current_room_name,
		22,
		StationeryUIScript.LIGHT_TEXT
	)
	StationeryUIScript.apply_heading(
		room_title,
		22,
		StationeryUIScript.LIGHT_TEXT
	)
	room_copy.add_child(room_title)

	var room_meta := _label(
		"focus  ·  read  ·  create",
		12,
		StationeryUIScript.LIGHT_MUTED
	)
	StationeryUIScript.apply_body(
		room_meta,
		12,
		StationeryUIScript.LIGHT_MUTED
	)
	room_copy.add_child(room_meta)

	var coins := PanelContainer.new()
	ui_root.add_child(coins)
	coins.position = Vector2(1080, 22)
	coins.size = Vector2(176, 42)
	coins.add_theme_stylebox_override(
		"panel",
		StationeryUIScript.dark_glass_style(0.54, 18, 1)
	)

	coins_label = _label(
		"%d focus" % GameState.focus_coins,
		13,
		StationeryUIScript.LIGHT_TEXT
	)
	StationeryUIScript.apply_body(
		coins_label,
		13,
		StationeryUIScript.LIGHT_TEXT
	)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins.add_child(coins_label)

	prompt_label = _label(
		"E   Study here",
		14,
		StationeryUIScript.LIGHT_TEXT
	)
	ui_root.add_child(prompt_label)
	prompt_label.position = Vector2(500, 638)
	prompt_label.size = Vector2(280, 44)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_stylebox_override(
		"normal",
		StationeryUIScript.dark_glass_style(0.72, 18, 1)
	)
	prompt_label.visible = false
	StationeryUIScript.apply_body(
		prompt_label,
		14,
		StationeryUIScript.LIGHT_TEXT
	)

	var hint := _label(
		"WASD move   ·   E interact   ·   F wave",
		11,
		StationeryUIScript.LIGHT_MUTED
	)
	ui_root.add_child(hint)
	hint.position = Vector2(24, 676)
	hint.size = Vector2(360, 26)
	StationeryUIScript.apply_body(
		hint,
		11,
		StationeryUIScript.LIGHT_MUTED
	)

	debug_label = _label(
		"DEV  F3 anchors  ·  F4 collision  ·  F5 short focus  ·  F6 performance\nFPS: --   Grounded: --",
		12,
		StationeryUIScript.LIGHT_TEXT
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
	overlay.color = Color(0.035, 0.03, 0.025, 0.46)

	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.position = Vector2(390, 84)
	panel.size = Vector2(500, 552)
	panel.add_theme_stylebox_override(
		"panel",
		StationeryUIScript.paper_style(
			StationeryUIScript.PAPER,
			22,
			1,
			StationeryUIScript.LINE,
			0
		)
	)

	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)

	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_theme_constant_override("separation", 14)

	var eyebrow := _label(
		"FOCUS SESSION",
		11,
		StationeryUIScript.MOSS
	)
	StationeryUIScript.apply_body(
		eyebrow,
		11,
		StationeryUIScript.MOSS
	)
	stack.add_child(eyebrow)

	var title := _label(
		"Settle in.",
		30,
		StationeryUIScript.INK
	)
	StationeryUIScript.apply_heading(
		title,
		30,
		StationeryUIScript.INK
	)
	stack.add_child(title)

	var helper := _label(
		"One task. One place. A little uninterrupted time.",
		13,
		StationeryUIScript.MUTED
	)
	StationeryUIScript.apply_body(
		helper,
		13,
		StationeryUIScript.MUTED
	)
	stack.add_child(helper)

	var divider := HSeparator.new()
	divider.modulate = StationeryUIScript.LINE
	stack.add_child(divider)

	var task_label := _label(
		"Task",
		13,
		StationeryUIScript.INK
	)
	StationeryUIScript.apply_body(
		task_label,
		13,
		StationeryUIScript.INK
	)
	stack.add_child(task_label)

	task_input = LineEdit.new()
	task_input.placeholder_text = "What are you working on?"
	task_input.max_length = 64
	task_input.custom_minimum_size = Vector2(0, 48)
	StationeryUIScript.apply_line_edit(task_input)
	stack.add_child(task_input)

	var duration_label := _label(
		"Duration",
		13,
		StationeryUIScript.INK
	)
	StationeryUIScript.apply_body(
		duration_label,
		13,
		StationeryUIScript.INK
	)
	stack.add_child(duration_label)

	var presets := GridContainer.new()
	presets.columns = 4
	presets.add_theme_constant_override("h_separation", 8)
	presets.add_theme_constant_override("v_separation", 8)
	stack.add_child(presets)

	for data in [
		["25 min", 1500],
		["50 min", 3000],
		["90 min", 5400],
		["120 min", 7200],
	]:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(100, 46)
		button.set_meta("seconds", data[1])
		StationeryUIScript.apply_soft_button(
			button,
			int(data[1]) == selected_duration
		)
		button.pressed.connect(
			_choose_duration.bind(
				int(data[1]),
				presets
			)
		)
		presets.add_child(button)

	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 10)
	stack.add_child(custom_row)

	var custom_label := _label(
		"Custom minutes",
		13,
		StationeryUIScript.MUTED
	)
	StationeryUIScript.apply_body(
		custom_label,
		13,
		StationeryUIScript.MUTED
	)
	custom_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_row.add_child(custom_label)

	var custom_minutes := SpinBox.new()
	custom_minutes.min_value = 1
	custom_minutes.max_value = 180
	custom_minutes.value = clampi(
		selected_duration / 60,
		1,
		180
	)
	custom_minutes.custom_minimum_size = Vector2(120, 42)
	StationeryUIScript.apply_spinbox(custom_minutes)
	custom_minutes.value_changed.connect(
		func(value: float):
			selected_duration = int(value) * 60
	)
	custom_row.add_child(custom_minutes)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	stack.add_child(actions)

	var cancel := Button.new()
	cancel.text = "Not yet"
	cancel.custom_minimum_size = Vector2(150, 48)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	StationeryUIScript.apply_soft_button(cancel, false)
	cancel.pressed.connect(_close_focus_setup)
	actions.add_child(cancel)

	var start := Button.new()
	start.text = "Start focus  →"
	start.custom_minimum_size = Vector2(220, 48)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	StationeryUIScript.apply_soft_button(start, true)
	start.pressed.connect(
		_begin_focus.bind(spot_index)
	)
	actions.add_child(start)

	task_input.grab_focus()
'''

FUNCTIONS["_choose_duration"] = r'''func _choose_duration(
	seconds: int,
	grid: GridContainer
) -> void:
	selected_duration = seconds

	for child: Node in grid.get_children():
		if child is Button:
			StationeryUIScript.apply_soft_button(
				child as Button,
				int(
					child.get_meta(
						"seconds",
						0
					)
				) == seconds
			)
'''

FUNCTIONS["_build_focus_hud"] = r'''func _build_focus_hud(task: String) -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var vignette := ColorRect.new()
	ui_root.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	vignette.color = Color(0.02, 0.018, 0.015, 0.08)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hud := VBoxContainer.new()
	ui_root.add_child(hud)
	hud.position = Vector2(1032, 26)
	hud.size = Vector2(220, 112)
	hud.add_theme_constant_override("separation", 0)

	focus_time_label = _label(
		"%02d:%02d"
		% [
			selected_duration / 60,
			selected_duration % 60,
		],
		42,
		StationeryUIScript.LIGHT_TEXT
	)
	StationeryUIScript.apply_heading(
		focus_time_label,
		42,
		StationeryUIScript.LIGHT_TEXT
	)
	focus_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(focus_time_label)

	focus_task_label = _label(
		task if not task.strip_edges().is_empty() else "Quiet focus",
		13,
		StationeryUIScript.LIGHT_MUTED
	)
	StationeryUIScript.apply_body(
		focus_task_label,
		13,
		StationeryUIScript.LIGHT_MUTED
	)
	focus_task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	focus_task_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.add_child(focus_task_label)

	focus_shot_label = _label("", 1, Color.TRANSPARENT)
	focus_shot_label.visible = false
	hud.add_child(focus_shot_label)

	var controls := HBoxContainer.new()
	ui_root.add_child(controls)
	controls.position = Vector2(1038, 142)
	controls.size = Vector2(214, 44)
	controls.add_theme_constant_override("separation", 8)

	var pause := Button.new()
	pause.text = "Pause"
	pause.custom_minimum_size = Vector2(98, 42)
	StationeryUIScript.apply_dark_button(pause)
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = (
				"Resume"
				if FocusManager.paused
				else "Pause"
			)
	)
	controls.add_child(pause)

	var end := Button.new()
	end.text = "End"
	end.custom_minimum_size = Vector2(98, 42)
	StationeryUIScript.apply_dark_button(end)
	end.pressed.connect(FocusManager.cancel_session)
	controls.add_child(end)

	var escape_hint := _label(
		"Esc  menu",
		11,
		StationeryUIScript.LIGHT_MUTED
	)
	ui_root.add_child(escape_hint)
	escape_hint.position = Vector2(24, 680)
	escape_hint.size = Vector2(120, 24)
	StationeryUIScript.apply_body(
		escape_hint,
		11,
		StationeryUIScript.LIGHT_MUTED
	)
'''

FUNCTIONS["_build_resting_hud"] = r'''func _build_resting_hud() -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var vignette := ColorRect.new()
	ui_root.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	vignette.color = Color(0.02, 0.018, 0.015, 0.06)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hud := VBoxContainer.new()
	ui_root.add_child(hud)
	hud.position = Vector2(1032, 26)
	hud.size = Vector2(220, 112)

	focus_time_label = _label(
		"%02d:%02d"
		% [
			resting_duration / 60,
			resting_duration % 60,
		],
		42,
		StationeryUIScript.LIGHT_TEXT
	)
	StationeryUIScript.apply_heading(
		focus_time_label,
		42,
		StationeryUIScript.LIGHT_TEXT
	)
	focus_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(focus_time_label)

	focus_task_label = _label(
		"Resting",
		13,
		StationeryUIScript.LIGHT_MUTED
	)
	StationeryUIScript.apply_body(
		focus_task_label,
		13,
		StationeryUIScript.LIGHT_MUTED
	)
	focus_task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(focus_task_label)

	focus_shot_label = _label("", 1, Color.TRANSPARENT)
	focus_shot_label.visible = false
	hud.add_child(focus_shot_label)

	var controls := HBoxContainer.new()
	ui_root.add_child(controls)
	controls.position = Vector2(1038, 142)
	controls.size = Vector2(214, 44)
	controls.add_theme_constant_override("separation", 8)

	var pause := Button.new()
	pause.text = "Pause"
	pause.custom_minimum_size = Vector2(98, 42)
	StationeryUIScript.apply_dark_button(pause)
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = (
				"Resume"
				if FocusManager.paused
				else "Pause"
			)
	)
	controls.add_child(pause)

	var end := Button.new()
	end.text = "End"
	end.custom_minimum_size = Vector2(98, 42)
	StationeryUIScript.apply_dark_button(end)
	end.pressed.connect(FocusManager.cancel_session)
	controls.add_child(end)
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
	overlay.color = Color(0.02, 0.018, 0.015, 0.28)

	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.position = Vector2(438, 226)
	panel.size = Vector2(404, 270)
	panel.add_theme_stylebox_override(
		"panel",
		StationeryUIScript.paper_style(
			StationeryUIScript.PAPER,
			22,
			1,
			StationeryUIScript.LINE,
			0
		)
	)

	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)

	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_theme_constant_override("separation", 10)

	var eyebrow := _label(
		"SESSION COMPLETE",
		10,
		StationeryUIScript.MOSS
	)
	StationeryUIScript.apply_body(
		eyebrow,
		10,
		StationeryUIScript.MOSS
	)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(eyebrow)

	var done := _label(
		"Good work.",
		30,
		StationeryUIScript.INK
	)
	StationeryUIScript.apply_heading(
		done,
		30,
		StationeryUIScript.INK
	)
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(done)

	var detail := _label(
		"%d minutes focused   ·   +%d focus"
		% [
			minutes,
			reward,
		],
		14,
		StationeryUIScript.MUTED
	)
	StationeryUIScript.apply_body(
		detail,
		14,
		StationeryUIScript.MUTED
	)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(detail)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	stack.add_child(buttons)

	var again := Button.new()
	again.text = "Study again"
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.custom_minimum_size = Vector2(0, 46)
	StationeryUIScript.apply_soft_button(again, true)
	again.pressed.connect(
		build_room.bind(GameState.selected_room)
	)
	buttons.add_child(again)

	var places := Button.new()
	places.text = "Places"
	places.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	places.custom_minimum_size = Vector2(0, 46)
	StationeryUIScript.apply_soft_button(places, false)
	places.pressed.connect(show_main_menu)
	buttons.add_child(places)
'''

FUNCTIONS["_show_resting_completion"] = r'''func _show_resting_completion(
	minutes: int
) -> void:
	var overlay := ColorRect.new()
	ui_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.02, 0.018, 0.015, 0.26)

	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.position = Vector2(448, 238)
	panel.size = Vector2(384, 244)
	panel.add_theme_stylebox_override(
		"panel",
		StationeryUIScript.paper_style(
			StationeryUIScript.PAPER,
			22,
			1,
			StationeryUIScript.LINE,
			0
		)
	)

	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)

	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_theme_constant_override("separation", 10)

	var done := _label(
		"Rest complete.",
		29,
		StationeryUIScript.INK
	)
	StationeryUIScript.apply_heading(
		done,
		29,
		StationeryUIScript.INK
	)
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(done)

	var detail := _label(
		"%d minutes resting" % minutes,
		14,
		StationeryUIScript.MUTED
	)
	StationeryUIScript.apply_body(
		detail,
		14,
		StationeryUIScript.MUTED
	)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(detail)

	var return_button := Button.new()
	return_button.text = "Return"
	return_button.custom_minimum_size = Vector2(0, 46)
	StationeryUIScript.apply_soft_button(
		return_button,
		true
	)
	return_button.pressed.connect(
		build_room.bind(GameState.selected_room)
	)
	stack.add_child(return_button)
'''


def backup(path: Path, timestamp: str) -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    shutil.copy2(
        path,
        BACKUP_DIR
        / (
            path.stem
            + "_before_stationery_ui_"
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

    next_function = text.find(
        "\nfunc ",
        start + len(marker),
    )

    if next_function < 0:
        end = len(text)
    else:
        end = next_function + 1

    return (
        text[:start]
        + replacement.rstrip()
        + "\n\n"
        + text[end:]
    )


def ensure_preload(text: str) -> str:
    if "StationeryUIScript" in text:
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
        PRELOAD_LINE + anchor,
        1,
    )


def patch_menu_world(text: str) -> str:
    replacements = {
        "menu_character.position = Vector3(0.8, 0, 0)":
            "menu_character.position = Vector3(2.35, 0, 0)",
        "menu_character.position = Vector3(1.65, 0, 0)":
            "menu_character.position = Vector3(2.35, 0, 0)",
        "Vector3(0.8, -0.08, 0)":
            "Vector3(2.35, -0.08, 0)",
        "Vector3(1.65, -0.08, 0)":
            "Vector3(2.35, -0.08, 0)",
        "Vector3(0.8, 1.65, 0)":
            "Vector3(2.35, 1.65, 0)",
        "Vector3(1.65, 1.65, 0)":
            "Vector3(2.35, 1.65, 0)",
    }

    for old, new in replacements.items():
        text = text.replace(old, new, 1)

    return text


def main() -> None:
    if not MAIN_PATH.is_file():
        raise FileNotFoundError(MAIN_PATH)

    timestamp = datetime.now().strftime(
        "%Y-%m-%d_%H-%M-%S"
    )

    backup(MAIN_PATH, timestamp)

    text = MAIN_PATH.read_text(
        encoding="utf-8"
    )

    text = ensure_preload(text)

    for function_name, replacement in FUNCTIONS.items():
        text = replace_function(
            text,
            function_name,
            replacement,
        )

    text = patch_menu_world(text)

    MAIN_PATH.write_text(
        text,
        encoding="utf-8",
    )

    print("")
    print("# STUDYTOWN STATIONERY / DIEGETIC UI")
    print("")
    print("Main menu:          editorial room list + selected character")
    print("Room HUD:           minimal diegetic labels")
    print("Focus setup:        stationery-style task + duration card")
    print("Focus HUD:          ultra-minimal timer + pause/end controls")
    print("Completion:         compact paper card")
    print(f"Backup:             {BACKUP_DIR}")
    print("")
    print("DONE")
    print("")


if __name__ == "__main__":
    main()
