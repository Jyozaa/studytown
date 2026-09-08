#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import shutil
import zipfile
from datetime import datetime
from io import BytesIO
from pathlib import Path

PROJECT_ROOT = Path.cwd()
SOURCE_ROOT = PROJECT_ROOT / "assets" / "dev_local" / "source" / "character_pack"
RUNTIME_ROOT = PROJECT_ROOT / "assets" / "dev_local" / "characters"
CATALOG_PATH = PROJECT_ROOT / "assets" / "dev_local" / "character_catalog.json"
MANIFEST_PATH = PROJECT_ROOT / "assets" / "local_asset_manifest.json"
BACKUP_ROOT = PROJECT_ROOT / "assets" / "dev_local" / "backups" / "character_pack"

ANIMATION_STATES = [
    "Idle", "Walk", "Sit", "SeatedIdle", "StudyLaptop", "StudyBook",
    "ArmchairSeatedIdle", "ArmchairStudyLaptop", "ArmchairStudyBook",
    "FloorStudy", "TrainStudy", "Resting", "Wave", "Stretch", "Cheer",
]

PACK_DEFINITIONS = [
    {
        "match": "Villagers - Cats.zip",
        "key": "cats",
        "species": "cat",
        "villager_root": "Cats",
        "default_model": "Cats/Cat.fbx",
        "special_models": {
            "Ankha": "Cats/CatAnkha.fbx",
            "Raymond": "Cats/CatRaymond.fbx",
        },
    },
    {
        "match": "Alligators _ Crocodiles.zip",
        "key": "alligators",
        "species": "alligator",
        "villager_root": "Animal Crossing - New Horizons/Alligators",
        "default_model": "Animal Crossing - New Horizons/Alligators/Alligator.FBX",
        "special_models": {
            "Drago": "Animal Crossing - New Horizons/Alligators/AlligatorDrago.FBX",
        },
    },
    {
        "match": "Villagers - Goats.zip",
        "key": "goats",
        "species": "goat",
        "villager_root": "Goats",
        "default_model": "Goats/NpcNmlGoa.fbx",
        "special_models": {
            "Billy": "Goats/NpcNmlGoaBillyGruff.fbx",
            "Gruff": "Goats/NpcNmlGoaBillyGruff.fbx",
            "Velma": "Goats/NpcNmlGoaVelma.fbx",
        },
    },
    {
        "match": "Villagers (Update) - Cece.zip",
        "key": "cece",
        "species": "squirrel",
        "villager_root": "",
        "default_model": "Cece/NpcNmlSqu19.fbx",
        "special_models": {},
        "single_character": "Cece",
        "single_texture_dir": "Cece",
    },
    {
        "match": "Villagers - Tigers.zip",
        "key": "tigers",
        "species": "tiger",
        "villager_root": "Animal Crossing - New Horizons/Tigers",
        "default_model": "Animal Crossing - New Horizons/Tigers/Tiger.FBX",
        "special_models": {},
    },
]

SPECIES_COLLIDERS = {
    "cat": 0.52,
    "alligator": 0.60,
    "goat": 0.52,
    "squirrel": 0.52,
    "tiger": 0.60,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--archive",
        default=str(Path.home() / "Downloads" / "characters.zip"),
    )
    return parser.parse_args()


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")


def find_nested_archive(outer: zipfile.ZipFile, match: str) -> str:
    candidates = [
        name for name in outer.namelist()
        if name.endswith(match) and not name.startswith("__MACOSX/")
    ]
    if len(candidates) != 1:
        raise RuntimeError(
            f"Expected exactly one nested archive ending in {match!r}; found {len(candidates)}."
        )
    return candidates[0]


def discover_numbered_characters(
    extracted_pack_root: Path,
    villager_root: str,
) -> list[tuple[int, str, Path]]:
    root = extracted_pack_root / villager_root
    if not root.is_dir():
        raise RuntimeError(f"Villager root not found after extraction: {root}")

    results: list[tuple[int, str, Path]] = []
    for child in root.iterdir():
        if not child.is_dir():
            continue
        match = re.match(r"^(\d\d) - (.+)$", child.name)
        if match:
            results.append((int(match.group(1)), match.group(2).strip(), child))

    return sorted(results, key=lambda item: item[0])


def relative_project_path(path: Path) -> str:
    return path.resolve().relative_to(PROJECT_ROOT.resolve()).as_posix()


def manifest_entry(record: dict) -> dict:
    species = record["species"]
    return {
        "asset_id": record["character_id"],
        "character_id": record["character_id"],
        "display_name": record["display_name"],
        "category": "character",
        "source_relative_path": record["source_archive_name"],
        "runtime_relative_path": (
            "res://assets/dev_local/characters/" + record["character_id"] + ".glb"
        ),
        "room_tags": ["all"],
        "scale": [1.0, 1.0, 1.0],
        "rotation_degrees": [0.0, 180.0, 0.0],
        "visual_offset": [0.0, 0.0, 0.0],
        "collision_type": "capsule",
        "material_notes": (
            f"{species.title()} villager variant textures from the user-supplied character pack"
        ),
        "tags": [species, "playable", "character_pack"],
        "skeleton": "Armature",
        "forward_axis": "VisualRoot correction to canonical gameplay -Z",
        "collider_radius": SPECIES_COLLIDERS.get(species, 0.52),
        "collider_height": 2.20,
        "collider_y_offset": 1.10,
        "label_height": 2.98,
        "standing_visual_offset": [0.0, 0.0, 0.0],
        "sitting_visual_offset": [0.0, -0.14, 0.12],
        "animation_map": {state: state for state in ANIMATION_STATES},
        "rigged": True,
        "animation_clips": list(ANIMATION_STATES),
        "imported": True,
        "currently_used": True,
        "where_used": ["player", "npcs", "menu"],
        "notes": (
            "StudyTown generates the same skeletal action set used by the previous characters."
        ),
    }


