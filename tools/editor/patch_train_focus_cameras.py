#!/usr/bin/env python3
"""Patch StudyTown's Train focus-camera candidate offsets.

The Train contains seats that intentionally face the windows. The existing
Train camera pool in scripts/core/main.gd only places cameras in front of the
seated player, so every candidate for a window-facing seat lands outside the
carriage or behind a wall.

This patch keeps the existing front-facing candidates and adds interior rear /
over-shoulder candidates. It is idempotent and creates a timestamped backup.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
import re
import shutil


MAIN_PATH = Path("scripts/core/main.gd")
MARKER = "# Train window-facing seats also need interior rear / over-shoulder angles."

NEW_BLOCK = '''\tif room_id == "train":
\t\t# Train window-facing seats also need interior rear / over-shoulder angles.
\t\t#
\t\t# Positive Z offsets are the existing player-facing candidates. Negative Z
\t\t# offsets put the camera behind the player's facing direction, keeping it
\t\t# inside the carriage when a seat intentionally faces a window.
\t\toffsets = [
\t\t\t# Front / three-quarter views for inward-facing Train seats.
\t\t\tVector3(2.35, 2.65, 2.45),
\t\t\tVector3(-2.35, 2.60, 2.45),

\t\t\tVector3(1.10, 2.55, 3.85),
\t\t\tVector3(-1.10, 2.45, 3.70),

\t\t\tVector3(1.75, 2.90, 3.25),
\t\t\tVector3(-1.75, 2.80, 3.20),

\t\t\tVector3(0.45, 3.35, 3.60),
\t\t\tVector3(-0.45, 3.25, 3.55),

\t\t\t# Interior rear / over-shoulder views for window-facing Train seats.
\t\t\tVector3(1.90, 2.70, -2.75),
\t\t\tVector3(-1.90, 2.65, -2.75),

\t\t\tVector3(1.05, 2.60, -3.55),
\t\t\tVector3(-1.05, 2.55, -3.55),

\t\t\tVector3(2.45, 3.00, -2.50),
\t\t\tVector3(-2.45, 2.95, -2.50),

\t\t\tVector3(0.55, 3.30, -3.15),
\t\t\tVector3(-0.55, 3.25, -3.15),
\t\t]
'''

PATTERN = re.compile(
    r'\tif room_id == "train":\n'
    r'\t\toffsets = \[\n'
    r'.*?'
    r'\t\t\]\n'
    r'(?=\n\tvar basis := Basis\()',
    re.DOTALL,
)


def main() -> int:
    if not MAIN_PATH.is_file():
        print(f"ERROR: {MAIN_PATH} does not exist.")
        print("Run this from the StudyTown project root.")
        return 1

    source = MAIN_PATH.read_text(encoding="utf-8")

    if MARKER in source:
        print("Train focus-camera patch is already applied.")
        return 0

    patched, count = PATTERN.subn(
        NEW_BLOCK.rstrip("\n"),
        source,
        count=1,
    )

    if count != 1:
        print(
            "ERROR: Could not find exactly one Train focus-camera offsets block "
            "in scripts/core/main.gd."
        )
        print("No file was changed.")
        return 1

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    backup = MAIN_PATH.with_name(
        f"main_before_train_focus_camera_{timestamp}.gd"
    )

    shutil.copy2(
        MAIN_PATH,
        backup,
    )

    MAIN_PATH.write_text(
        patched,
        encoding="utf-8",
    )

    print("DONE")
    print(f"Patched: {MAIN_PATH}")
    print(f"Backup:  {backup}")
    print("Train focus cameras now support both inward- and window-facing seats.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
