#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd()
MAIN_PATH = ROOT / "scripts" / "core" / "main.gd"
GLOW_PATH = ROOT / "scripts" / "study" / "seat_availability_glow.gd"
BACKUP_DIR = ROOT / "assets" / "dev_local" / "backups" / "seated_session_flow"

FUNCTIONS = {}

FUNCTIONS["_build_room_ui"] = r'''func _build_room_ui() -> void:
	_ft_install_seat_glows()

	var back := Button.new()
	back.text = "←"
	back.position = Vector2(14, 14)
	back.size = Vector2(54, 54)
	RetroUIScript.apply_button(back, true, false, false, false, 17)
	back.pressed.connect(show_main_menu)
	ui_root.add_child(back)

	var profile := Button.new()
	profile.text = "♙"
	profile.position = Vector2(78, 14)
	profile.size = Vector2(54, 54)
	RetroUIScript.apply_button(profile, true, false, false, false, 17)
	profile.pressed.connect(_open_character_selection)
	ui_root.add_child(profile)

	var toolbar := Panel.new()
	toolbar.position = Vector2(824, 14)
	toolbar.size = Vector2(436, 56)
	toolbar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.95),
			Color("#30333a"),
			2,
			23,
			3,
			Vector2(0, 3)
		)
	)
	ui_root.add_child(toolbar)

	var resource_copy := RetroUIScript.label(
		"● 0      ● 0      ◔      ♪",
		9,
		RetroUIScript.WHITE,
		true
	)
	resource_copy.position = Vector2(16, 18)
	resource_copy.size = Vector2(190, 20)
	toolbar.add_child(resource_copy)

	var room_code := Button.new()
	room_code.text = "COPY ROOM CODE  ⛓"
	room_code.position = Vector2(214, 8)
	room_code.size = Vector2(208, 40)
	RetroUIScript.apply_button(room_code, true, false, false, true, 18)
	room_code.pressed.connect(
		func():
			DisplayServer.clipboard_set("STUDYTOWN-1177")
			_show_toast("Room code copied")
	)
	toolbar.add_child(room_code)

	var chat_rail := Panel.new()
	chat_rail.position = Vector2(-4, 340)
	chat_rail.size = Vector2(46, 94)
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

	var chat_copy := RetroUIScript.label("○\n\n›", 17, RetroUIScript.WHITE, true)
	chat_copy.position = Vector2(8, 10)
	chat_copy.size = Vector2(30, 72)
	chat_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chat_rail.add_child(chat_copy)

	var people_rail := Panel.new()
	people_rail.position = Vector2(1238, 340)
	people_rail.size = Vector2(46, 94)
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

	var people_copy := RetroUIScript.label("♙ 6\n\n‹", 10, RetroUIScript.WHITE, true)
	people_copy.position = Vector2(6, 10)
	people_copy.size = Vector2(34, 72)
	people_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	people_rail.add_child(people_copy)

	var radio := Panel.new()
	radio.position = Vector2(16, 598)
	radio.size = Vector2(102, 102)
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

	var radio_icon := RetroUIScript.label("♫", 32, Color("#efb675"), true)
	radio_icon.position = Vector2(18, 20)
	radio_icon.size = Vector2(66, 44)
	radio_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio.add_child(radio_icon)

	var radio_text := RetroUIScript.label("RADIO", 8, RetroUIScript.MUTED, true)
	radio_text.position = Vector2(18, 73)
	radio_text.size = Vector2(66, 18)
	radio_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio.add_child(radio_text)

	prompt_label = RetroUIScript.label("E  TAKE SEAT", 10, RetroUIScript.WHITE, true)
	prompt_label.position = Vector2(516, 675)
	prompt_label.size = Vector2(248, 28)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
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
	if session_setup_open:
		return
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

		if distance <= study_spots[i].interaction_radius and distance < best_distance:
			best = i
			best_distance = distance

	nearest_spot = best

	if debug_spots_visible:
		for i: int in range(study_spots.size()):
			study_spots[i].update_debug(i == best)

	if is_instance_valid(prompt_label):
		prompt_label.visible = best >= 0

		if best >= 0:
			var nearest = study_spots[best]
			if str(nearest.seat_type) == "tanning_bed":
				prompt_label.text = "E  TAKE A BREAK"
			else:
				prompt_label.text = "E  TAKE SEAT"
'''

