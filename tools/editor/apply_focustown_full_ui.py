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
    / "focustown_full_ui"
)

FUNCTIONS: dict[str, str] = {}

FUNCTIONS["_build_menu_world"] = r'''func _build_menu_world() -> void:
	_add_environment(
		Color("#121318"),
		Color("#1d2330"),
		0.20
	)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.8, 6.0)
	camera.current = true
	world_root.add_child(camera)
'''

FUNCTIONS["_build_menu_ui"] = r'''func _build_menu_ui() -> void:
	var room_ids := [
		"library",
		"garden",
		"train",
	]

	var room_names := [
		"Grand Library",
		"Garden Commons",
		"Scenic Train",
	]

	var room_short := [
		"Library",
		"Garden",
		"Train",
	]

	var room_available := [
		"395 rooms available",
		"258 rooms available",
		"13 rooms available",
	]

	var room_studying := [
		"1,701 studying",
		"1,006 studying",
		"47 studying",
	]

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = Color("#15161a")
	ui_root.add_child(background)

	# Left navigation shell.
	var sidebar := Panel.new()
	sidebar.position = Vector2(0, 0)
	sidebar.size = Vector2(214, 720)
	sidebar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#17181d"),
			Color("#24262c"),
			1,
			0
		)
	)
	ui_root.add_child(sidebar)

	var selected_index := clampi(
		GameState.selected_character,
		0,
		maxi(
			character_loader.profiles.size() - 1,
			0
		)
	)

	var avatar_panel := Panel.new()
	avatar_panel.position = Vector2(18, 18)
	avatar_panel.size = Vector2(48, 48)
	avatar_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#252831"),
			Color("#343842"),
			2,
			13
		)
	)
	sidebar.add_child(avatar_panel)

	var avatar := RetroCharacterPreviewScript.make_character_preview(
		character_loader,
		selected_index,
		Vector2i(42, 42),
		true
	)
	avatar.position = Vector2(3, 3)
	avatar.size = Vector2(42, 42)
	avatar_panel.add_child(avatar)

	var brand_small := RetroUIScript.label(
		"NEVER STUDY ALONE",
		8,
		Color("#78a9ff"),
		true
	)
	brand_small.position = Vector2(76, 18)
	brand_small.size = Vector2(124, 16)
	sidebar.add_child(brand_small)

	var brand := RetroUIScript.label(
		"StudyTown",
		17,
		RetroUIScript.WHITE,
		true
	)
	brand.position = Vector2(76, 35)
	brand.size = Vector2(124, 26)
	sidebar.add_child(brand)

	var nav_items := [
		["⌂   Home", "home"],
		["♙   Friends", "disabled"],
		["▤   Servers", "disabled"],
		["▥   Stats", "disabled"],
		["○   Profile", "profile"],
		["▢   Store", "disabled"],
		["⚙   Settings", "settings"],
	]

	for i: int in range(nav_items.size()):
		var button := Button.new()
		button.text = nav_items[i][0]
		button.position = Vector2(
			18,
			92 + float(i) * 48.0
		)
		button.size = Vector2(178, 40)

		RetroUIScript.apply_sidebar_button(
			button,
			i == 0
		)

		var action := str(nav_items[i][1])

		if action == "profile":
			button.pressed.connect(
				_open_character_selection
			)
		elif action == "settings":
			button.pressed.connect(
				_open_scrapbook_settings
			)
		elif action == "disabled":
			button.disabled = true

		sidebar.add_child(button)

	var joined := RetroUIScript.label(
		"JOINED SERVERS",
		8,
		RetroUIScript.MUTED,
		true
	)
	joined.position = Vector2(20, 570)
	joined.size = Vector2(170, 18)
	sidebar.add_child(joined)

	var joined_card := Panel.new()
	joined_card.position = Vector2(18, 596)
	joined_card.size = Vector2(178, 68)
	joined_card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1d1f25"),
			Color("#30333a"),
			2,
			15
		)
	)
	sidebar.add_child(joined_card)

	var mini := RetroCharacterPreviewScript.make_character_preview(
		character_loader,
		selected_index,
		Vector2i(42, 42),
		true
	)
	mini.position = Vector2(8, 12)
	mini.size = Vector2(42, 42)
	joined_card.add_child(mini)

	var joined_name := RetroUIScript.label(
		"StudyTown",
		10,
		RetroUIScript.WHITE,
		true
	)
	joined_name.position = Vector2(60, 12)
	joined_name.size = Vector2(108, 20)
	joined_card.add_child(joined_name)

	var live_rooms := RetroUIScript.label(
		"● 1,177 live rooms",
		8,
		RetroUIScript.GREEN,
		true
	)
	live_rooms.position = Vector2(60, 35)
	live_rooms.size = Vector2(110, 18)
	joined_card.add_child(live_rooms)

	# Hardcoded future-state headline stats, intentionally matching the
	# reference's product-dashboard concept.
	var stats_card := Panel.new()
	stats_card.position = Vector2(236, 20)
	stats_card.size = Vector2(1024, 106)
	stats_card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#191b20"),
			Color("#3a3d45"),
			2,
			24,
			4,
			Vector2(0, 4)
		)
	)
	ui_root.add_child(stats_card)

	var future_stats := [
		["◉", "5,694", "focusing now..."],
		["▤", "1,177", "Rooms"],
		["▥", "20,670", "public servers"],
	]

	for i: int in range(3):
		var x := 26 + float(i) * 334.0

		var icon_panel := Panel.new()
		icon_panel.position = Vector2(x, 24)
		icon_panel.size = Vector2(50, 50)
		icon_panel.add_theme_stylebox_override(
			"panel",
			RetroUIScript.panel_style(
				(
					RetroUIScript.CORAL
					if i == 0
					else Color("#22252b")
				),
				Color("#31343c"),
				2,
				16
			)
		)
		stats_card.add_child(icon_panel)

		var icon := RetroUIScript.label(
			future_stats[i][0],
			18,
			RetroUIScript.WHITE,
			true
		)
		icon.position = Vector2(10, 9)
		icon.size = Vector2(30, 28)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_panel.add_child(icon)

		var value := RetroUIScript.label(
			future_stats[i][1],
			27,
			RetroUIScript.WHITE,
			true
		)
		value.position = Vector2(x + 66, 16)
		value.size = Vector2(190, 36)
		stats_card.add_child(value)

		var caption := RetroUIScript.label(
			future_stats[i][2],
			10,
			Color("#d3d5da"),
			true
		)
		caption.position = Vector2(x + 66, 55)
		caption.size = Vector2(200, 22)
		stats_card.add_child(caption)

	# Featured server / place.
	var featured := Panel.new()
	featured.position = Vector2(236, 146)
	featured.size = Vector2(1024, 286)
	featured.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1c1e24"),
			Color("#3a3d45"),
			2,
			24
		)
	)
	ui_root.add_child(featured)

	var featured_holder := Control.new()
	featured_holder.position = Vector2(18, 18)
	featured_holder.size = Vector2(988, 250)
	featured_holder.clip_contents = true
	featured.add_child(featured_holder)

	var featured_preview := RoomPreviewScript.make_preview(
		"library",
		Vector2i(988, 250)
	)
	featured_preview.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	featured_holder.add_child(featured_preview)

	var live_chip := Panel.new()
	live_chip.position = Vector2(34, 32)
	live_chip.size = Vector2(68, 28)
	live_chip.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			RetroUIScript.CORAL,
			RetroUIScript.CORAL.lightened(0.1),
			1,
			14
		)
	)
	featured.add_child(live_chip)

	var live_text := RetroUIScript.label(
		"● LIVE",
		8,
		RetroUIScript.WHITE,
		true
	)
	live_text.position = Vector2(6, 5)
	live_text.size = Vector2(56, 18)
	live_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	live_chip.add_child(live_text)

	var featured_info := Panel.new()
	featured_info.position = Vector2(720, 34)
	featured_info.size = Vector2(260, 68)
	featured_info.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.96, 0.96, 0.97, 0.95),
			Color(1, 1, 1, 0.9),
			1,
			30
		)
	)
	featured.add_child(featured_info)

	var featured_name := RetroUIScript.label(
		"Grand Library",
		12,
		Color("#26282d"),
		true
	)
	featured_name.position = Vector2(16, 8)
	featured_name.size = Vector2(140, 20)
	featured_info.add_child(featured_name)

	var featured_meta := RetroUIScript.label(
		"395 rooms   ·   1,701 studying",
		8,
		Color("#7f838d"),
		true
	)
	featured_meta.position = Vector2(16, 31)
	featured_meta.size = Vector2(170, 18)
	featured_info.add_child(featured_meta)

	var featured_join := Button.new()
	featured_join.text = "JOIN"
	featured_join.position = Vector2(184, 14)
	featured_join.size = Vector2(62, 38)
	RetroUIScript.apply_button(
		featured_join,
		false,
		false,
		false,
		true,
		18
	)
	featured_join.pressed.connect(
		_enter_room.bind(0)
	)
	featured_info.add_child(featured_join)

	var server_icon := RetroUIScript.label(
		"▤",
		18,
		RetroUIScript.BLUE,
		true
	)
	server_icon.position = Vector2(240, 450)
	server_icon.size = Vector2(30, 26)
	ui_root.add_child(server_icon)

	var server_title := RetroUIScript.label(
		"Official StudyTown Server",
		18,
		RetroUIScript.WHITE,
		true
	)
	server_title.position = Vector2(278, 447)
	server_title.size = Vector2(310, 30)
	ui_root.add_child(server_title)

	var server_live := RetroUIScript.label(
		"▤ 1,177 rooms live",
		9,
		RetroUIScript.GREEN,
		true
	)
	server_live.position = Vector2(590, 452)
	server_live.size = Vector2(150, 20)
	ui_root.add_child(server_live)

	var server_sub := RetroUIScript.label(
		"Quickly join and study with people all over the world in real time.",
		9,
		Color("#c0c2c9")
	)
	server_sub.position = Vector2(240, 477)
	server_sub.size = Vector2(620, 20)
	ui_root.add_child(server_sub)

	for i: int in range(3):
		var card := Panel.new()
		card.position = Vector2(
			236 + float(i) * 340.0,
			506
		)
		card.size = Vector2(324, 196)
		card.add_theme_stylebox_override(
			"panel",
			RetroUIScript.panel_style(
				Color("#191b20"),
				Color("#3a3d45"),
				2,
				22,
				3,
				Vector2(0, 3)
			)
		)
		ui_root.add_child(card)

		var preview_holder := Control.new()
		preview_holder.position = Vector2(12, 12)
		preview_holder.size = Vector2(300, 88)
		preview_holder.clip_contents = true
		card.add_child(preview_holder)

		var preview := RoomPreviewScript.make_preview(
			room_ids[i],
			Vector2i(300, 88)
		)
		preview.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		preview_holder.add_child(preview)

		var title := RetroUIScript.label(
			room_short[i],
			13,
			RetroUIScript.WHITE,
			true
		)
		title.position = Vector2(14, 108)
		title.size = Vector2(178, 24)
		card.add_child(title)

		var available := RetroUIScript.label(
			room_available[i],
			8,
			RetroUIScript.GREEN,
			true
		)
		available.position = Vector2(14, 133)
		available.size = Vector2(170, 18)
		card.add_child(available)

		var studying := RetroUIScript.label(
			room_studying[i],
			8,
			Color("#c3c5ca"),
			true
		)
		studying.position = Vector2(14, 154)
		studying.size = Vector2(150, 18)
		card.add_child(studying)

		var join := Button.new()
		join.text = "JOIN"
		join.position = Vector2(212, 126)
		join.size = Vector2(96, 48)
		RetroUIScript.apply_button(
			join,
			false,
			false,
			false,
			true,
			20,
			i == 2
		)
		join.pressed.connect(
			_enter_room.bind(i)
		)
		card.add_child(join)

	# Session setup intentionally never exists on the dashboard.
'''

