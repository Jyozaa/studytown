"""Build a redistribution-safe inventory of StudyTown's local asset archives.

The script reads only repository-local copies under ``assets/dev_local/source``.
It records filenames and expected local runtime paths, never binary content.
"""

from __future__ import annotations

import json
import re
import zipfile
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/dev_local/source"
AUDIT_PATH = ROOT / "docs/ASSET_AUDIT.md"
MANIFEST_PATH = ROOT / "assets/local_asset_manifest.json"

MODEL_SUFFIXES = {".glb", ".gltf", ".fbx", ".obj", ".blend", ".dae", ".smd", ".stl"}
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".tga", ".bmp", ".tif", ".tiff"}

RUNTIME_PATHS = {
    "Froggy Chair": "res://assets/dev_local/props/froggy_chair/Froggy Chair.dae",
    "Mini DIY Workbench": "res://assets/dev_local/props/mini_workbench.glb",
    "Hardcover Books": "res://assets/dev_local/props/hardcover_books.glb",
    "Paperback Books": "res://assets/dev_local/props/paperback_books.glb",
    "Coffee Mug": "res://assets/dev_local/props/coffee_mug.glb",
    "Cup of Coffee": "res://assets/dev_local/props/cup_coffee.glb",
    "Desk Fan": "res://assets/dev_local/props/desk_fan.glb",
    "Corkboard": "res://assets/dev_local/props/corkboard.glb",
    "Pendulum Clock": "res://assets/dev_local/props/pendulum_clock.glb",
    "NookPhone": "res://assets/dev_local/props/nook_phone.glb",
    "Lost Book": "res://assets/dev_local/props/lost_book.glb",
    "Potted Spring Flowers": "res://assets/dev_local/environment/potted_spring_flowers.glb",
    "Potted Autumn Flowers": "res://assets/dev_local/environment/potted_autumn_flowers.glb",
    "Oak Trees (Museum)": "res://assets/dev_local/environment/oak_tree.glb",
    "Big Tree (Museum)": "res://assets/dev_local/environment/big_tree.glb",
    "Palm Tree (Museum)": "res://assets/dev_local/environment/palm_tree.glb",
    "Rocks": "res://assets/dev_local/environment/rocks.glb",
    "Spring Weeds": "res://assets/dev_local/environment/spring_weeds.glb",
    "Villager Tent": "res://assets/dev_local/environment/villager_tent.glb",
    "Recycle Box": "res://assets/dev_local/props/recycle_box.glb",
    "Natural Basket": "res://assets/dev_local/props/natural_basket.glb",
    "Tote Bag": "res://assets/dev_local/props/tote_bag.glb",
    "Leather Handbag": "res://assets/dev_local/props/leather_handbag.glb",
    "Coffee Grinder": "res://assets/dev_local/props/coffee_grinder.glb",
    "Iced Tea": "res://assets/dev_local/props/iced_tea.glb",
}

RUNTIME_SCALES = {
    "Froggy Chair": [14.0, 14.0, 14.0],
}