def patch_manifest(records: list[dict]) -> None:
    if not MANIFEST_PATH.is_file():
        raise RuntimeError(f"Manifest not found: {MANIFEST_PATH}")

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    assets = manifest.get("assets", [])
    if not isinstance(assets, list):
        raise RuntimeError("assets/local_asset_manifest.json has no valid assets array.")

    first_character_index = next(
        (
            index for index, entry in enumerate(assets)
            if isinstance(entry, dict) and entry.get("category") == "character"
        ),
        len(assets),
    )

    non_character_assets = [
        entry for entry in assets
        if not (isinstance(entry, dict) and entry.get("category") == "character")
    ]

    insertion_index = min(first_character_index, len(non_character_assets))
    new_character_entries = [manifest_entry(record) for record in records]

    manifest["assets"] = (
        non_character_assets[:insertion_index]
        + new_character_entries
        + non_character_assets[insertion_index:]
    )

    MANIFEST_PATH.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    args = parse_args()
    archive_path = Path(args.archive).expanduser().resolve()

    if not archive_path.is_file():
        raise FileNotFoundError(f"Character archive not found: {archive_path}")

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    BACKUP_ROOT.mkdir(parents=True, exist_ok=True)

    if MANIFEST_PATH.is_file():
        shutil.copy2(
            MANIFEST_PATH,
            BACKUP_ROOT / f"local_asset_manifest_before_character_pack_{timestamp}.json",
        )

    if RUNTIME_ROOT.exists():
        shutil.rmtree(RUNTIME_ROOT)
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)

    if SOURCE_ROOT.exists():
        shutil.rmtree(SOURCE_ROOT)
    SOURCE_ROOT.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []

    with zipfile.ZipFile(archive_path) as outer:
        for definition in PACK_DEFINITIONS:
            nested_name = find_nested_archive(outer, definition["match"])
            target_root = SOURCE_ROOT / definition["key"]
            target_root.mkdir(parents=True, exist_ok=True)

            with zipfile.ZipFile(BytesIO(outer.read(nested_name))) as nested:
                for member in nested.namelist():
                    if (
                        member.startswith("__MACOSX/")
                        or "/__MACOSX/" in member
                        or Path(member).name.startswith("._")
                    ):
                        continue
                    nested.extract(member, target_root)

            source_archive_name = Path(nested_name).name

            if definition.get("single_character"):
                name = definition["single_character"]
                texture_dir = target_root / definition["single_texture_dir"]
                model_path = target_root / definition["default_model"]

                records.append(
                    {
                        "character_id": slugify(name),
                        "display_name": name,
                        "species": definition["species"],
                        "variant_index": 0,
                        "source_archive_name": source_archive_name,
                        "source_fbx": relative_project_path(model_path),
                        "texture_dir": relative_project_path(texture_dir),
                    }
                )
                continue

            villagers = discover_numbered_characters(
                target_root,
                definition["villager_root"],
            )

            for variant_index, name, texture_dir in villagers:
                model_relative = definition["special_models"].get(
                    name,
                    definition["default_model"],
                )
                model_path = target_root / model_relative

                if not model_path.is_file():
                    raise RuntimeError(f"Model for {name} not found: {model_path}")

                records.append(
                    {
                        "character_id": slugify(name),
                        "display_name": name,
                        "species": definition["species"],
                        "variant_index": variant_index,
                        "source_archive_name": source_archive_name,
                        "source_fbx": relative_project_path(model_path),
                        "texture_dir": relative_project_path(texture_dir),
                    }
                )

    if len(records) != 46:
        raise RuntimeError(
            f"Expected 46 selectable villagers from the supplied archive; discovered {len(records)}."
        )

    ids = [record["character_id"] for record in records]
    if len(ids) != len(set(ids)):
        raise RuntimeError("Duplicate character IDs were generated.")

    catalog = {
        "schema_version": 1,
        "source_archive": str(archive_path),
        "character_count": len(records),
        "characters": records,
    }

    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CATALOG_PATH.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    patch_manifest(records)

    print("")
    print("STUDYTOWN CHARACTER PACK STAGED")
    print("===============================")
    print(f"Characters:       {len(records)}")
    print("Species:          cats, alligators, goats, squirrel, tigers")
    print(f"Source:           {SOURCE_ROOT}")
    print(f"Runtime cleared:  {RUNTIME_ROOT}")
    print(f"Catalog:          {CATALOG_PATH}")
    print(f"Manifest updated: {MANIFEST_PATH}")
    print("")


if __name__ == "__main__":
    main()