FUNCTIONS["_build_room_ui"] = r'''func _build_room_ui() -> void:
	# Top-left navigation buttons.
	var back := Button.new()
	back.text = "←"
	back.position = Vector2(14, 14)
	back.size = Vector2(54, 54)
	RetroUIScript.apply_button(
		back,
		true,
		false,
		false,
		false,
		17
	)
	back.pressed.connect(show_main_menu)
	ui_root.add_child(back)

	var profile := Button.new()
	profile.text = "♙"
	profile.position = Vector2(78, 14)
	profile.size = Vector2(54, 54)
	RetroUIScript.apply_button(
		profile,
		true,
		false,
		false,
		false,
		17
	)
	profile.pressed.connect(
		_open_character_selection
	)
	ui_root.add_child(profile)

	# Future multiplayer/resource toolbar.
	var toolbar := Panel.new()
	toolbar.position = Vector2(760, 14)
	toolbar.size = Vector2(500, 58)
	toolbar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.95),
			Color("#30333a"),
			2,
			24,
			3,
			Vector2(0, 3)
		)
	)
	ui_root.add_child(toolbar)

	var toolbar_items := [
		["●", "0"],
		["●", "0"],
		["◔", ""],
		["♪", ""],
	]

	for i: int in range(toolbar_items.size()):
		var item := Panel.new()
		item.position = Vector2(
			10 + float(i) * 62.0,
			8
		)
		item.size = Vector2(54, 42)
		item.add_theme_stylebox_override(
			"panel",
			RetroUIScript.panel_style(
				Color("#15171b"),
				Color("#292c33"),
				1,
				13
			)
		)
		toolbar.add_child(item)

		var item_text := RetroUIScript.label(
			"%s %s"
			% [
				toolbar_items[i][0],
				toolbar_items[i][1],
			],
			10,
			RetroUIScript.WHITE,
			true
		)
		item_text.position = Vector2(5, 10)
		item_text.size = Vector2(44, 20)
		item_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(item_text)

	var room_code := Button.new()
	room_code.text = "COPY ROOM CODE  ⛓"
	room_code.position = Vector2(262, 8)
	room_code.size = Vector2(224, 42)
	RetroUIScript.apply_button(
		room_code,
		true,
		false,
		false,
		true,
		18
	)
	room_code.pressed.connect(
		func():
			DisplayServer.clipboard_set(
				"STUDYTOWN-1177"
			)
			_show_toast(
				"Room code copied"
			)
	)
	toolbar.add_child(room_code)

	# Side rail placeholders for the future social layer.
	var chat_rail := Panel.new()
	chat_rail.position = Vector2(-4, 334)
	chat_rail.size = Vector2(46, 98)
	chat_rail.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.94),
			Color("#30333a"),
			2,
			16
		)
	)
	ui_root.add_child(chat_rail)

	var chat_text := RetroUIScript.label(
		"○\n\n›",
		18,
		RetroUIScript.WHITE,
		true
	)
	chat_text.position = Vector2(8, 12)
	chat_text.size = Vector2(30, 76)
	chat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chat_rail.add_child(chat_text)

	var people_rail := Panel.new()
	people_rail.position = Vector2(1238, 334)
	people_rail.size = Vector2(46, 98)
	people_rail.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.94),
			Color("#30333a"),
			2,
			16
		)
	)
	ui_root.add_child(people_rail)

	var people_text := RetroUIScript.label(
		"♙ 6\n\n‹",
		11,
		RetroUIScript.WHITE,
		true
	)
	people_text.position = Vector2(6, 12)
	people_text.size = Vector2(34, 76)
	people_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	people_rail.add_child(people_text)

	# Radio placeholder.
	var radio := Panel.new()
	radio.position = Vector2(16, 590)
	radio.size = Vector2(108, 108)
	radio.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.94),
			Color("#30333a"),
			2,
			18
		)
	)
	ui_root.add_child(radio)

	var radio_icon := RetroUIScript.label(
		"♫",
		34,
		Color("#f0b877"),
		true
	)
	radio_icon.position = Vector2(20, 22)
	radio_icon.size = Vector2(68, 48)
	radio_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio.add_child(radio_icon)

	var radio_text := RetroUIScript.label(
		"RADIO",
		8,
		RetroUIScript.MUTED,
		true
	)
	radio_text.position = Vector2(20, 75)
	radio_text.size = Vector2(68, 18)
	radio_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio.add_child(radio_text)

	# This button becomes available only when the player is in range of a seat.
	start_session_button = Button.new()
	start_session_button.text = "Start a session"
	start_session_button.position = Vector2(454, 626)
	start_session_button.size = Vector2(372, 58)
	start_session_button.visible = false
	RetroUIScript.apply_button(
		start_session_button,
		false,
		false,
		false,
		false,
		28
	)
	start_session_button.pressed.connect(
		_ft_start_nearest_session
	)
	ui_root.add_child(start_session_button)

	prompt_label = RetroUIScript.label(
		"Pick another spot",
		9,
		RetroUIScript.WHITE,
		true
	)
	prompt_label.position = Vector2(514, 689)
	prompt_label.size = Vector2(252, 20)
	prompt_label.visible = false
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(prompt_label)

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

	var seat_available := best >= 0

	if is_instance_valid(start_session_button):
		start_session_button.visible = seat_available

	if is_instance_valid(prompt_label):
		prompt_label.visible = seat_available

	if seat_available:
		var nearest = study_spots[best]

		if str(nearest.seat_type) == "tanning_bed":
			start_session_button.text = "Start a break"
			prompt_label.text = "Pick another lounger"
		else:
			start_session_button.text = "Start a session"
			prompt_label.text = "Pick another spot"
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

	var overlay := Control.new()
	overlay.name = "FocusSetupOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	ui_root.add_child(overlay)

	var close := Button.new()
	close.text = "×"
	close.position = Vector2(18, 18)
	close.size = Vector2(54, 54)
	RetroUIScript.apply_button(
		close,
		true,
		false,
		false,
		false,
		27
	)
	close.pressed.connect(_close_focus_setup)
	overlay.add_child(close)

	var panel := Panel.new()
	panel.position = Vector2(78, 82)
	panel.size = Vector2(548, 608)
	panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.97),
			Color("#343740"),
			2,
			22,
			5,
			Vector2(0, 5)
		)
	)
	overlay.add_child(panel)

	var duration_input := LineEdit.new()
	duration_input.position = Vector2(90, 34)
	duration_input.size = Vector2(368, 74)
	duration_input.text = _ft_seconds_to_hhmm(
		selected_duration
	)
	duration_input.placeholder_text = "00:25"
	duration_input.max_length = 5
	duration_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	duration_input.select_all_on_focus = true
	RetroUIScript.apply_line_edit(
		duration_input,
		18
	)
	duration_input.add_theme_font_override(
		"font",
		RetroUIScript.heading_font()
	)
	duration_input.add_theme_font_size_override(
		"font_size",
		38
	)
	panel.add_child(duration_input)

	var total_pill := Panel.new()
	total_pill.position = Vector2(190, 116)
	total_pill.size = Vector2(168, 28)
	total_pill.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#15171b"),
			Color("#24272e"),
			1,
			14
		)
	)
	panel.add_child(total_pill)

	var total_label := RetroUIScript.label(
		"◷  TOTAL: %d MIN"
		% maxi(
			1,
			selected_duration / 60
		),
		9,
		Color("#d9dbe0"),
		true
	)
	total_label.position = Vector2(8, 5)
	total_label.size = Vector2(152, 18)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_pill.add_child(total_label)

	var slider := HSlider.new()
	slider.position = Vector2(32, 166)
	slider.size = Vector2(484, 28)
	slider.min_value = 5
	slider.max_value = 180
	slider.step = 5
	slider.value = clampi(
		selected_duration / 60,
		5,
		180
	)
	panel.add_child(slider)

	var marks := RetroUIScript.label(
		"5m                       1h                         2h",
		8,
		RetroUIScript.MUTED,
		true
	)
	marks.position = Vector2(34, 196)
	marks.size = Vector2(480, 18)
	panel.add_child(marks)

	var reserved := RetroUIScript.label(
		"Study spot reserved. Choose your duration and start.",
		9,
		Color("#d5d7dc"),
		true
	)
	reserved.position = Vector2(32, 224)
	reserved.size = Vector2(484, 22)
	reserved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(reserved)

	var session_title := RetroUIScript.label(
		"SESSION TAG",
		9,
		Color("#d5d7dc"),
		true
	)
	session_title.position = Vector2(32, 264)
	session_title.size = Vector2(150, 18)
	panel.add_child(session_title)

	var tag_card := Panel.new()
	tag_card.position = Vector2(32, 288)
	tag_card.size = Vector2(484, 82)
	tag_card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1b1d23"),
			Color("#30333a"),
			2,
			16
		)
	)
	panel.add_child(tag_card)

	var tag_accent := ColorRect.new()
	tag_accent.position = Vector2(12, 14)
	tag_accent.size = Vector2(8, 54)
	tag_accent.color = _ft_tag_color(
		session_tag_name
	)
	tag_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_card.add_child(tag_accent)

	var tag_name := RetroUIScript.label(
		session_tag_name,
		13,
		RetroUIScript.WHITE,
		true
	)
	tag_name.position = Vector2(40, 16)
	tag_name.size = Vector2(280, 24)
	tag_card.add_child(tag_name)

	var focus_copy := RetroUIScript.label(
		(
			session_focus_text
			if not session_focus_text.is_empty()
			else "Add current focus"
		),
		9,
		(
			RetroUIScript.CORAL
			if session_focus_text.is_empty()
			else RetroUIScript.MUTED
		),
		true
	)
	focus_copy.position = Vector2(40, 44)
	focus_copy.size = Vector2(330, 20)
	focus_copy.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tag_card.add_child(focus_copy)

	var edit_focus := Button.new()
	edit_focus.text = "✎"
	edit_focus.position = Vector2(424, 17)
	edit_focus.size = Vector2(44, 44)
	RetroUIScript.apply_button(
		edit_focus,
		true,
		false,
		false,
		true,
		22
	)
	edit_focus.pressed.connect(
		_ft_open_current_focus_editor
	)
	tag_card.add_child(edit_focus)

	var book_title := RetroUIScript.label(
		"BOOK · OPTIONAL",
		9,
		Color("#d5d7dc"),
		true
	)
	book_title.position = Vector2(32, 388)
	book_title.size = Vector2(180, 18)
	panel.add_child(book_title)

	var book_card := Button.new()
	book_card.text = "▣   Choose a book\n     Attach one reading-now book to this session."
	book_card.position = Vector2(32, 412)
	book_card.size = Vector2(484, 72)
	book_card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	RetroUIScript.apply_button(
		book_card,
		true,
		false,
		false,
		true,
		16
	)
	book_card.pressed.connect(
		func():
			_show_toast(
				"Book picker is a future StudyTown feature"
			)
	)
	panel.add_child(book_card)

	var reward_title := RetroUIScript.label(
		"TOTAL REWARD",
		9,
		Color("#d5d7dc"),
		true
	)
	reward_title.position = Vector2(32, 500)
	reward_title.size = Vector2(170, 18)
	panel.add_child(reward_title)

	var reward_card := Panel.new()
	reward_card.position = Vector2(32, 524)
	reward_card.size = Vector2(484, 62)
	reward_card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1b1d23"),
			Color("#30333a"),
			2,
			16
		)
	)
	panel.add_child(reward_card)

	var reward_copy := RetroUIScript.label(
		"Boosts     ● 15 focus      ● 0 golden",
		10,
		Color("#d8dae0"),
		true
	)
	reward_copy.position = Vector2(18, 20)
	reward_copy.size = Vector2(360, 22)
	reward_card.add_child(reward_copy)

	var edit_rewards := Button.new()
	edit_rewards.text = "✎"
	edit_rewards.position = Vector2(424, 9)
	edit_rewards.size = Vector2(44, 44)
	RetroUIScript.apply_button(
		edit_rewards,
		true,
		false,
		false,
		true,
		22
	)
	edit_rewards.pressed.connect(
		_ft_open_session_settings
	)
	reward_card.add_child(edit_rewards)

	var start := Button.new()
	start.text = "Start Session"
	start.position = Vector2(32, 602)
	start.size = Vector2(484, 54)
	RetroUIScript.apply_button(
		start,
		false,
		false,
		false,
		false,
		27
	)
	overlay.add_child(start)

	task_input = LineEdit.new()
	task_input.visible = false
	task_input.text = session_focus_text
	panel.add_child(task_input)

	duration_input.text_changed.connect(
		_ft_duration_text_changed.bind(
			duration_input,
			slider,
			total_label
		)
	)

	slider.value_changed.connect(
		_ft_duration_slider_changed.bind(
			duration_input,
			total_label
		)
	)

	start.pressed.connect(
		_ft_begin_session_from_panel.bind(
			spot_index,
			duration_input
		)
	)
'''

