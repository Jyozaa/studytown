#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd()

MAIN_PATH = ROOT / "scripts" / "core" / "main.gd"
PROFILE_PATH = ROOT / "scripts" / "player" / "character_profile.gd"
LOADER_PATH = ROOT / "scripts" / "assets" / "character_loader.gd"

BACKUP_DIR = (
    ROOT
    / "assets"
    / "dev_local"
    / "backups"
    / "character_selection_ui"
)

SELECTION_PRELOAD = '''const CharacterSelectionScreenScript := preload(
\t"res://scripts/ui/character_selection_screen.gd"
)
'''

MENU_BUDDY_BLOCK = '''\tstack.add_child(_separator())

\tvar selected_profile = character_loader.get_profile(
\t\tclampi(
\t\t\tGameState.selected_character,
\t\t\t0,
\t\t\tmaxi(
\t\t\t\tcharacter_loader.profiles.size() - 1,
\t\t\t\t0
\t\t\t)
\t\t)
\t)

\tvar buddy_panel := PanelContainer.new()
\tbuddy_panel.add_theme_stylebox_override(
\t\t"panel",
\t\t_panel_style(
\t\t\tColor("#f7e8c8"),
\t\t\t18,
\t\t\t2,
\t\t\tColor("#ead09b")
\t\t)
\t)
\tstack.add_child(buddy_panel)

\tvar buddy_margin := MarginContainer.new()
\tbuddy_margin.add_theme_constant_override("margin_left", 14)
\tbuddy_margin.add_theme_constant_override("margin_right", 14)
\tbuddy_margin.add_theme_constant_override("margin_top", 10)
\tbuddy_margin.add_theme_constant_override("margin_bottom", 10)
\tbuddy_panel.add_child(buddy_margin)

\tvar buddy_row := HBoxContainer.new()
\tbuddy_row.add_theme_constant_override("separation", 12)
\tbuddy_margin.add_child(buddy_row)

\tvar buddy_text := VBoxContainer.new()
\tbuddy_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tbuddy_text.add_theme_constant_override("separation", 2)
\tbuddy_row.add_child(buddy_text)

\tbuddy_text.add_child(
\t\t_label(
\t\t\t"STUDY BUDDY",
\t\t\t11,
\t\t\tGREEN
\t\t)
\t)

\tbuddy_text.add_child(
\t\t_label(
\t\t\tselected_profile.display_name,
\t\t\t19,
\t\t\tINK
\t\t)
\t)

\tvar species_label: String = str(
\t\tselected_profile.species
\t).capitalize()

\tif species_label.is_empty():
\t\tspecies_label = "Villager"

\tbuddy_text.add_child(
\t\t_label(
\t\t\tspecies_label,
\t\t\t12,
\t\t\tCOCOA
\t\t)
\t)

\tvar change_character_button := _button(
\t\t"Change",
\t\tfalse
\t)
\tchange_character_button.custom_minimum_size = Vector2(
\t\t96,
\t\t48
\t)
\tchange_character_button.pressed.connect(
\t\t_open_character_selection
\t)
\tbuddy_row.add_child(
\t\tchange_character_button
\t)

\tstack.add_child(
\t\t_label(
\t\t\t"Where do you want to focus?",
\t\t\t20,
\t\t\tINK
\t\t)
\t)'''

OPEN_FUNCTION = '''func _open_character_selection() -> void:
\tif character_loader == null:
\t\treturn

\tvar selector := CharacterSelectionScreenScript.new()

\tui_root.add_child(
\t\tselector
\t)

\tselector.character_chosen.connect(
\t\t_select_character
\t)

\tselector.closed.connect(
\t\tshow_main_menu
\t)

\tselector.configure(
\t\tcharacter_loader,
\t\tGameState.selected_character
\t)


'''


def backup(path: Path, timestamp: str) -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    shutil.copy2(
        path,
        BACKUP_DIR
        / (
            path.stem
            + "_before_character_selection_"
            + timestamp
            + path.suffix
            + ".backup.txt"
        ),
    )


def patch_profile() -> None:
    text = PROFILE_PATH.read_text(encoding="utf-8")

    if 'var species := "villager"' not in text and '@export var species: String = "villager"' not in text:
        anchors = [
            'var display_name := "Study buddy"\n',
            '@export var display_name: String = ""\n',
        ]

        inserted = False

        for anchor in anchors:
            if anchor in text:
                species_line = (
                    'var species := "villager"\n'
                    if anchor.startswith("var ")
                    else '@export var species: String = "villager"\n'
                )

                text = text.replace(
                    anchor,
                    anchor + species_line,
                    1,
                )
                inserted = True
                break

        if not inserted:
            raise RuntimeError(
                "Could not locate the display_name field in character_profile.gd."
            )

    if "profile.species = species_value" not in text:
        anchor = '\tprofile.display_name = str(data.get("display_name", "Study buddy"))\n'

        if anchor not in text:
            multiline_anchor = (
                '\tprofile.display_name = str(\n'
                '\t\tdata.get(\n'
                '\t\t\t"display_name",\n'
                '\t\t\t"Study buddy"\n'
                '\t\t)\n'
                '\t)\n'
            )

            if multiline_anchor in text:
                anchor = multiline_anchor
            else:
                raise RuntimeError(
                    "Could not locate display_name assignment inside "
                    "CharacterProfile.from_dictionary()."
                )

        species_parse = (
            '\tvar species_value := str(\n'
            '\t\tdata.get(\n'
            '\t\t\t"species",\n'
            '\t\t\t""\n'
            '\t\t)\n'
            '\t).strip_edges().to_lower()\n'
            '\n'
            '\tif species_value.is_empty():\n'
            '\t\tvar tags_value: Variant = data.get(\n'
            '\t\t\t"tags",\n'
            '\t\t\t[]\n'
            '\t\t)\n'
            '\n'
            '\t\tif tags_value is Array:\n'
            '\t\t\tfor tag_variant: Variant in tags_value:\n'
            '\t\t\t\tvar tag_value := str(\n'
            '\t\t\t\t\ttag_variant\n'
            '\t\t\t\t).strip_edges().to_lower()\n'
            '\n'
            '\t\t\t\tif tag_value in [\n'
            '\t\t\t\t\t"cat",\n'
            '\t\t\t\t\t"alligator",\n'
            '\t\t\t\t\t"goat",\n'
            '\t\t\t\t\t"squirrel",\n'
            '\t\t\t\t\t"tiger",\n'
            '\t\t\t\t]:\n'
            '\t\t\t\t\tspecies_value = tag_value\n'
            '\t\t\t\t\tbreak\n'
            '\n'
            '\tif species_value.is_empty():\n'
            '\t\tspecies_value = "villager"\n'
            '\n'
            '\tprofile.species = species_value\n'
        )

        text = text.replace(
            anchor,
            anchor + species_parse,
            1,
        )

    PROFILE_PATH.write_text(
        text,
        encoding="utf-8",
    )