FUNCTIONS["_open_focus_setup"] = r'''func _open_focus_setup(spot_index: int) -> void:
	if session_setup_open or study_spots.is_empty():
		return

	spot_index = clampi(spot_index, 0, study_spots.size() - 1)
	var spot = study_spots[spot_index]

	if not spot.reserve("local_player", StudySpot.OccupantType.PLAYER):
		_show_toast("That seat is occupied")
		return

	session_setup_open = true
	pending_study_spot = spot
	active_study_spot = spot
	_set_movement_enabled(false)
	_ft_set_seat_glows_enabled(false)

	for child: Node in ui_root.get_children():
		child.queue_free()

	await _transition_player_to_study_spot(spot)
	player.velocity = Vector3.ZERO

	if bool(player_visual.get_meta("is_imported_character", false)):
		character_loader.set_seated(player_visual, true, spot.seated_visual_offset)
		_play_seated_character_animation(
			player_visual,
			_study_animation_for_spot(spot)
		)
	elif player_parts.has("leg_l"):
		player_parts.leg_l.rotation.x = -1.22
		player_parts.leg_r.rotation.x = -1.22
		player_parts.arm_l.rotation.x = -0.80
		player_parts.arm_r.rotation.x = -0.80

	session_setup_camera = _ft_make_session_setup_camera(spot)
	var from_camera := get_viewport().get_camera_3d()

	if is_instance_valid(from_camera) and is_instance_valid(session_setup_camera):
		focus_camera_director.transition(from_camera, session_setup_camera, 0.78)

	await get_tree().create_timer(0.72).timeout

	if not session_setup_open or not is_instance_valid(ui_root):
		return

	_ft_build_seated_session_panel(spot_index)
'''

FUNCTIONS["_close_focus_setup"] = r'''func _close_focus_setup() -> void:
	session_setup_open = false

	var overlay := ui_root.get_node_or_null("SeatedSessionSetup")
	if overlay:
		overlay.queue_free()

	if active_study_spot != null and is_instance_valid(active_study_spot):
		_restore_player_standing()
	elif pending_study_spot != null and is_instance_valid(pending_study_spot):
		pending_study_spot.release("local_player")

	pending_study_spot = null
	_transition_back_to_follow_camera()

	for child: Node in ui_root.get_children():
		child.queue_free()

	_build_room_ui()
	_set_movement_enabled(true)
'''

FUNCTIONS["_begin_focus"] = r'''func _begin_focus(spot_index: int) -> void:
	active_session_mode = "focus"

	var task := (
		session_focus_text
		if not session_focus_text.strip_edges().is_empty()
		else "Quiet focus"
	)

	var spot = study_spots[spot_index]

	if spot.occupant_id != "local_player":
		if not spot.reserve("local_player", StudySpot.OccupantType.PLAYER):
			_show_toast("That seat is occupied")
			_close_focus_setup()
			return

	active_study_spot = spot
	pending_study_spot = null
	session_setup_open = false

	for child: Node in ui_root.get_children():
		child.queue_free()

	if bool(player_visual.get_meta("is_imported_character", false)):
		character_loader.set_seated(player_visual, true, spot.seated_visual_offset)
		_play_seated_character_animation(
			player_visual,
			_study_animation_for_spot(spot)
		)

	_set_movement_enabled(false)
	screen = Screen.FOCUS
	_build_focus_hud(task)
	_prepare_focus_camera_pool(spot)
	focus_shot_index = -1
	next_shot_at = 0
	FocusManager.start_session(task, selected_duration)
'''