FUNCTIONS["_build_focus_hud"] = r'''func _build_focus_hud(task: String) -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var back := Button.new()
	back.text = "←"
	back.position = Vector2(18, 18)
	back.size = Vector2(50, 50)
	RetroUIScript.apply_button(
		back,
		true,
		false,
		false,
		false,
		16
	)
	back.pressed.connect(FocusManager.cancel_session)
	ui_root.add_child(back)

	var toolbar := Panel.new()
	toolbar.position = Vector2(834, 18)
	toolbar.size = Vector2(426, 54)
	toolbar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.95),
			Color("#30333a"),
			2,
			23
		)
	)
	ui_root.add_child(toolbar)

	var toolbar_copy := RetroUIScript.label(
		"● 0     ● 0      ◔      ♪      ROOM CODE ⛓",
		9,
		RetroUIScript.WHITE,
		true
	)
	toolbar_copy.position = Vector2(18, 17)
	toolbar_copy.size = Vector2(390, 20)
	toolbar.add_child(toolbar_copy)

	var timer := Panel.new()
	timer.position = Vector2(968, 92)
	timer.size = Vector2(292, 238)
	timer.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.97),
			Color("#343740"),
			2,
			22,
			4,
			Vector2(0, 4)
		)
	)
	ui_root.add_child(timer)

	focus_time_label = RetroUIScript.label(
		_ft_format_countdown(
			selected_duration
		),
		35,
		RetroUIScript.WHITE,
		true
	)
	focus_time_label.position = Vector2(20, 26)
	focus_time_label.size = Vector2(252, 48)
	focus_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_child(focus_time_label)

	var tag_pill := Panel.new()
	tag_pill.position = Vector2(86, 82)
	tag_pill.size = Vector2(120, 28)
	tag_pill.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1c1f25"),
			Color("#2b2e35"),
			1,
			14
		)
	)
	timer.add_child(tag_pill)

	var tag_text := RetroUIScript.label(
		session_tag_name.to_upper(),
		8,
		_ft_tag_color(
			session_tag_name
		),
		true
	)
	tag_text.position = Vector2(8, 5)
	tag_text.size = Vector2(104, 18)
	tag_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_pill.add_child(tag_text)

	focus_task_label = RetroUIScript.label(
		task if not task.strip_edges().is_empty() else "Quiet focus",
		11,
		Color("#d8dae0"),
		true
	)
	focus_task_label.position = Vector2(24, 124)
	focus_task_label.size = Vector2(244, 26)
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
	pause.text = "Pause"
	pause.position = Vector2(20, 172)
	pause.size = Vector2(118, 46)
	RetroUIScript.apply_button(
		pause,
		true,
		false,
		false,
		true,
		20
	)
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = (
				"Resume"
				if FocusManager.paused
				else "Pause"
			)
	)
	timer.add_child(pause)

	var end := Button.new()
	end.text = "End"
	end.position = Vector2(154, 172)
	end.size = Vector2(118, 46)
	RetroUIScript.apply_button(
		end,
		false,
		false,
		true,
		true,
		20
	)
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
	overlay.color = Color(0.03, 0.035, 0.045, 0.76)
	ui_root.add_child(overlay)

	var card := Panel.new()
	card.position = Vector2(370, 150)
	card.size = Vector2(540, 420)
	card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#17191e"),
			Color("#33363f"),
			2,
			24,
			5,
			Vector2(0, 5)
		)
	)
	overlay.add_child(card)

	var eyebrow := RetroUIScript.label(
		"SESSION COMPLETE",
		9,
		RetroUIScript.MUTED,
		true
	)
	eyebrow.position = Vector2(30, 26)
	eyebrow.size = Vector2(220, 18)
	card.add_child(eyebrow)

	var title := RetroUIScript.label(
		"Nice work!",
		28,
		RetroUIScript.WHITE,
		true
	)
	title.position = Vector2(30, 50)
	title.size = Vector2(300, 42)
	card.add_child(title)

	var reward_panel := Panel.new()
	reward_panel.position = Vector2(330, 42)
	reward_panel.size = Vector2(170, 62)
	reward_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#29402f"),
			Color("#3d6146"),
			2,
			18
		)
	)
	card.add_child(reward_panel)

	var reward_text := RetroUIScript.label(
		"+%d FOCUS" % reward,
		13,
		RetroUIScript.GREEN,
		true
	)
	reward_text.position = Vector2(12, 19)
	reward_text.size = Vector2(146, 24)
	reward_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_panel.add_child(reward_text)

	var rows := [
		["TASK", FocusManager.task],
		["TAG", session_tag_name],
		[
			"TIME",
			_ft_seconds_to_hhmm(
				maxi(
					60,
					minutes * 60
				)
			)
		],
		["ROOM", current_room_name],
	]

	for i: int in range(rows.size()):
		var row := Panel.new()
		row.position = Vector2(
			30,
			134 + float(i) * 48.0
		)
		row.size = Vector2(480, 40)
		row.add_theme_stylebox_override(
			"panel",
			RetroUIScript.panel_style(
				Color("#1e2026"),
				Color("#2d3037"),
				1,
				13
			)
		)
		card.add_child(row)

		var key := RetroUIScript.label(
			rows[i][0],
			8,
			RetroUIScript.MUTED,
			true
		)
		key.position = Vector2(14, 11)
		key.size = Vector2(90, 18)
		row.add_child(key)

		var value := RetroUIScript.label(
			str(rows[i][1]),
			10,
			RetroUIScript.WHITE,
			true
		)
		value.position = Vector2(110, 10)
		value.size = Vector2(350, 20)
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(value)

	var again := Button.new()
	again.text = "Study again"
	again.position = Vector2(30, 350)
	again.size = Vector2(228, 48)
	RetroUIScript.apply_button(
		again,
		false,
		false,
		false,
		false,
		22
	)
	again.pressed.connect(
		build_room.bind(
			GameState.selected_room
		)
	)
	card.add_child(again)

	var done := Button.new()
	done.text = "Back to places"
	done.position = Vector2(282, 350)
	done.size = Vector2(228, 48)
	RetroUIScript.apply_button(
		done,
		true,
		false,
		false,
		false,
		22
	)
	done.pressed.connect(show_main_menu)
	card.add_child(done)
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
	overlay.color = Color(0.03, 0.035, 0.045, 0.58)
	ui_root.add_child(overlay)

	var card := Panel.new()
	card.position = Vector2(400, 180)
	card.size = Vector2(480, 360)
	card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#17191e"),
			Color("#33363f"),
			2,
			24
		)
	)
	overlay.add_child(card)

	var title := RetroUIScript.label(
		"Take a break",
		26,
		RetroUIScript.WHITE,
		true
	)
	title.position = Vector2(30, 28)
	title.size = Vector2(300, 40)
	card.add_child(title)

	var sub := RetroUIScript.label(
		"Rest, stretch, and come back stronger.",
		10,
		RetroUIScript.MUTED,
		true
	)
	sub.position = Vector2(30, 72)
	sub.size = Vector2(360, 20)
	card.add_child(sub)

	var durations := [
		["5 minutes", 300],
		["10 minutes", 600],
		["15 minutes", 900],
	]

	for i: int in range(durations.size()):
		var button := Button.new()
		button.text = durations[i][0]
		button.position = Vector2(
			60,
			118 + float(i) * 58.0
		)
		button.size = Vector2(360, 44)
		RetroUIScript.apply_button(
			button,
			i == 0,
			i == 0,
			false,
			true,
			20
		)

		button.pressed.connect(
			_begin_scrapbook_break.bind(
				int(durations[i][1]),
				spot_index
			)
		)
		card.add_child(button)

	var back := Button.new()
	back.text = "Cancel"
	back.position = Vector2(150, 302)
	back.size = Vector2(180, 42)
	RetroUIScript.apply_button(
		back,
		true,
		false,
		false,
		true,
		20
	)
	back.pressed.connect(_close_resting_setup)
	card.add_child(back)
'''

