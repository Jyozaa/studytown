#!/usr/bin/env python3
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path.cwd()
MAIN_PATH = ROOT / "scripts" / "core" / "main.gd"

REMOVE_DIRS = [
    ROOT / "assets" / "ui_elements",
]

REMOVE_FILES = [
    ROOT / "scripts" / "ui" / "scrapbook_ui.gd",
    ROOT / "scripts" / "ui" / "stationery_ui.gd",
    ROOT / "scripts" / "ui" / "character_selection_screen_scrapbook.gd",
    ROOT / "scripts" / "ui" / "character_selection_screen_handmade.gd",
    ROOT / "assets" / "dev_local" / "room_layouts" / "main_menu.tscn",
    ROOT / "tools" / "editor" / "apply_stationery_ui.py",
    ROOT / "tools" / "editor" / "apply_scrapbook_ui.py",
    ROOT / "tools" / "editor" / "apply_main_menu_character_ui_v2.py",
]


def main() -> None:
    if not MAIN_PATH.is_file():
        raise FileNotFoundError(MAIN_PATH)

    main_text = MAIN_PATH.read_text(
        encoding="utf-8"
    )

    if "RetroUIScript" not in main_text:
        raise RuntimeError(
            "Retro UI has not been applied yet. "
            "Run apply_retro_database_ui.py first."
        )

    if "ScrapbookUIScript" in main_text:
        raise RuntimeError(
            "main.gd still references ScrapbookUIScript. "
            "Cleanup aborted."
        )

    if "StationeryUIScript" in main_text:
        raise RuntimeError(
            "main.gd still references StationeryUIScript. "
            "Cleanup aborted."
        )

    removed: list[str] = []

    for path in REMOVE_FILES:
        if path.is_file():
            path.unlink()
            removed.append(
                str(path.relative_to(ROOT))
            )

    for path in REMOVE_DIRS:
        if path.is_dir():
            shutil.rmtree(path)
            removed.append(
                str(path.relative_to(ROOT)) + "/"
            )

    print("")
    print("# STUDYTOWN OLD UI CLEANUP")
    print("")

    if removed:
        for item in removed:
            print("removed:", item)
    else:
        print("Nothing old remained to remove.")

    print("")
    print("Retro UI files were kept.")
    print("Room scenes and gameplay assets were untouched.")
    print("DONE")
    print("")


if __name__ == "__main__":
    main()