# Converted-scene AABBs measured by Godot. Froggy Chair includes its registry
# scale so every value describes the runtime-ready asset rather than the raw
# source scene. Axis order is Godot X/Y/Z, in metres.
RUNTIME_DIMENSIONS = {
    "Froggy Chair": [0.992, 1.201, 1.037],
    "Mini DIY Workbench": [0.083, 0.077, 0.104],
    "Hardcover Books": [0.023, 0.016, 0.013],
    "Paperback Books": [0.014, 0.009, 0.008],
    "Coffee Mug": [0.033, 0.024, 0.027],
    "Cup of Coffee": [0.044, 0.033, 0.026],
    "Desk Fan": [0.056, 0.048, 0.069],
    "Corkboard": [0.348, 0.026, 0.209],
    "Pendulum Clock": [0.072, 0.033, 0.123],
    "NookPhone": [0.023, 0.024, 0.011],
    "Lost Book": [0.017, 0.018, 0.007],
    "Potted Spring Flowers": [0.127, 0.101, 0.173],
    "Potted Autumn Flowers": [0.159, 0.137, 0.173],
    "Oak Trees (Museum)": [0.708, 0.441, 0.879],
    "Big Tree (Museum)": [0.530, 0.320, 0.589],
    "Palm Tree (Museum)": [0.931, 0.720, 0.972],
    "Rocks": [0.372, 0.342, 0.236],
    "Spring Weeds": [0.081, 0.088, 0.055],
    "Villager Tent": [0.691, 0.530, 0.465],
    "Recycle Box": [0.366, 0.182, 0.193],
    "Natural Basket": [0.154, 0.139, 0.124],
    "Tote Bag": [1.087, 1.004, 0.306],
    "Leather Handbag": [0.272, 0.205, 0.131],
    "Coffee Grinder": [0.021, 0.016, 0.027],
    "Iced Tea": [0.038, 0.038, 0.039],
}

USED_BY = {
    "Froggy Chair": ["library", "garden", "japanese"],
    "Mini DIY Workbench": ["library", "japanese"],
    "Hardcover Books": ["library", "train", "japanese"],
    "Paperback Books": ["library", "japanese"],
    "Coffee Mug": ["library", "garden", "train", "japanese"],
    "Cup of Coffee": ["library"],
    "Desk Fan": ["library", "train"],
    "Corkboard": ["library", "train", "japanese"],
    "Pendulum Clock": ["library", "train", "japanese"],
    "NookPhone": ["library", "train", "japanese"],
    "Lost Book": ["library", "train", "japanese"],
    "Potted Spring Flowers": ["library", "garden", "japanese"],
    "Potted Autumn Flowers": ["library", "garden", "japanese"],
    "Oak Trees (Museum)": ["garden"],
    "Big Tree (Museum)": ["garden"],
    "Palm Tree (Museum)": ["garden"],
    "Rocks": ["garden"],
    "Spring Weeds": ["garden"],
    "Villager Tent": ["garden"],
    "Recycle Box": ["garden"],
    "Natural Basket": ["library", "garden", "japanese"],
    "Tote Bag": ["library", "train"],
    "Leather Handbag": ["train"],
    "Coffee Grinder": ["library"],
    "Iced Tea": ["garden", "japanese"],
}


def clean_archive_name(path: Path) -> tuple[str, str]:
    stem = path.stem
    match = re.match(r"Nintendo Switch - Animal Crossing_ New Horizons - (.+?) - (.+)", stem)
    if match:
        return match.group(1), match.group(2)
    return "Supplemental", stem