FUNCTIONS["_build_resting_hud"] = r'''func _build_resting_hud() -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var timer := Panel.new()
	timer.position = Vector2(992, 92)
	timer.size = Vector2(268, 210)
	timer.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.97),
			Color("#343740"),
			2,
			22
		)
	)
	ui_root.add_child(timer)

	focus_time_label = RetroUIScript.label(
		_ft_format_countdown(
			resting_duration
		),
		34,
		RetroUIScript.WHITE,
		true
	)
	focus_time_label.position = Vector2(16, 30)
	focus_time_label.size = Vector2(236, 44)
	focus_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_child(focus_time_label)

	focus_task_label = RetroUIScript.label(
		"BREAK",
		10,
		RetroUIScript.GREEN,
		true
	)
	focus_task_label.position = Vector2(20, 90)
	focus_task_label.size = Vector2(228, 20)
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
	pause.text = "Pause"
	pause.position = Vector2(16, 144)
	pause.size = Vector2(108, 44)
	RetroUIScript.apply_button(
		pause,
		true,
		false,
		false,
		true,
		20
	)
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = (
				"Resume"
				if FocusManager.paused
				else "Pause"
			)
	)
	timer.add_child(pause)

	var end := Button.new()
	end.text = "End"
	end.position = Vector2(144, 144)
	end.size = Vector2(108, 44)
	RetroUIScript.apply_button(
		end,
		false,
		false,
		true,
		true,
		20
	)
	end.pressed.connect(FocusManager.cancel_session)
	timer.add_child(end)
'''