FUNCTIONS["_build_focus_hud"] = r'''func _build_focus_hud(task: String) -> void:
	for child: Node in ui_root.get_children():
		child.queue_free()

	var back := Button.new()
	back.text = "←"
	back.position = Vector2(18, 18)
	back.size = Vector2(50, 50)
	RetroUIScript.apply_button(back, true, false, false, false, 16)
	back.pressed.connect(FocusManager.cancel_session)
	ui_root.add_child(back)

	var timer := Panel.new()
	timer.position = Vector2(1000, 22)
	timer.size = Vector2(256, 194)
	timer.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.08, 0.09, 0.11, 0.96),
			Color("#343740"),
			2,
			22,
			4,
			Vector2(0, 4)
		)
	)
	ui_root.add_child(timer)

	focus_time_label = RetroUIScript.label(
		_ft_format_countdown(selected_duration),
		34,
		RetroUIScript.WHITE,
		true
	)
	focus_time_label.position = Vector2(16, 22)
	focus_time_label.size = Vector2(224, 46)
	focus_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_child(focus_time_label)

	var tag_pill := Panel.new()
	tag_pill.position = Vector2(74, 74)
	tag_pill.size = Vector2(108, 26)
	tag_pill.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1c1f25"),
			Color("#2b2e35"),
			1,
			13
		)
	)
	timer.add_child(tag_pill)

	var tag_text := RetroUIScript.label(
		session_tag_name.to_upper(),
		8,
		_ft_tag_color(session_tag_name),
		true
	)
	tag_text.position = Vector2(7, 4)
	tag_text.size = Vector2(94, 18)
	tag_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_pill.add_child(tag_text)

	focus_task_label = RetroUIScript.label(task, 10, Color("#d7d9de"), true)
	focus_task_label.position = Vector2(18, 110)
	focus_task_label.size = Vector2(220, 22)
	focus_task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_task_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	timer.add_child(focus_task_label)

	focus_shot_label = RetroUIScript.label("", 1, Color.TRANSPARENT)
	focus_shot_label.visible = false
	timer.add_child(focus_shot_label)

	var pause := Button.new()
	pause.text = "Pause"
	pause.position = Vector2(16, 146)
	pause.size = Vector2(104, 34)
	RetroUIScript.apply_button(pause, true, false, false, true, 17)
	pause.pressed.connect(
		func():
			FocusManager.toggle_pause()
			pause.text = "Resume" if FocusManager.paused else "Pause"
	)
	timer.add_child(pause)

	var end := Button.new()
	end.text = "End"
	end.position = Vector2(136, 146)
	end.size = Vector2(104, 34)
	RetroUIScript.apply_button(end, false, false, true, true, 17)
	end.pressed.connect(FocusManager.cancel_session)
	timer.add_child(end)
'''

FUNCTIONS["_show_completion"] = r'''func _show_completion(minutes: int, reward: int) -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.03, 0.035, 0.045, 0.74)
	ui_root.add_child(overlay)

	var card := Panel.new()
	card.position = Vector2(390, 158)
	card.size = Vector2(500, 400)
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

	var eyebrow := RetroUIScript.label("SESSION COMPLETE", 9, RetroUIScript.MUTED, true)
	eyebrow.position = Vector2(28, 24)
	eyebrow.size = Vector2(220, 18)
	card.add_child(eyebrow)

	var title := RetroUIScript.label("Nice work!", 27, RetroUIScript.WHITE, true)
	title.position = Vector2(28, 48)
	title.size = Vector2(260, 40)
	card.add_child(title)

	var reward_box := Panel.new()
	reward_box.position = Vector2(314, 36)
	reward_box.size = Vector2(156, 58)
	reward_box.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#29402f"),
			Color("#3d6146"),
			2,
			18
		)
	)
	card.add_child(reward_box)

	var reward_text := RetroUIScript.label(
		"+%d FOCUS" % reward,
		12,
		RetroUIScript.GREEN,
		true
	)
	reward_text.position = Vector2(8, 18)
	reward_text.size = Vector2(140, 22)
	reward_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_box.add_child(reward_text)

	var rows := [
		["TASK", FocusManager.task],
		["TAG", session_tag_name],
		["TIME", _ft_seconds_to_hhmm(maxi(60, minutes * 60))],
		["ROOM", current_room_name],
	]

	for i: int in range(rows.size()):
		var row := Panel.new()
		row.position = Vector2(28, 122 + float(i) * 46.0)
		row.size = Vector2(444, 38)
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

		var key := RetroUIScript.label(rows[i][0], 8, RetroUIScript.MUTED, true)
		key.position = Vector2(12, 10)
		key.size = Vector2(82, 18)
		row.add_child(key)

		var value := RetroUIScript.label(str(rows[i][1]), 10, RetroUIScript.WHITE, true)
		value.position = Vector2(100, 9)
		value.size = Vector2(330, 20)
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(value)

	var again := Button.new()
	again.text = "Study again"
	again.position = Vector2(28, 330)
	again.size = Vector2(210, 46)
	RetroUIScript.apply_button(again, false, false, false, false, 22)
	again.pressed.connect(build_room.bind(GameState.selected_room))
	card.add_child(again)

	var done := Button.new()
	done.text = "Back to places"
	done.position = Vector2(262, 330)
	done.size = Vector2(210, 46)
	RetroUIScript.apply_button(done, true, false, false, false, 22)
	done.pressed.connect(show_main_menu)
	card.add_child(done)
'''