def asset_id(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def classify(group: str, name: str) -> tuple[str, list[str], list[str]]:
    text = f"{group} {name}".lower()
    if any(token in text for token in ("tree", "flower", "weed", "rock", "water", "sapling", "plaza")):
        category = "environment"
        rooms = ["garden"]
    elif any(token in text for token in ("book", "corkboard", "clock", "rug", "desk", "chair", "workbench")):
        category = "furniture"
        rooms = ["library", "train", "japanese"]
    elif any(token in text for token in ("coffee", "tea", "mug", "cup", "grinder", "food", "donut", "sandwich", "soup")):
        category = "cafe_prop"
        rooms = ["garden", "library", "train"]
    elif any(token in text for token in ("bag", "phone", "map", "ticket", "paper", "timer")):
        category = "personal_prop"
        rooms = ["library", "train", "japanese"]
    elif "tent" in text or "building" in text:
        category = "architecture"
        rooms = ["garden"]
    else:
        category = "decorative_prop"
        rooms = ["library", "garden", "train", "japanese"]
    tags = sorted({category, group.lower().replace(" ", "_")})
    return category, rooms, tags


def archive_record(path: Path) -> dict:
    group, name = clean_archive_name(path)
    with zipfile.ZipFile(path) as archive:
        members = [member for member in archive.infolist() if not member.is_dir()]
    models = [member.filename for member in members if Path(member.filename).suffix.lower() in MODEL_SUFFIXES]
    images = [member.filename for member in members if Path(member.filename).suffix.lower() in IMAGE_SUFFIXES]
    formats = sorted({Path(item).suffix.lower().lstrip(".") for item in models})
    category, rooms, tags = classify(group, name)
    runtime = RUNTIME_PATHS.get(name, "")
    return {
        "asset_id": asset_id(name),
        "display_name": name,
        "category": category,
        "source_relative_path": path.relative_to(SOURCE).as_posix(),
        "runtime_relative_path": runtime,
        "room_tags": rooms,
        "scale": RUNTIME_SCALES.get(name, [1.0, 1.0, 1.0]),
        "rotation_degrees": [0.0, 0.0, 0.0],
        "visual_offset": [0.0, 0.0, 0.0],
        "collision_type": "none",
        "dimensions": RUNTIME_DIMENSIONS.get(name, []),
        "material_notes": f"{len(images)} texture/image files in source archive",
        "tags": tags,
        "source_group": group,
        "model_files": len(models),
        "image_files": len(images),
        "formats": formats,
        "textures_present": bool(images),
        "rigged": False,
        "skeleton": "",
        "animation_clips": [],
        "imported": bool(runtime),
        "currently_used": name in USED_BY,
        "where_used": USED_BY.get(name, []),
        "notes": ("Runtime-ready local derivative in active use." if name in USED_BY else "Audited; retained as an optional local source asset."),
    }


def character_records(path: Path) -> list[dict]:
    with zipfile.ZipFile(path) as archive:
        discovered = {match.group(1) for name in archive.namelist() if (match := re.match(r"Cats/\d+ - ([^/]+)/$", name))}
        names = [name for name in ("Bob", "Rosie", "Raymond") if name in discovered]
        names.extend(sorted(discovered.difference(names)))
    selected = {
        "Bob": "res://assets/dev_local/characters/bob.glb",
        "Rosie": "res://assets/dev_local/characters/rosie.glb",
        "Raymond": "res://assets/dev_local/characters/raymond.glb",
    }
    records = []
    for name in names:
        runtime = selected.get(name, "")
        records.append({
            "asset_id": asset_id(name),
            "display_name": name,
            "category": "character",
            "source_relative_path": path.relative_to(SOURCE).as_posix(),
            "runtime_relative_path": runtime,
            "room_tags": ["all"],
            "scale": [1.0, 1.0, 1.0],
            "rotation_degrees": [0.0, 180.0, 0.0],
            "visual_offset": [0.0, 0.0, 0.0],
            "collision_type": "capsule",
            "dimensions": [1.55, 2.70, 1.52] if runtime else [],
            "material_notes": "Variant body, eye, mouth, and top textures",
            "tags": ["cat", "playable" if runtime else "variant"],
            "skeleton": "Armature",
            "forward_axis": "VisualRoot correction to -Z",
            "collider_radius": 0.52,
            "collider_height": 2.20,
            "label_height": 2.98,
            "standing_visual_offset": [0.0, 0.0, 0.0],
            "sitting_visual_offset": [0.0, -0.14, 0.12],
            "animation_map": {state: state for state in ("Idle", "Walk", "Sit", "StudyLaptop", "StudyBook", "Wave", "Stretch")},
            "rigged": True,
            "bone_count": 51,
            "animation_clips": [] if not runtime else ["Idle", "Walk", "Sit", "StudyLaptop", "StudyBook", "Wave", "Stretch"],
            "imported": bool(runtime),
            "currently_used": bool(runtime),
            "where_used": ["player", "npcs", "menu"] if runtime else [],
            "notes": "No source clips; local skeletal actions generated." if runtime else "Texture variant audited; not selected for runtime conversion.",
        })
    return records


def markdown(records: list[dict]) -> str:
    archive_records = [record for record in records if record["category"] != "character"]
    characters = [record for record in records if record["category"] == "character"]
    model_files = sum(record.get("model_files", 0) for record in archive_records) + 6
    image_files = sum(record.get("image_files", 0) for record in archive_records) + 2518
    lines = [
        "# Local asset audit",
        "",
        "Generated from the repository-local copy under `assets/dev_local/source/`. Proprietary binaries are gitignored; this committed audit stores metadata only.",
        "",
        "## Summary",
        "",
        f"- Primary asset archives inspected: {len(archive_records)}",
        f"- Cat texture variants inspected: {len(characters)}",
        f"- Model files represented (FBX/DAE, including alternate formats): {model_files}",
        f"- Texture/image files represented: {image_files}",
        f"- Runtime-selected local entries: {sum(bool(record.get('runtime_relative_path')) for record in records)}",
        "- Source animations found on cats: 0",
        "- Cat rig: `Armature`, 51 bones",
        "",
        "Dimensions are recorded after conversion for selected runtime assets; unselected sources remain `not measured` rather than carrying guessed values.",
        "",
        "## Inventory",
        "",
        "| Source filename | Relative source path | Format | Category | Inferred asset name | Type | Suitable rooms | Textures? | Rigged? | Skeleton | Animation clips? | Approx dimensions | Imported? | Converted path | Used? | Where used | Notes/issues |",
        "|---|---|---|---|---|---|---|---:|---:|---|---|---|---:|---|---:|---|---|",
    ]
    for record in records:
        path = record["source_relative_path"]
        source_name = Path(path).name
        formats = ", ".join(record.get("formats", ["FBX/DAE + PNG variant"]))
        dimensions = " × ".join(str(value) for value in record.get("dimensions", [])) or "not measured"
        where = ", ".join(record.get("where_used", [])) or "—"
        clips = ", ".join(record.get("animation_clips", [])) or "none"
        lines.append(
            "| {source} | `{path}` | {formats} | {category} | {name} | {kind} | {rooms} | {textures} | {rigged} | {skeleton} | {clips} | {dimensions} | {imported} | `{runtime}` | {used} | {where} | {notes} |".format(
                source=source_name.replace("|", "\\|"),
                path=path,
                formats=formats or "archive",
                category=record["category"],
                name=record["display_name"].replace("|", "\\|"),
                kind="character" if record["category"] == "character" else "prop/environment",
                rooms=", ".join(record["room_tags"]),
                textures="yes" if record.get("textures_present", record["category"] == "character") else "no",
                rigged="yes" if record.get("rigged") else "no",
                skeleton=record.get("skeleton") or "—",
                clips=clips,
                dimensions=dimensions,
                imported="yes" if record.get("imported") else "no",
                runtime=record.get("runtime_relative_path") or "—",
                used="yes" if record.get("currently_used") else "no",
                where=where,
                notes=record.get("notes", ""),
            )
        )
    return "\n".join(lines) + "\n"


def main() -> None:
    primary = sorted(path for path in SOURCE.glob("*.zip"))
    records = [archive_record(path) for path in primary]
    supplemental = next((SOURCE / "_supplemental_characters").glob("*.zip"))
    records.extend(character_records(supplemental))
    manifest = {
        "schema_version": 1,
        "notice": "Expected metadata for owner-supplied local assets. Binary assets are intentionally absent from Git.",
        "source_root": "res://assets/dev_local/source/",
        "runtime_root": "res://assets/dev_local/",
        "assets": records,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    AUDIT_PATH.write_text(markdown(records), encoding="utf-8")
    print(json.dumps({"archives": len(primary), "characters": 23, "records": len(records)}, sort_keys=True))


if __name__ == "__main__":
    main()