def patch_loader() -> None:
    text = LOADER_PATH.read_text(encoding="utf-8")

    text = text.replace(
        '"Local cat development models are absent; "',
        '"Local villager development models are absent; "',
    )

    LOADER_PATH.write_text(
        text,
        encoding="utf-8",
    )

def patch_main() -> None:
    text = MAIN_PATH.read_text(encoding="utf-8")

    if "CharacterSelectionScreenScript" not in text:
        anchor = (
            'const CharacterLoaderScript := preload('
            '"res://scripts/assets/character_loader.gd")\n'
        )

        if anchor not in text:
            raise RuntimeError(
                "Could not locate CharacterLoaderScript preload in main.gd."
            )

        text = text.replace(
            anchor,
            anchor + SELECTION_PRELOAD,
            1,
        )

    start = text.find("func _build_menu_ui() -> void:")

    if start < 0:
        raise RuntimeError(
            "Could not find _build_menu_ui() in main.gd."
        )

    end = text.find(
        "\nfunc _select_character(",
        start,
    )

    if end < 0:
        raise RuntimeError(
            "Could not locate end of _build_menu_ui()."
        )

    menu_block = text[start:end]

    section_pattern = re.compile(
        r'\tstack\.add_child\(_separator\(\)\)\n'
        r'.*?'
        r'\tstack\.add_child\(_label\("Where do you want to focus\?", 20, INK\)\)',
        re.DOTALL,
    )

    menu_block, count = section_pattern.subn(
        MENU_BUDDY_BLOCK,
        menu_block,
        count=1,
    )

    if count != 1:
        raise RuntimeError(
            "Could not replace the character-selection section in _build_menu_ui()."
        )

    text = text[:start] + menu_block + text[end:]

    if "func _open_character_selection() -> void:" not in text:
        select_function_index = text.find(
            "func _select_character("
        )

        if select_function_index < 0:
            raise RuntimeError(
                "Could not find _select_character() in main.gd."
            )

        text = (
            text[:select_function_index]
            + OPEN_FUNCTION
            + text[select_function_index:]
        )

    text = text.replace(
        "menu_character.position = Vector3(0.8, 0, 0)",
        "menu_character.position = Vector3(1.65, 0, 0)",
        1,
    )
    text = text.replace(
        "Vector3(0.8, -0.08, 0)",
        "Vector3(1.65, -0.08, 0)",
        1,
    )
    text = text.replace(
        "Vector3(0.8, 1.65, 0)",
        "Vector3(1.65, 1.65, 0)",
        1,
    )

    fallback_start = text.find(
        "func _create_fallback_character("
    )

    if fallback_start >= 0:
        fallback_end = text.find(
            "\nfunc ",
            fallback_start + 5,
        )

        if fallback_end < 0:
            fallback_end = len(text)

        fallback = text[
            fallback_start:fallback_end
        ]

        if "var fallback_variant := posmod(variant, 3)" not in fallback:
            anchor = '''\troot.name = "Character_%02d" % (variant + 1)
\tparent.add_child(root)'''

            replacement = '''\troot.name = "Character_%02d" % (variant + 1)
\tparent.add_child(root)

\tvar fallback_variant := posmod(
\t\tvariant,
\t\t3
\t)'''

            if anchor in fallback:
                fallback = fallback.replace(
                    anchor,
                    replacement,
                    1,
                )

        fallback = re.sub(
            r"\[variant\]",
            "[fallback_variant]",
            fallback,
        )

        text = (
            text[:fallback_start]
            + fallback
            + text[fallback_end:]
        )

    MAIN_PATH.write_text(
        text,
        encoding="utf-8",
    )


def main() -> None:
    paths = [
        MAIN_PATH,
        PROFILE_PATH,
        LOADER_PATH,
    ]

    for path in paths:
        if not path.is_file():
            raise FileNotFoundError(path)

    timestamp = datetime.now().strftime(
        "%Y-%m-%d_%H-%M-%S"
    )

    for path in paths:
        backup(
            path,
            timestamp,
        )

    patch_profile()
    patch_loader()
    patch_main()

    print("")
    print("STUDYTOWN CHARACTER SELECTION UI PATCHED V3")
    print("========================================")
    print("Flow:              character type -> variant -> main menu")
    print("Type cards:        actual 3D representative previews")
    print("Variant cards:     actual 3D character previews")
    print("Main menu:         selected model right / room selection left")
    print(f"Backups:           {BACKUP_DIR}")
    print("")


if __name__ == "__main__":
    main()