FUNCTIONS["_on_focus_tick"] = r'''func _on_focus_tick(remaining: int) -> void:
	if is_instance_valid(focus_time_label):
		focus_time_label.text = _ft_format_countdown(remaining)
'''

HELPERS = r'''# === STUDYTOWN SEATED SESSION FLOW START ===
func _ft_install_seat_glows() -> void:
	for i: int in range(study_spots.size()):
		var spot = study_spots[i]
		var existing := spot.get_node_or_null("AvailabilityGlow")

		if existing != null:
			existing.call("set_enabled", true)
			continue

		var glow = SeatAvailabilityGlowScript.new()
		glow.name = "AvailabilityGlow"
		spot.add_child(glow)
		glow.call("configure", i)


func _ft_set_seat_glows_enabled(value: bool) -> void:
	for spot in study_spots:
		if not is_instance_valid(spot):
			continue

		var glow := spot.get_node_or_null("AvailabilityGlow")
		if glow != null:
			glow.call("set_enabled", value)


func _ft_make_session_setup_camera(spot) -> Camera3D:
	if is_instance_valid(session_setup_camera):
		session_setup_camera.queue_free()

	var basis := Basis(Vector3.UP, spot.facing_yaw)
	var forward := basis * Vector3.FORWARD
	var right := basis * Vector3.RIGHT
	var character_target: Vector3 = spot.sitting_position + Vector3.UP * 1.30
	var composition_target := character_target - right * 0.82

	var candidates := [
		composition_target + forward * 3.35 + Vector3.UP * 0.72,
		composition_target + forward * 3.10 - right * 0.45 + Vector3.UP * 0.78,
		composition_target - forward * 3.10 + Vector3.UP * 0.72,
	]

	var chosen: Vector3 = candidates[0]

	for candidate: Vector3 in candidates:
		if _is_focus_shot_clear(candidate, spot):
			chosen = candidate
			break

	var camera := _make_camera(chosen, composition_target, 36.0, false)
	camera.set_meta("shot_name", "session setup front")
	camera.set_meta("requires_player_visibility", true)
	return camera


func _ft_seconds_to_hhmm(seconds: int) -> String:
	var total_minutes := maxi(0, ceili(float(seconds) / 60.0))
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]


func _ft_format_countdown(seconds: int) -> String:
	var safe := maxi(0, seconds)
	var hours := safe / 3600
	var minutes := (safe % 3600) / 60
	var secs := safe % 60

	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]

	return "%02d:%02d" % [minutes, secs]


func _ft_reward_base(minutes: int) -> int:
	return maxi(1, minutes)


func _ft_reward_bonus(minutes: int) -> int:
	return 5 if minutes >= 25 else 0


func _ft_projected_reward(minutes: int) -> int:
	return _ft_reward_base(minutes) + _ft_reward_bonus(minutes)


func _ft_reward_text(minutes: int) -> String:
	var base := _ft_reward_base(minutes)
	var bonus := _ft_reward_bonus(minutes)

	return (
		"BASE FOCUS                     +%d\n"
		+ "LONG SESSION BONUS             +%d\n"
		+ "TOTAL                           %d"
	) % [base, bonus, base + bonus]


func _ft_tag_color(tag_name: String) -> Color:
	match tag_name.to_lower():
		"reading":
			return RetroUIScript.LILAC
		"work":
			return Color("#98d278")
		"creative":
			return RetroUIScript.PEACH
		_:
			return Color("#76a8ff")


func _ft_select_session_tag(tag_name: String, container: HBoxContainer) -> void:
	session_tag_name = tag_name

	for child: Node in container.get_children():
		if child is Button:
			var button := child as Button
			var selected := str(button.get_meta("tag_name", "")) == tag_name
			RetroUIScript.apply_button(button, selected, false, false, true, 17)


func _ft_duration_from_slider(
	value: float,
	time_input: LineEdit,
	reward_label: Label
) -> void:
	var minutes := int(value)
	selected_duration = minutes * 60
	time_input.text = _ft_seconds_to_hhmm(selected_duration)
	reward_label.text = _ft_reward_text(minutes)


func _ft_parse_setup_time(text_value: String) -> int:
	var digits := ""

	for i: int in range(text_value.length()):
		var codepoint := text_value.unicode_at(i)
		if codepoint >= 48 and codepoint <= 57:
			digits += text_value.substr(i, 1)

	if digits.is_empty():
		return -1

	while digits.length() < 4:
		digits = "0" + digits

	if digits.length() > 4:
		digits = digits.substr(0, 4)

	var hours := int(digits.substr(0, 2))
	var minutes := int(digits.substr(2, 2))

	if minutes > 59:
		return -1

	var total_minutes := hours * 60 + minutes

	if total_minutes < 5 or total_minutes > 120:
		return -1

	return total_minutes


func _ft_time_input_changed(
	new_text: String,
	time_input: LineEdit,
	slider: HSlider,
	reward_label: Label
) -> void:
	var digits := ""

	for i: int in range(new_text.length()):
		var codepoint := new_text.unicode_at(i)
		if codepoint >= 48 and codepoint <= 57:
			digits += new_text.substr(i, 1)

	if digits.length() > 4:
		digits = digits.substr(0, 4)

	var formatted := digits

	if digits.length() > 2:
		formatted = digits.substr(0, 2) + ":" + digits.substr(2)

	if time_input.text != formatted:
		time_input.text = formatted
		time_input.caret_column = formatted.length()

	var minutes := _ft_parse_setup_time(formatted)

	if minutes < 0:
		return

	selected_duration = minutes * 60
	slider.value = minutes
	reward_label.text = _ft_reward_text(minutes)


func _ft_build_seated_session_panel(spot_index: int) -> void:
	var root := Control.new()
	root.name = "SeatedSessionSetup"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(root)

	var panel := Panel.new()
	panel.position = Vector2(38, 48)
	panel.size = Vector2(500, 624)
	panel.modulate.a = 0.0
	panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.075, 0.082, 0.10, 0.975),
			Color("#353842"),
			2,
			24,
			5,
			Vector2(0, 5)
		)
	)
	root.add_child(panel)

	var close := Button.new()
	close.text = "×"
	close.position = Vector2(18, 16)
	close.size = Vector2(48, 48)
	RetroUIScript.apply_button(close, true, false, false, false, 24)
	close.pressed.connect(_close_focus_setup)
	panel.add_child(close)

	var heading := RetroUIScript.label("Start a session", 24, RetroUIScript.WHITE, true)
	heading.position = Vector2(82, 19)
	heading.size = Vector2(300, 36)
	panel.add_child(heading)

	var time_input := LineEdit.new()
	time_input.position = Vector2(90, 76)
	time_input.size = Vector2(320, 70)
	time_input.text = _ft_seconds_to_hhmm(selected_duration)
	time_input.max_length = 5
	time_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_input.select_all_on_focus = true
	RetroUIScript.apply_line_edit(time_input, 20)
	time_input.add_theme_font_override("font", RetroUIScript.heading_font())
	time_input.add_theme_font_size_override("font_size", 36)
	panel.add_child(time_input)

	var slider := HSlider.new()
	slider.position = Vector2(42, 158)
	slider.size = Vector2(416, 26)
	slider.min_value = 5
	slider.max_value = 120
	slider.step = 5
	slider.value = clampi(selected_duration / 60, 5, 120)
	panel.add_child(slider)

	var slider_marks := RetroUIScript.label(
		"5m               25m                 1h               2h",
		8,
		RetroUIScript.MUTED,
		true
	)
	slider_marks.position = Vector2(42, 188)
	slider_marks.size = Vector2(416, 18)
	panel.add_child(slider_marks)

	var focus_title := RetroUIScript.label(
		"CURRENT FOCUS · OPTIONAL",
		8,
		Color("#d5d7dc"),
		true
	)
	focus_title.position = Vector2(42, 222)
	focus_title.size = Vector2(210, 18)
	panel.add_child(focus_title)

	task_input = LineEdit.new()
	task_input.position = Vector2(42, 246)
	task_input.size = Vector2(416, 42)
	task_input.placeholder_text = "What are you working on?"
	task_input.text = session_focus_text
	task_input.max_length = 64
	RetroUIScript.apply_line_edit(task_input, 14)
	panel.add_child(task_input)

	var tag_title := RetroUIScript.label("SESSION TAG", 8, Color("#d5d7dc"), true)
	tag_title.position = Vector2(42, 310)
	tag_title.size = Vector2(130, 18)
	panel.add_child(tag_title)

	var tags := HBoxContainer.new()
	tags.position = Vector2(42, 334)
	tags.size = Vector2(416, 42)
	tags.add_theme_constant_override("separation", 7)
	panel.add_child(tags)

	for tag_name: String in ["Study", "Reading", "Work", "Creative"]:
		var tag_button := Button.new()
		tag_button.text = tag_name
		tag_button.custom_minimum_size = Vector2(98, 38)
		tag_button.set_meta("tag_name", tag_name)

		RetroUIScript.apply_button(
			tag_button,
			tag_name == session_tag_name,
			false,
			false,
			true,
			17
		)

		tag_button.pressed.connect(
			_ft_select_session_tag.bind(tag_name, tags)
		)
		tags.add_child(tag_button)

	var reward_title := RetroUIScript.label(
		"PROJECTED REWARDS",
		8,
		Color("#d5d7dc"),
		true
	)
	reward_title.position = Vector2(42, 398)
	reward_title.size = Vector2(170, 18)
	panel.add_child(reward_title)

	var reward_card := Panel.new()
	reward_card.position = Vector2(42, 422)
	reward_card.size = Vector2(416, 104)
	reward_card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#181a1f"),
			Color("#30333a"),
			2,
			17
		)
	)
	panel.add_child(reward_card)

	var reward_label := RetroUIScript.label(
		_ft_reward_text(int(slider.value)),
		9,
		Color("#d8dae0"),
		true
	)
	reward_label.position = Vector2(18, 16)
	reward_label.size = Vector2(380, 76)
	reward_card.add_child(reward_label)

	var start := Button.new()
	start.text = "Start Session"
	start.position = Vector2(42, 548)
	start.size = Vector2(416, 54)
	RetroUIScript.apply_button(start, false, false, false, false, 27)
	panel.add_child(start)

	slider.value_changed.connect(
		_ft_duration_from_slider.bind(time_input, reward_label)
	)

	time_input.text_changed.connect(
		_ft_time_input_changed.bind(time_input, slider, reward_label)
	)

	start.pressed.connect(
		func():
			var minutes := _ft_parse_setup_time(time_input.text)

			if minutes < 0:
				_show_toast("Choose 5 minutes to 2 hours")
				time_input.grab_focus()
				time_input.select_all()
				return

			selected_duration = minutes * 60
			session_focus_text = task_input.text.strip_edges()
			_begin_focus(spot_index)
	)

	var intro := panel.create_tween()
	intro.set_trans(Tween.TRANS_QUAD)
	intro.set_ease(Tween.EASE_OUT)
	intro.tween_property(panel, "modulate:a", 1.0, 0.18)
# === STUDYTOWN SEATED SESSION FLOW END ===
'''