FUNCTIONS["_show_resting_completion"] = r'''func _show_resting_completion(
	minutes: int
) -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.03, 0.035, 0.045, 0.72)
	ui_root.add_child(overlay)

	var card := Panel.new()
	card.position = Vector2(430, 220)
	card.size = Vector2(420, 280)
	card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#17191e"),
			Color("#33363f"),
			2,
			24
		)
	)
	overlay.add_child(card)

	var title := RetroUIScript.label(
		"Break complete",
		24,
		RetroUIScript.WHITE,
		true
	)
	title.position = Vector2(28, 36)
	title.size = Vector2(364, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)

	var detail := RetroUIScript.label(
		"%d minutes resting" % minutes,
		11,
		RetroUIScript.MUTED,
		true
	)
	detail.position = Vector2(28, 102)
	detail.size = Vector2(364, 24)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(detail)

	var back := Button.new()
	back.text = "Back to work"
	back.position = Vector2(100, 188)
	back.size = Vector2(220, 50)
	RetroUIScript.apply_button(
		back,
		false,
		false,
		false,
		false,
		24
	)
	back.pressed.connect(
		build_room.bind(
			GameState.selected_room
		)
	)
	card.add_child(back)
'''

HELPERS = r'''# === STUDYTOWN FOCUSTOWN HELPERS START ===
func _ft_start_nearest_session() -> void:
	if nearest_spot < 0:
		_show_toast(
			"Pick a study spot first"
		)
		return

	var nearest = study_spots[nearest_spot]

	if str(nearest.seat_type) == "tanning_bed":
		_open_resting_setup(
			nearest_spot
		)
	else:
		_open_focus_setup(
			nearest_spot
		)


func _ft_digits(
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


func _ft_seconds_to_hhmm(
	seconds: int
) -> String:
	var total_minutes := maxi(
		0,
		ceili(
			float(seconds)
			/ 60.0
		)
	)

	return "%02d:%02d" % [
		total_minutes / 60,
		total_minutes % 60,
	]


func _ft_format_countdown(
	seconds: int
) -> String:
	var safe := maxi(
		0,
		seconds
	)

	var hours := safe / 3600
	var minutes := (
		safe % 3600
	) / 60
	var secs := safe % 60

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


func _ft_parse_duration(
	text_value: String
) -> int:
	var digits := _ft_digits(
		text_value
	)

	if digits.is_empty():
		return -1

	while digits.length() < 4:
		digits = "0" + digits

	if digits.length() > 4:
		digits = digits.substr(
			0,
			4
		)

	var hours := int(
		digits.substr(
			0,
			2
		)
	)

	var minutes := int(
		digits.substr(
			2,
			2
		)
	)

	if minutes > 59:
		return -1

	var total := (
		hours * 3600
		+ minutes * 60
	)

	if total < 60 or total > 10800:
		return -1

	return total


func _ft_duration_text_changed(
	new_text: String,
	input: LineEdit,
	slider: HSlider,
	total_label: Label
) -> void:
	var digits := _ft_digits(
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

	var parsed := _ft_parse_duration(
		formatted
	)

	if parsed > 0:
		selected_duration = parsed
		slider.value = clampf(
			float(parsed) / 60.0,
			slider.min_value,
			slider.max_value
		)
		total_label.text = (
			"◷  TOTAL: %d MIN"
			% maxi(
				1,
				parsed / 60
			)
		)


func _ft_duration_slider_changed(
	value: float,
	input: LineEdit,
	total_label: Label
) -> void:
	selected_duration = int(value) * 60
	input.text = _ft_seconds_to_hhmm(
		selected_duration
	)
	input.caret_column = input.text.length()
	total_label.text = (
		"◷  TOTAL: %d MIN"
		% int(value)
	)


func _ft_begin_session_from_panel(
	spot_index: int,
	duration_input: LineEdit
) -> void:
	var parsed := _ft_parse_duration(
		duration_input.text
	)

	if parsed < 0:
		_show_toast(
			"Enter a duration from 00:01 to 03:00"
		)
		duration_input.grab_focus()
		duration_input.select_all()
		return

	selected_duration = parsed

	if is_instance_valid(task_input):
		task_input.text = session_focus_text

	_begin_focus(
		spot_index
	)


func _ft_tag_color(
	tag_name: String
) -> Color:
	match tag_name.to_lower():
		"reading":
			return RetroUIScript.LILAC
		"work":
			return Color("#98d278")
		"creative":
			return RetroUIScript.PEACH
		_:
			return Color("#76a8ff")


func _ft_choose_tag(
	tag_name: String,
	tag_buttons: VBoxContainer,
	preview_tag: Label
) -> void:
	session_tag_name = tag_name
	preview_tag.text = tag_name

	for child: Node in tag_buttons.get_children():
		if child is Button:
			var button := child as Button
			var selected := (
				str(
					button.get_meta(
						"tag_name",
						""
					)
				) == tag_name
			)

			RetroUIScript.apply_button(
				button,
				selected,
				false,
				false,
				true,
				18
			)


func _ft_open_current_focus_editor() -> void:
	var existing := ui_root.get_node_or_null(
		"CurrentFocusOverlay"
	)

	if existing:
		existing.queue_free()

	var overlay := ColorRect.new()
	overlay.name = "CurrentFocusOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color("#15161a")
	ui_root.add_child(overlay)

	var close := Button.new()
	close.text = "×"
	close.position = Vector2(20, 18)
	close.size = Vector2(58, 58)
	RetroUIScript.apply_button(
		close,
		true,
		false,
		false,
		false,
		29
	)
	close.pressed.connect(
		func():
			overlay.queue_free()
	)
	overlay.add_child(close)

	var eyebrow := RetroUIScript.label(
		"ALL TAGS",
		10,
		RetroUIScript.MUTED,
		true
	)
	eyebrow.position = Vector2(104, 20)
	eyebrow.size = Vector2(180, 20)
	overlay.add_child(eyebrow)

	var heading := RetroUIScript.label(
		"Current Focus",
		27,
		RetroUIScript.WHITE,
		true
	)
	heading.position = Vector2(104, 42)
	heading.size = Vector2(320, 40)
	overlay.add_child(heading)

	var left := Panel.new()
	left.position = Vector2(22, 106)
	left.size = Vector2(686, 588)
	left.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1b1d23"),
			Color("#30333a"),
			2,
			22
		)
	)
	overlay.add_child(left)

	var question := RetroUIScript.label(
		"WHAT ARE YOU WORKING ON?",
		9,
		Color("#d8dae0"),
		true
	)
	question.position = Vector2(24, 22)
	question.size = Vector2(260, 18)
	left.add_child(question)

	var focus_edit := TextEdit.new()
	focus_edit.position = Vector2(24, 50)
	focus_edit.size = Vector2(638, 124)
	focus_edit.placeholder_text = "Add current focus"
	focus_edit.text = session_focus_text
	RetroUIScript.apply_text_edit(
		focus_edit,
		17
	)
	left.add_child(focus_edit)

	var counter := RetroUIScript.label(
		"0/120                                      Clear",
		8,
		RetroUIScript.MUTED,
		true
	)
	counter.position = Vector2(24, 184)
	counter.size = Vector2(638, 18)
	left.add_child(counter)

	var create := Button.new()
	create.text = "Create Tag                                      +"
	create.position = Vector2(24, 218)
	create.size = Vector2(638, 58)
	create.alignment = HORIZONTAL_ALIGNMENT_LEFT
	RetroUIScript.apply_button(
		create,
		true,
		false,
		false,
		false,
		20
	)
	create.pressed.connect(
		func():
			_show_toast(
				"Custom tags are a future StudyTown feature"
			)
	)
	left.add_child(create)

	var tag_buttons := VBoxContainer.new()
	tag_buttons.position = Vector2(24, 292)
	tag_buttons.size = Vector2(638, 270)
	tag_buttons.add_theme_constant_override(
		"separation",
		9
	)
	left.add_child(tag_buttons)

	var right := Panel.new()
	right.position = Vector2(736, 106)
	right.size = Vector2(522, 588)
	right.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1b1d23"),
			Color("#30333a"),
			2,
			22
		)
	)
	overlay.add_child(right)

	var preview_heading := RetroUIScript.label(
		"PREVIEW",
		9,
		Color("#d8dae0"),
		true
	)
	preview_heading.position = Vector2(28, 26)
	preview_heading.size = Vector2(120, 18)
	right.add_child(preview_heading)

	var preview_card := Panel.new()
	preview_card.position = Vector2(28, 58)
	preview_card.size = Vector2(466, 122)
	preview_card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#17191e"),
			Color("#30333a"),
			1,
			20
		)
	)
	right.add_child(preview_card)

	var preview_accent := ColorRect.new()
	preview_accent.position = Vector2(20, 22)
	preview_accent.size = Vector2(10, 76)
	preview_accent.color = _ft_tag_color(
		session_tag_name
	)
	preview_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_card.add_child(preview_accent)

	var preview_tag := RetroUIScript.label(
		session_tag_name,
		19,
		RetroUIScript.WHITE,
		true
	)
	preview_tag.position = Vector2(48, 26)
	preview_tag.size = Vector2(260, 30)
	preview_card.add_child(preview_tag)

	var preview_focus := RetroUIScript.label(
		(
			session_focus_text
			if not session_focus_text.is_empty()
			else "Add current focus"
		),
		10,
		RetroUIScript.CORAL,
		true
	)
	preview_focus.position = Vector2(48, 62)
	preview_focus.size = Vector2(320, 22)
	preview_focus.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview_card.add_child(preview_focus)

	var preview_info := Panel.new()
	preview_info.position = Vector2(28, 202)
	preview_info.size = Vector2(466, 176)
	preview_info.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1b1d23"),
			Color("#30333a"),
			1,
			18
		)
	)
	right.add_child(preview_info)

	var info_copy := RetroUIScript.label(
		"TAG\n\n%s\n\nFOCUS\n\n%s"
		% [
			session_tag_name,
			(
				session_focus_text
				if not session_focus_text.is_empty()
				else "Add current focus"
			),
		],
		10,
		Color("#d9dbe0"),
		true
	)
	info_copy.position = Vector2(24, 18)
	info_copy.size = Vector2(418, 142)
	preview_info.add_child(info_copy)

	var tags := [
		"Reading",
		"Work",
		"Study",
		"Creative",
	]

	for tag_name: String in tags:
		var tag_button := Button.new()
		tag_button.text = "   %s        SESSION TAG" % tag_name
		tag_button.custom_minimum_size = Vector2(638, 58)
		tag_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tag_button.set_meta(
			"tag_name",
			tag_name
		)

		RetroUIScript.apply_button(
			tag_button,
			tag_name == session_tag_name,
			false,
			false,
			true,
			18
		)

		tag_button.pressed.connect(
			_ft_choose_tag.bind(
				tag_name,
				tag_buttons,
				preview_tag
			)
		)

		tag_buttons.add_child(tag_button)

	var save := Button.new()
	save.text = "Save Settings"
	save.position = Vector2(28, 500)
	save.size = Vector2(466, 58)
	RetroUIScript.apply_button(
		save,
		false,
		false,
		false,
		false,
		28
	)
	save.pressed.connect(
		func():
			session_focus_text = focus_edit.text.strip_edges()

			if is_instance_valid(task_input):
				task_input.text = session_focus_text

			overlay.queue_free()
	)
	right.add_child(save)


func _ft_open_session_settings() -> void:
	var existing := ui_root.get_node_or_null(
		"SessionSettingsOverlay"
	)

	if existing:
		existing.queue_free()

	var overlay := ColorRect.new()
	overlay.name = "SessionSettingsOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color("#15161a")
	ui_root.add_child(overlay)

	var close := Button.new()
	close.text = "×"
	close.position = Vector2(20, 18)
	close.size = Vector2(58, 58)
	RetroUIScript.apply_button(
		close,
		true,
		false,
		false,
		false,
		29
	)
	close.pressed.connect(
		func():
			overlay.queue_free()
	)
	overlay.add_child(close)

	var eyebrow := RetroUIScript.label(
		"BOOSTS",
		10,
		RetroUIScript.MUTED,
		true
	)
	eyebrow.position = Vector2(104, 20)
	eyebrow.size = Vector2(160, 20)
	overlay.add_child(eyebrow)

	var heading := RetroUIScript.label(
		"Session settings",
		27,
		RetroUIScript.WHITE,
		true
	)
	heading.position = Vector2(104, 42)
	heading.size = Vector2(360, 40)
	overlay.add_child(heading)

	var boost_panel := Panel.new()
	boost_panel.position = Vector2(20, 112)
	boost_panel.size = Vector2(714, 582)
	boost_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#17191e"),
			Color("#2d3037"),
			1,
			20
		)
	)
	overlay.add_child(boost_panel)

	var boost_rows := [
		[
			"Deep Focus",
			"App blocking and background enforcement stay on.",
			"Native only",
			Color("#9ab1cc"),
		],
		[
			"Long Session",
			"25 minutes or more earns the long-session bonus.",
			"Active",
			Color("#ffb45e"),
		],
		[
			"Coffee Boost",
			"2× for first 60m",
			"Empty",
			Color("#c68b5c"),
		],
		[
			"Friend Boost",
			"Study with a friend in the same room for a multiplier.",
			"Invite",
			Color("#5595ff"),
		],
	]

	for i: int in range(boost_rows.size()):
		var row := Panel.new()
		row.position = Vector2(
			18,
			18 + float(i) * 132.0
		)
		row.size = Vector2(678, 116)
		row.add_theme_stylebox_override(
			"panel",
			RetroUIScript.panel_style(
				Color("#1d1f25"),
				Color("#32353d"),
				2,
				20
			)
		)
		boost_panel.add_child(row)

		var accent := ColorRect.new()
		accent.position = Vector2(16, 18)
		accent.size = Vector2(10, 80)
		accent.color = boost_rows[i][3]
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(accent)

		var title := RetroUIScript.label(
			boost_rows[i][0],
			14,
			RetroUIScript.WHITE,
			true
		)
		title.position = Vector2(58, 22)
		title.size = Vector2(240, 26)
		row.add_child(title)

		var sub := RetroUIScript.label(
			boost_rows[i][1],
			9,
			Color("#c3c5cb"),
			true
		)
		sub.position = Vector2(58, 54)
		sub.size = Vector2(410, 42)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(sub)

		var status := RetroUIScript.label(
			boost_rows[i][2],
			11,
			(
				RetroUIScript.GREEN
				if boost_rows[i][2] == "Active"
				else RetroUIScript.MUTED
			),
			true
		)
		status.position = Vector2(526, 44)
		status.size = Vector2(122, 26)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(status)

	var reward_panel := Panel.new()
	reward_panel.position = Vector2(758, 112)
	reward_panel.size = Vector2(502, 582)
	reward_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#17191e"),
			Color("#2d3037"),
			2,
			22
		)
	)
	overlay.add_child(reward_panel)

	var focused := Panel.new()
	focused.position = Vector2(24, 22)
	focused.size = Vector2(454, 252)
	focused.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#15171b"),
			Color("#2d3037"),
			1,
			20
		)
	)
	reward_panel.add_child(focused)

	var focused_title := RetroUIScript.label(
		"FOCUSED TIME",
		9,
		Color("#d5d7dc"),
		true
	)
	focused_title.position = Vector2(24, 20)
	focused_title.size = Vector2(180, 18)
	focused.add_child(focused_title)

	var time := RetroUIScript.label(
		_ft_seconds_to_hhmm(
			selected_duration
		),
		38,
		RetroUIScript.WHITE,
		true
	)
	time.position = Vector2(24, 58)
	time.size = Vector2(250, 52)
	focused.add_child(time)

	var duration_pill := Panel.new()
	duration_pill.position = Vector2(332, 22)
	duration_pill.size = Vector2(96, 30)
	duration_pill.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1c1e24"),
			Color("#262930"),
			1,
			15
		)
	)
	focused.add_child(duration_pill)

	var duration_copy := RetroUIScript.label(
		"%d min"
		% maxi(
			1,
			selected_duration / 60
		),
		9,
		RetroUIScript.WHITE,
		true
	)
	duration_copy.position = Vector2(8, 6)
	duration_copy.size = Vector2(80, 18)
	duration_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duration_pill.add_child(duration_copy)

	var slider := HSlider.new()
	slider.position = Vector2(24, 140)
	slider.size = Vector2(404, 28)
	slider.min_value = 5
	slider.max_value = 120
	slider.step = 5
	slider.value = clampi(
		selected_duration / 60,
		5,
		120
	)
	focused.add_child(slider)

	var slider_marks := RetroUIScript.label(
		"5m                 25m                 1h              2h",
		8,
		RetroUIScript.MUTED,
		true
	)
	slider_marks.position = Vector2(24, 178)
	slider_marks.size = Vector2(404, 18)
	focused.add_child(slider_marks)

	slider.value_changed.connect(
		func(value: float):
			selected_duration = int(value) * 60
			time.text = _ft_seconds_to_hhmm(
				selected_duration
			)
			duration_copy.text = "%d min" % int(value)
	)

	var rewards := Panel.new()
	rewards.position = Vector2(24, 296)
	rewards.size = Vector2(454, 176)
	rewards.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#15171b"),
			Color("#2d3037"),
			1,
			20
		)
	)
	reward_panel.add_child(rewards)

	var rewards_title := RetroUIScript.label(
		"PROJECTED REWARDS                                      ×1",
		9,
		Color("#d5d7dc"),
		true
	)
	rewards_title.position = Vector2(24, 20)
	rewards_title.size = Vector2(404, 18)
	rewards.add_child(rewards_title)

	var focus_reward := RetroUIScript.label(
		"●\n48\nFOCUS",
		20,
		RetroUIScript.WHITE,
		true
	)
	focus_reward.position = Vector2(46, 58)
	focus_reward.size = Vector2(140, 94)
	rewards.add_child(focus_reward)

	var golden_reward := RetroUIScript.label(
		"●\n0\nGOLDEN",
		20,
		RetroUIScript.MUTED,
		true
	)
	golden_reward.position = Vector2(250, 58)
	golden_reward.size = Vector2(140, 94)
	rewards.add_child(golden_reward)

	var save := Button.new()
	save.text = "Save Settings"
	save.position = Vector2(24, 492)
	save.size = Vector2(454, 62)
	RetroUIScript.apply_button(
		save,
		false,
		false,
		false,
		false,
		30
	)
	save.pressed.connect(
		func():
			overlay.queue_free()
	)
	reward_panel.add_child(save)
# === STUDYTOWN FOCUSTOWN HELPERS END ===
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
            + "_before_focustown_full_ui_"
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

    end = (
        len(text)
        if next_func < 0
        else next_func + 1
    )

    return (
        text[:start]
        + replacement.rstrip()
        + "\n\n"
        + text[end:]
    )


def ensure_vars(text: str) -> str:
    anchor = "var task_input: LineEdit\n"

    if anchor not in text:
        raise RuntimeError(
            "Could not locate task_input variable declaration."
        )

    additions = ""

    if "var start_session_button: Button" not in text:
        additions += "var start_session_button: Button\n"

    if "var session_tag_name :=" not in text:
        additions += 'var session_tag_name := "Study"\n'

    if "var session_focus_text :=" not in text:
        additions += 'var session_focus_text := ""\n'

    if "var session_book_name :=" not in text:
        additions += 'var session_book_name := ""\n'

    if additions:
        text = text.replace(
            anchor,
            anchor + additions,
            1,
        )

    return text


def ensure_preloads(text: str) -> str:
    if "RetroUIScript" not in text:
        raise RuntimeError(
            "RetroUIScript preload is missing. "
            "Install retro_ui_v4.gd before running this patch."
        )

    if "RetroCharacterPreviewScript" not in text:
        match = re.search(
            r'const RetroUIScript := preload\([^\n]+\)\n',
            text,
        )

        if match is None:
            raise RuntimeError(
                "Could not locate RetroUIScript preload."
            )

        insertion = (
            'const RetroCharacterPreviewScript := preload('
            '"res://scripts/ui/retro_character_preview.gd")\n'
        )

        text = (
            text[: match.end()]
            + insertion
            + text[match.end() :]
        )

    if "RoomPreviewScript" not in text:
        raise RuntimeError(
            "RoomPreviewScript preload is missing."
        )

    return text


def replace_helper_block(text: str) -> str:
    start_marker = (
        "# === STUDYTOWN FOCUSTOWN HELPERS START ==="
    )
    end_marker = (
        "# === STUDYTOWN FOCUSTOWN HELPERS END ==="
    )

    start = text.find(start_marker)

    if start >= 0:
        end = text.find(
            end_marker,
            start,
        )

        if end < 0:
            raise RuntimeError(
                "Found helper start marker without end marker."
            )

        end += len(end_marker)

        text = (
            text[:start]
            + text[end:]
        )

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
    text = ensure_vars(text)

    for function_name, replacement in FUNCTIONS.items():
        text = replace_function(
            text,
            function_name,
            replacement,
            True,
        )

    text = replace_helper_block(text)

    MAIN_PATH.write_text(
        text,
        encoding="utf-8",
    )

    print("")
    print("# STUDYTOWN FOCUSTOWN-STYLE FULL UI")
    print("")
    print("Main page:         hardcoded future dashboard numbers")
    print("Room HUD:          floating social/game controls")
    print("Seat interaction:  Start a session button")
    print("Session setup:     left-side duration/tag/book/reward panel")
    print("Current Focus:     full tag/focus editor")
    print("Session settings:  boosts + projected rewards screen")
    print("Active timer:      matching dark rounded HUD")
    print("Completion:        matching dark rounded result card")
    print("Buttons:           tactile push-down animation")
    print(f"Backup:            {BACKUP_DIR}")
    print("")
    print("DONE")
    print("")


if __name__ == "__main__":
    main()
