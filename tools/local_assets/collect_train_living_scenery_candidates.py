#!/usr/bin/env python3
"""Collect Train exterior-liveliness source candidates for visual inspection.

Run from the StudyTown repository root. The script copies selected source model
families from asset_library/Model into Downloads and creates a ZIP ready to
upload back into ChatGPT for mesh/material inspection.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


DEFAULT_SOURCE = Path("asset_library/Model")
DEFAULT_OUTPUT = Path.home() / "Downloads" / "StudyTown Train Living Scenery Candidates"

# Small, deliberate candidate set. Families include recolor/material companion
# folders where available so candidates can be inspected with their variants.
CATEGORIES: dict[str, list[str]] = {
    "01_watercraft": [
        "StrcWherearenBoatA00",
    ],
    "02_water_life": [
        "FishKoi",
        "FishNishikigoi",
        "FishAji",
        "FishAyu",
        "FishKingyo",
        "FishSuzuki",
    ],
    "03_water_props": [
        "FtrFloat",
        "FtrLifebelt",
        "FtrTetrapod",
        "FldBuoy",
        "FtrBuoy",
    ],
    "04_birds_and_air": [
        "BbsBirdDay",
        "BbsBirdDayWherearen",
        "BbsBirdNight",
        "BbsBirdNightWherearen",
        "Balloon00",
        "StrcPlaneA00",
    ],
    "05_landmarks": [
        "FtrLighthouse",
        "CommuneObjWindmill01",
    ],
    "06_countryside_motion": [
        "FtrTractor",
        "FtrLawnmower",
        "FtrCityCycle",
    ],
    "07_atmosphere": [
        "InsectHotaru",
        "InsectFeather",
        "InsectAutumnLeaf",
    ],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--no-zip", action="store_true")
    return parser.parse_args()


def normalise_family(name: str) -> str:
    return name.removesuffix(".Nin_NX_NVN")


def family_matches(source: Path, family: str) -> list[Path]:
    """Return base + companion/recolor folders belonging to a family."""
    matches: list[Path] = []
    family_lower = family.lower()

    for entry in source.iterdir():
        if not entry.is_dir():
            continue
        stem = normalise_family(entry.name)
        stem_lower = stem.lower()

        # Exact model plus known companion naming patterns such as ReBody,
        # ReFabric, ReParts, etc. Prefix matching is intentional for FldBuoy /
        # FtrBuoy because exact buoy family names vary across extracted packs.
        if (
            stem_lower == family_lower
            or stem_lower.startswith(family_lower + "re")
            or (family_lower in {"fldbuoy", "ftrbuoy"} and stem_lower.startswith(family_lower))
        ):
            matches.append(entry)

    return sorted(matches, key=lambda p: p.name.lower())


def copy_candidate(src: Path, category_dir: Path) -> tuple[int, int]:
    dst = category_dir / src.name
    shutil.copytree(src, dst, copy_function=shutil.copy2)

    file_count = 0
    byte_count = 0
    for child in dst.rglob("*"):
        if child.is_file():
            file_count += 1
            byte_count += child.stat().st_size
    return file_count, byte_count


def human_bytes(value: int) -> str:
    units = ["B", "KB", "MB", "GB"]
    amount = float(value)
    for unit in units:
        if amount < 1024.0 or unit == units[-1]:
            return f"{amount:.1f} {unit}"
        amount /= 1024.0
    return f"{value} B"


def main() -> int:
    args = parse_args()
    source = args.source.expanduser().resolve()
    output = args.output.expanduser().resolve()

    if not source.is_dir():
        raise SystemExit(f"Source folder not found: {source}")

    # Safety: only replace the specific output folder chosen by this script.
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)

    manifest_lines: list[str] = [
        "StudyTown Train Living Scenery Candidates",
        f"Source: {source}",
        "",
    ]

    copied_names: set[str] = set()
    total_folders = 0
    total_files = 0
    total_bytes = 0

    for category, families in CATEGORIES.items():
        category_dir = output / category
        category_dir.mkdir(parents=True, exist_ok=True)
        manifest_lines.append(f"[{category}]")

        category_found = False
        for family in families:
            matches = family_matches(source, family)
            if not matches:
                manifest_lines.append(f"MISSING  {family}")
                continue

            for match in matches:
                if match.name in copied_names:
                    continue
                copied_names.add(match.name)
                files, size = copy_candidate(match, category_dir)
                total_folders += 1
                total_files += files
                total_bytes += size
                category_found = True
                manifest_lines.append(
                    f"COPIED   {match.name}  ({files} files, {human_bytes(size)})"
                )

        if not category_found:
            # Keep empty category out of the final archive.
            category_dir.rmdir()
        manifest_lines.append("")

    manifest_lines.extend(
        [
            "[summary]",
            f"Folders copied: {total_folders}",
            f"Files copied: {total_files}",
            f"Total copied size: {human_bytes(total_bytes)}",
        ]
    )
    (output / "candidate_manifest.txt").write_text(
        "\n".join(manifest_lines) + "\n", encoding="utf-8"
    )

    print(f"Created candidate folder: {output}")
    print(f"Copied {total_folders} source folders ({human_bytes(total_bytes)}).")

    if not args.no_zip:
        zip_base = output.parent / output.name
        zip_path = Path(shutil.make_archive(str(zip_base), "zip", root_dir=output.parent, base_dir=output.name))
        print(f"Created ZIP: {zip_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