def backup(path: Path, timestamp: str) -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(
        path,
        BACKUP_DIR
        / (
            path.stem
            + "_before_seated_session_flow_"
            + timestamp
            + path.suffix
            + ".backup.txt"
        ),
    )


def replace_function(text: str, function_name: str, replacement: str, required: bool = True) -> str:
    marker = f"func {function_name}("
    start = text.find(marker)

    if start < 0:
        if required:
            raise RuntimeError(f"Could not find {function_name}() in main.gd")
        return text

    next_func = text.find("\nfunc ", start + len(marker))
    end = len(text) if next_func < 0 else next_func + 1
    return text[:start] + replacement.rstrip() + "\n\n" + text[end:]


def ensure_preloads(text: str) -> str:
    if "SeatAvailabilityGlowScript" in text:
        return text

    match = re.search(r'const RetroUIScript := preload\([^\n]+\)\n', text)
    if match is None:
        raise RuntimeError("Could not locate RetroUIScript preload.")

    preload = (
        'const SeatAvailabilityGlowScript := preload('
        '"res://scripts/study/seat_availability_glow.gd")\n'
    )

    return text[:match.end()] + preload + text[match.end():]


def ensure_vars(text: str) -> str:
    anchor = "var task_input: LineEdit\n"
    if anchor not in text:
        raise RuntimeError("Could not locate task_input variable.")

    additions = ""
    if "var session_setup_open :=" not in text:
        additions += "var session_setup_open := false\n"
    if "var session_setup_camera: Camera3D" not in text:
        additions += "var session_setup_camera: Camera3D\n"
    if "var session_tag_name :=" not in text:
        additions += 'var session_tag_name := "Study"\n'
    if "var session_focus_text :=" not in text:
        additions += 'var session_focus_text := ""\n'

    if additions:
        text = text.replace(anchor, anchor + additions, 1)
    return text


