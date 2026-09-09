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
    / "main_dashboard_ui"
)

MENU_WORLD = r'''func _build_menu_world() -> void:
	# The main page is now a UI-first dashboard. Keep only a quiet background
	# world/camera alive behind the CanvasLayer.
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

MENU_UI = r'''func _build_menu_ui() -> void:
	var selected_room := clampi(
		GameState.selected_room,
		0,
		2
	)

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

	var room_short_names := [
		"Library",
		"Garden",
		"Train",
	]

	var room_taglines := [
		"Quiet desks, shelves and warm lamps.",
		"Fresh air, cafe tables and open space.",
		"Study compartments with moving scenery.",
	]

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = Color("#141519")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(background)

	var sidebar := Panel.new()
	sidebar.position = Vector2(0, 0)
	sidebar.size = Vector2(220, 720)
	sidebar.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#17181d"),
			Color("#23252b"),
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

	var brand_avatar_panel := Panel.new()
	brand_avatar_panel.position = Vector2(18, 18)
	brand_avatar_panel.size = Vector2(52, 52)
	brand_avatar_panel.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#262933"),
			Color("#353944"),
			2,
			14
		)
	)
	sidebar.add_child(brand_avatar_panel)

	var brand_avatar := RetroCharacterPreviewScript.make_character_preview(
		character_loader,
		selected_index,
		Vector2i(46, 46),
		true
	)
	brand_avatar.position = Vector2(3, 3)
	brand_avatar.size = Vector2(46, 46)
	brand_avatar_panel.add_child(brand_avatar)

	var eyebrow := RetroUIScript.label(
		"NEVER STUDY ALONE",
		8,
		Color("#77aaff"),
		true
	)
	eyebrow.position = Vector2(80, 20)
	eyebrow.size = Vector2(128, 16)
	sidebar.add_child(eyebrow)

	var brand := RetroUIScript.label(
		"StudyTown",
		18,
		RetroUIScript.WHITE,
		true
	)
	brand.position = Vector2(80, 36)
	brand.size = Vector2(128, 30)
	sidebar.add_child(brand)

	var divider := HSeparator.new()
	divider.position = Vector2(18, 82)
	divider.size = Vector2(184, 2)
	divider.modulate = Color("#30333b")
	sidebar.add_child(divider)

	var home := Button.new()
	home.text = "⌂   Home"
	home.position = Vector2(18, 104)
	home.size = Vector2(184, 44)
	RetroUIScript.apply_sidebar_button(
		home,
		true
	)
	sidebar.add_child(home)

	var buddy := Button.new()
	buddy.text = "♙   Study Buddy"
	buddy.position = Vector2(18, 164)
	buddy.size = Vector2(184, 42)
	RetroUIScript.apply_sidebar_button(buddy)
	buddy.pressed.connect(_open_character_selection)
	sidebar.add_child(buddy)

	var stats := Button.new()
	stats.text = "▥   Stats"
	stats.position = Vector2(18, 216)
	stats.size = Vector2(184, 42)
	RetroUIScript.apply_sidebar_button(stats)
	stats.disabled = true
	stats.tooltip_text = "Coming soon"
	sidebar.add_child(stats)

	var profile := Button.new()
	profile.text = "○   Profile"
	profile.position = Vector2(18, 268)
	profile.size = Vector2(184, 42)
	RetroUIScript.apply_sidebar_button(profile)
	profile.pressed.connect(_open_character_selection)
	sidebar.add_child(profile)

	var settings := Button.new()
	settings.text = "⚙   Settings"
	settings.position = Vector2(18, 320)
	settings.size = Vector2(184, 42)
	RetroUIScript.apply_sidebar_button(settings)
	settings.pressed.connect(_open_scrapbook_settings)
	sidebar.add_child(settings)

	var joined_label := RetroUIScript.label(
		"YOUR STUDYTOWN",
		9,
		RetroUIScript.MUTED,
		true
	)
	joined_label.position = Vector2(20, 586)
	joined_label.size = Vector2(180, 20)
	sidebar.add_child(joined_label)

	var selected_profile: CharacterProfile = character_loader.get_profile(
		selected_index
	)

	var buddy_chip := Panel.new()
	buddy_chip.position = Vector2(18, 614)
	buddy_chip.size = Vector2(184, 64)
	buddy_chip.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1e2026"),
			Color("#30333b"),
			2,
			16
		)
	)
	sidebar.add_child(buddy_chip)

	var mini_preview := RetroCharacterPreviewScript.make_character_preview(
		character_loader,
		selected_index,
		Vector2i(46, 46),
		true
	)
	mini_preview.position = Vector2(8, 9)
	mini_preview.size = Vector2(46, 46)
	buddy_chip.add_child(mini_preview)

	var buddy_name := RetroUIScript.label(
		selected_profile.display_name,
		11,
		RetroUIScript.WHITE,
		true
	)
	buddy_name.position = Vector2(64, 12)
	buddy_name.size = Vector2(110, 20)
	buddy_chip.add_child(buddy_name)

	var buddy_species := RetroUIScript.label(
		selected_profile.species.capitalize(),
		9,
		Color("#6fc878"),
		true
	)
	buddy_species.position = Vector2(64, 34)
	buddy_species.size = Vector2(110, 18)
	buddy_chip.add_child(buddy_species)

	var stats_card := Panel.new()
	stats_card.position = Vector2(246, 20)
	stats_card.size = Vector2(1014, 108)
	stats_card.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#181a20"),
			Color("#373a43"),
			2,
			24,
			4,
			Vector2(0, 4)
		)
	)
	ui_root.add_child(stats_card)

	var stat_values := [
		str(GameState.focus_coins),
		"3",
		str(character_loader.profiles.size()),
	]

	var stat_labels := [
		"focus points",
		"places",
		"available buddies",
	]

	var stat_icons := [
		"●",
		"▤",
		"♙",
	]

	for i: int in range(3):
		var x := 28 + float(i) * 330.0

		var icon_panel := Panel.new()
		icon_panel.position = Vector2(x, 24)
		icon_panel.size = Vector2(52, 52)
		icon_panel.add_theme_stylebox_override(
			"panel",
			RetroUIScript.panel_style(
				(
					Color("#ff6c68")
					if i == 0
					else Color("#22252b")
				),
				Color("#30333b"),
				2,
				16
			)
		)
		stats_card.add_child(icon_panel)

		var icon := RetroUIScript.label(
			stat_icons[i],
			20,
			RetroUIScript.WHITE,
			true
		)
		icon.position = Vector2(12, 10)
		icon.size = Vector2(28, 30)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_panel.add_child(icon)

		var value := RetroUIScript.label(
			stat_values[i],
			28,
			RetroUIScript.WHITE,
			true
		)
		value.position = Vector2(x + 68, 18)
		value.size = Vector2(190, 38)
		stats_card.add_child(value)

		var caption := RetroUIScript.label(
			stat_labels[i],
			11,
			Color("#c9cbd2"),
			true
		)
		caption.position = Vector2(x + 68, 57)
		caption.size = Vector2(220, 24)
		stats_card.add_child(caption)

	var featured := Panel.new()
	featured.position = Vector2(246, 148)
	featured.size = Vector2(1014, 286)
	featured.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#1c1e24"),
			Color("#373a43"),
			2,
			24
		)
	)
	ui_root.add_child(featured)

	var featured_preview_holder := Control.new()
	featured_preview_holder.position = Vector2(18, 18)
	featured_preview_holder.size = Vector2(978, 250)
	featured_preview_holder.clip_contents = true
	featured.add_child(featured_preview_holder)

	var featured_preview := RoomPreviewScript.make_preview(
		room_ids[selected_room],
		Vector2i(978, 250)
	)
	featured_preview.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	featured_preview_holder.add_child(featured_preview)

	var live_chip := Panel.new()
	live_chip.position = Vector2(34, 32)
	live_chip.size = Vector2(74, 30)
	live_chip.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color("#ff6b68"),
			Color("#ff8582"),
			1,
			15
		)
	)
	featured.add_child(live_chip)

	var live_text := RetroUIScript.label(
		"● OPEN",
		9,
		RetroUIScript.WHITE,
		true
	)
	live_text.position = Vector2(8, 6)
	live_text.size = Vector2(58, 18)
	live_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	live_chip.add_child(live_text)

	var featured_info := Panel.new()
	featured_info.position = Vector2(676, 34)
	featured_info.size = Vector2(298, 72)
	featured_info.add_theme_stylebox_override(
		"panel",
		RetroUIScript.panel_style(
			Color(0.96, 0.96, 0.97, 0.94),
			Color(1.0, 1.0, 1.0, 0.86),
			1,
			30
		)
	)
	featured.add_child(featured_info)

	var featured_name := RetroUIScript.label(
		room_names[selected_room],
		14,
		Color("#2a2c31"),
		true
	)
	featured_name.position = Vector2(18, 10)
	featured_name.size = Vector2(180, 24)
	featured_info.add_child(featured_name)

	var featured_sub := RetroUIScript.label(
		room_taglines[selected_room],
		9,
		Color("#777b84")
	)
	featured_sub.position = Vector2(18, 36)
	featured_sub.size = Vector2(190, 24)
	featured_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	featured_info.add_child(featured_sub)

	var featured_join := Button.new()
	featured_join.text = "JOIN"
	featured_join.position = Vector2(214, 18)
	featured_join.size = Vector2(70, 38)
	RetroUIScript.apply_button(
		featured_join,
		false,
		false,
		false,
		true,
		18
	)
	featured_join.pressed.connect(
		_enter_room.bind(selected_room)
	)
	featured_info.add_child(featured_join)

	var section_icon := RetroUIScript.label(
		"▤",
		20,
		RetroUIScript.BLUE,
		true
	)
	section_icon.position = Vector2(248, 452)
	section_icon.size = Vector2(34, 28)
	ui_root.add_child(section_icon)

	var section_title := RetroUIScript.label(
		"StudyTown Places",
		19,
		RetroUIScript.WHITE,
		true
	)
	section_title.position = Vector2(286, 448)
	section_title.size = Vector2(300, 34)
	ui_root.add_child(section_title)

	var section_subtitle := RetroUIScript.label(
		"Pick a room, take a seat, then start your focus session.",
		10,
		Color("#b5b8c1")
	)
	section_subtitle.position = Vector2(286, 479)
	section_subtitle.size = Vector2(520, 24)
	ui_root.add_child(section_subtitle)

	for i: int in range(3):
		var card := Panel.new()
		card.position = Vector2(
			246 + float(i) * 338.0,
			506
		)
		card.size = Vector2(320, 196)
		card.add_theme_stylebox_override(
			"panel",
			RetroUIScript.panel_style(
				Color("#191b20"),
				Color("#373a43"),
				2,
				22,
				3,
				Vector2(0, 3)
			)
		)
		ui_root.add_child(card)

		var preview_holder := Control.new()
		preview_holder.position = Vector2(12, 12)
		preview_holder.size = Vector2(296, 92)
		preview_holder.clip_contents = true
		card.add_child(preview_holder)

		var preview := RoomPreviewScript.make_preview(
			room_ids[i],
			Vector2i(296, 92)
		)
		preview.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		preview_holder.add_child(preview)

		var title := RetroUIScript.label(
			room_short_names[i],
			14,
			RetroUIScript.WHITE,
			true
		)
		title.position = Vector2(14, 112)
		title.size = Vector2(190, 26)
		card.add_child(title)

		var tagline := RetroUIScript.label(
			room_taglines[i],
			9,
			Color("#8fd28e"),
			true
		)
		tagline.position = Vector2(14, 137)
		tagline.size = Vector2(180, 20)
		tagline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_child(tagline)

		var join := Button.new()
		join.text = "JOIN"
		join.position = Vector2(214, 126)
		join.size = Vector2(90, 48)
		RetroUIScript.apply_button(
			join,
			false,
			false,
			false,
			true,
			20
		)
		join.pressed.connect(
			_enter_room.bind(i)
		)
		card.add_child(join)

	# Deliberately no Start Session control on the main page.
	# Session setup only opens from the existing StudySpot interaction flow.
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
            + "_before_main_dashboard_"
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
            f"Could not find {function_name}() in main.gd"
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
    if "RetroUIScript" not in text:
        raise RuntimeError(
            "RetroUIScript is missing. Install retro_ui_v3.gd first."
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
            "RoomPreviewScript preload is missing from main.gd."
        )

    return text


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

    text = replace_function(
        text,
        "_build_menu_world",
        MENU_WORLD,
    )
    text = replace_function(
        text,
        "_build_menu_ui",
        MENU_UI,
    )

    MAIN_PATH.write_text(
        text,
        encoding="utf-8",
    )

    print("")
    print("# STUDYTOWN MAIN DASHBOARD UI")
    print("")
    print("Main page:        dark app-style dashboard")
    print("Sidebar:          Home / Buddy / Stats / Profile / Settings")
    print("Top card:         focus / places / buddy stats")
    print("Featured place:   dynamic selected-room preview")
    print("Room cards:       Library / Garden / Train")
    print("Buttons:          tactile push-down interaction")
    print("Start Session:    seat interaction only")
    print(f"Backup:           {BACKUP_DIR}")
    print("")
    print("DONE")
    print("")


if __name__ == "__main__":
    main()
