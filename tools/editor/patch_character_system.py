#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd()
MAIN_PATH = ROOT / "scripts" / "core" / "main.gd"
GAME_STATE_PATH = ROOT / "autoload" / "game_state.gd"
LOADER_PATH = ROOT / "scripts" / "assets" / "character_loader.gd"
BACKUP_DIR = ROOT / "assets" / "dev_local" / "backups" / "character_pack"

OLD_PICKER = """\tvar chars := HBoxContainer.new()
\tchars.add_theme_constant_override("separation", 10)
\tstack.add_child(chars)
\tvar char_names := ["Bob", "Rosie", "Raymond"]
\tfor i in 3:
\t\tvar b := _button(char_names[i], i == GameState.selected_character)
\t\tb.custom_minimum_size = Vector2(104, 52)
\t\tb.pressed.connect(_select_character.bind(i))
\t\tchars.add_child(b)"""

NEW_PICKER = """\t# Character selection is manifest-driven so every staged villager variant is
\t# selectable without hard-coding names into the UI.
\tvar character_picker := OptionButton.new()
\tcharacter_picker.custom_minimum_size = Vector2(0, 52)
\tcharacter_picker.add_theme_font_size_override("font_size", 16)

\tvar character_count: int = character_loader.profiles.size()

\tif character_count <= 0:
\t\tcharacter_picker.add_item("Character assets not generated yet", 0)
\t\tcharacter_picker.set_item_disabled(0, true)
\telse:
\t\tfor character_index: int in range(character_count):
\t\t\tvar profile: CharacterProfile = character_loader.get_profile(
\t\t\t\tcharacter_index
\t\t\t)

\t\t\tcharacter_picker.add_item(
\t\t\t\tprofile.display_name,
\t\t\t\tcharacter_index
\t\t\t)

\t\tvar selected_index: int = clampi(
\t\t\tGameState.selected_character,
\t\t\t0,
\t\t\tcharacter_count - 1
\t\t)

\t\tGameState.selected_character = selected_index
\t\tcharacter_picker.select(selected_index)
\t\tcharacter_picker.item_selected.connect(_select_character)

\tstack.add_child(character_picker)

\tvar character_count_label := _label(
\t\t"%d villagers available" % character_count,
\t\t13,
\t\tCOCOA
\t)
\tstack.add_child(character_count_label)"""


def backup(path: Path, timestamp: str) -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(
        path,
        BACKUP_DIR
        / f"{path.stem}_before_character_pack_{timestamp}{path.suffix}",
    )


def patch_main() -> None:
    text = MAIN_PATH.read_text(encoding="utf-8")

    if NEW_PICKER not in text:
        if OLD_PICKER not in text:
            raise RuntimeError(
                "Could not locate the current hard-coded character picker "
                "in scripts/core/main.gd."
            )
        text = text.replace(OLD_PICKER, NEW_PICKER, 1)

    fallback_start = text.find("func _create_fallback_character(")

    if fallback_start < 0:
        raise RuntimeError(
            "Could not find _create_fallback_character() in main.gd."
        )

    fallback_end = text.find("\nfunc ", fallback_start + 5)
    if fallback_end < 0:
        fallback_end = len(text)

    block = text[fallback_start:fallback_end]

    if "var fallback_variant := posmod(variant, 3)" not in block:
        anchor = """\troot.name = "Character_%02d" % (variant + 1)
\tparent.add_child(root)"""

        replacement = """\troot.name = "Character_%02d" % (variant + 1)
\tparent.add_child(root)

\t# Public fallback art still has three palettes. Local playable characters are
\t# no longer limited to three, so wrap only the fallback palette index.
\tvar fallback_variant := posmod(variant, 3)"""

        if anchor not in block:
            raise RuntimeError(
                "Could not locate fallback-character setup anchor."
            )

        block = block.replace(anchor, replacement, 1)

    block = re.sub(r"\[variant\]", "[fallback_variant]", block)

    text = text[:fallback_start] + block + text[fallback_end:]
    MAIN_PATH.write_text(text, encoding="utf-8")


def patch_game_state() -> None:
    text = GAME_STATE_PATH.read_text(encoding="utf-8")

    old = (
        'selected_character = clampi(int(data.get("selected_character", 0)), 0, 2)'
    )
    new = (
        'selected_character = maxi(0, int(data.get("selected_character", 0)))'
    )

    if new not in text:
        if old not in text:
            raise RuntimeError(
                "Could not locate the old 0..2 character save clamp."
            )
        text = text.replace(old, new, 1)

    GAME_STATE_PATH.write_text(text, encoding="utf-8")


def patch_loader() -> None:
    text = LOADER_PATH.read_text(encoding="utf-8")
    text = text.replace(
        '"Local cat development models are absent; "',
        '"Local villager development models are absent; "',
    )
    LOADER_PATH.write_text(text, encoding="utf-8")


def main() -> None:
    for path in [MAIN_PATH, GAME_STATE_PATH, LOADER_PATH]:
        if not path.is_file():
            raise FileNotFoundError(path)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

    for path in [MAIN_PATH, GAME_STATE_PATH, LOADER_PATH]:
        backup(path, timestamp)

    patch_main()
    patch_game_state()
    patch_loader()

    print("")
    print("STUDYTOWN CHARACTER SYSTEM PATCHED")
    print("==================================")
    print("main.gd:          dynamic manifest-driven character picker")
    print("game_state.gd:    removed old 3-character save clamp")
    print("character_loader: generic villager warning")
    print(f"Backups:          {BACKUP_DIR}")
    print("")


if __name__ == "__main__":
    main()