def reset_setup_state_on_room_build(text: str) -> str:
    marker = "func build_room(index: int) -> void:\n\tscreen = Screen.ROOM\n"
    replacement = (
        "func build_room(index: int) -> void:\n"
        "\tscreen = Screen.ROOM\n"
        "\tsession_setup_open = false\n"
        "\tsession_setup_camera = null\n"
    )

    if marker in text:
        return text.replace(marker, replacement, 1)

    if (
        "func build_room(index: int) -> void:\n"
        "\tscreen = Screen.ROOM\n"
        "\tsession_setup_open = false\n"
    ) in text:
        return text

    raise RuntimeError("Could not patch build_room() setup-state reset.")


def replace_helper_blocks(text: str) -> str:
    blocks = [
        (
            "# === STUDYTOWN FOCUSTOWN HELPERS START ===",
            "# === STUDYTOWN FOCUSTOWN HELPERS END ===",
        ),
        (
            "# === STUDYTOWN SEATED SESSION FLOW START ===",
            "# === STUDYTOWN SEATED SESSION FLOW END ===",
        ),
    ]

    for start_marker, end_marker in blocks:
        while start_marker in text:
            start = text.find(start_marker)
            end = text.find(end_marker, start)
            if end < 0:
                raise RuntimeError(f"Found {start_marker} without matching end marker.")
            end += len(end_marker)
            text = text[:start] + text[end:]

    anchor = "\nfunc _begin_focus("
    index = text.find(anchor)
    if index < 0:
        raise RuntimeError("Could not locate _begin_focus() for helper insertion.")

    return text[:index] + "\n" + HELPERS.rstrip() + "\n\n" + text[index + 1:]


def main() -> None:
    if not MAIN_PATH.is_file():
        raise FileNotFoundError(MAIN_PATH)

    if not GLOW_PATH.is_file():
        raise FileNotFoundError(
            "Install scripts/study/seat_availability_glow.gd first."
        )

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    backup(MAIN_PATH, timestamp)

    text = MAIN_PATH.read_text(encoding="utf-8")
    text = ensure_preloads(text)
    text = ensure_vars(text)
    text = reset_setup_state_on_room_build(text)

    for function_name, replacement in FUNCTIONS.items():
        text = replace_function(text, function_name, replacement, True)

    text = replace_helper_blocks(text)
    MAIN_PATH.write_text(text, encoding="utf-8")

    print("")
    print("# STUDYTOWN SEATED SESSION FLOW")
    print("")
    print("Available seats:    soft blinking white glow")
    print("Interaction:        walk to seat + press E")
    print("Seat transition:    player sits before setup appears")
    print("Camera:             pans to front / character framed right")
    print("Setup panel:        left side only; no HUD overlap")
    print("Timer slider:       5 minutes to 2 hours")
    print("Session tags:       Study / Reading / Work / Creative")
    print("Rewards:            1 focus/min +5 at 25+ minutes")
    print("Active timer:       compact top-right dark card")
    print("Completion:         matching rounded results card")
    print(f"Backup:             {BACKUP_DIR}")
    print("")
    print("DONE")
    print("")


if __name__ == "__main__":
    main()
