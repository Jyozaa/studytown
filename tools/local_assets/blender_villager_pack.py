"""Convert every staged StudyTown villager into an animated Godot GLB.

This reuses the exact StudyTown skeletal action generator from
tools/local_assets/blender_cat_pipeline.py so every compatible villager receives
the same Idle / Walk / sitting / study / wave / stretch / cheer / resting
animation states already used by the project.

Run with Blender from the StudyTown repository root.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from blender_cat_pipeline import LOOP_ACTIONS, create_actions, normalize_height  # noqa: E402

DEFAULT_CATALOG = (
    PROJECT_ROOT / "assets" / "dev_local" / "character_catalog.json"
)
DEFAULT_OUTPUT = (
    PROJECT_ROOT / "assets" / "dev_local" / "characters"
)

CORE_ANIMATION_BONES = {
    "Spine_2",
    "Head",
    "Arm_1_L",
    "Arm_1_R",
    "Arm_2_L",
    "Arm_2_R",
    "Leg_1_L",
    "Leg_1_R",
    "Leg_2_L",
    "Leg_2_R",
    "Ankle_L",
    "Ankle_R",
}

ROLE_PREFIXES = {
    "body": ["mbody", "body"],
    "eye": ["meye", "eye"],
    "mouth": ["mmouth", "mouth"],
    "beak": ["mbeak", "beak"],
    "tops": ["mtops", "cloth"],
    "glassalpha": ["mglassalpha", "glassalpha"],
    "glass": ["mglass", "glass"],
    "cap": ["mcap", "cap"],
}


def parse_args() -> argparse.Namespace:
    argv = (
        sys.argv[sys.argv.index("--") + 1 :]
        if "--" in sys.argv
        else []
    )

    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default=str(DEFAULT_CATALOG))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument(
        "--only",
        default="",
        help="Optional comma-separated character IDs.",
    )
    parser.add_argument("--target-height", type=float, default=2.70)
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    collections = [
        bpy.data.actions,
        bpy.data.meshes,
        bpy.data.armatures,
        bpy.data.materials,
        bpy.data.images,
    ]

    for collection in collections:
        for datablock in list(collection):
            if datablock.users == 0:
                collection.remove(datablock)


def normalize_token(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def classify_material(material_name: str) -> str | None:
    name = normalize_token(material_name)

    if "glassalpha" in name:
        return "glassalpha"
    if "glass" in name:
        return "glass"
    if "capvis" in name:
        return "body"
    if "body" in name:
        return "body"
    if "eye" in name:
        return "eye"
    if "mouth" in name:
        return "mouth"
    if "beak" in name:
        return "beak"
    if "tops" in name or "cloth" in name:
        return "tops"
    if "cap" in name:
        return "cap"

    return None


def texture_candidates(
    texture_dir: Path,
    role: str,
    suffix: str,
) -> list[Path]:
    prefixes = ROLE_PREFIXES.get(role, [])
    suffix_token = suffix.lower()
    candidates: list[tuple[int, int, str, Path]] = []

    for path in texture_dir.iterdir():
        if not path.is_file() or path.suffix.lower() != ".png":
            continue

        token = normalize_token(path.stem)

        if not any(token.startswith(prefix) for prefix in prefixes):
            continue

        if suffix_token not in token:
            continue

        neutral_score = 0

        if role in {"eye", "mouth"}:
            neutral_score = 0 if token.endswith(("0", "00")) else 1

        candidates.append(
            (
                neutral_score,
                len(token),
                token,
                path,
            )
        )

    candidates.sort(
        key=lambda item: (
            item[0],
            item[1],
            item[2],
        )
    )

    return [item[3] for item in candidates]


def texture_for(
    texture_dir: Path,
    role: str,
    suffix: str,
) -> Path | None:
    candidates = texture_candidates(texture_dir, role, suffix)
    return candidates[0] if candidates else None


def image_node(
    nodes,
    path: Path,
    label: str,
    non_color: bool = False,
):
    node = nodes.new("ShaderNodeTexImage")
    node.name = label
    node.label = label
    node.image = bpy.data.images.load(str(path), check_existing=True)

    if non_color:
        node.image.colorspace_settings.name = "Non-Color"

    return node


def rebuild_materials(texture_dir: Path) -> None:
    used = {
        slot.material
        for obj in bpy.data.objects
        if obj.type == "MESH"
        for slot in obj.material_slots
        if slot.material
    }

    for material in used:
        role = classify_material(material.name)
        if role is None:
            continue

        material.use_nodes = True
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        nodes.clear()

        output = nodes.new("ShaderNodeOutputMaterial")
        shader = nodes.new("ShaderNodeBsdfPrincipled")
        shader.inputs["Roughness"].default_value = 0.72
        links.new(shader.outputs["BSDF"], output.inputs["Surface"])

        albedo_path = texture_for(texture_dir, role, "alb")
        if albedo_path:
            albedo = image_node(nodes, albedo_path, "Albedo")
            links.new(albedo.outputs["Color"], shader.inputs["Base Color"])

            if role in {"tops", "glassalpha", "cap"}:
                links.new(albedo.outputs["Alpha"], shader.inputs["Alpha"])

        normal_path = texture_for(texture_dir, role, "nrm")
        if normal_path:
            normal = image_node(nodes, normal_path, "Normal", True)
            normal_map = nodes.new("ShaderNodeNormalMap")
            normal_map.inputs["Strength"].default_value = 0.65
            links.new(normal.outputs["Color"], normal_map.inputs["Color"])
            links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])

        roughness_path = texture_for(texture_dir, role, "rgh")
        if roughness_path:
            roughness = image_node(nodes, roughness_path, "Roughness", True)
            links.new(roughness.outputs["Color"], shader.inputs["Roughness"])

        metallic_path = texture_for(texture_dir, role, "mtl")
        if metallic_path:
            metallic = image_node(nodes, metallic_path, "Metallic", True)
            links.new(metallic.outputs["Color"], shader.inputs["Metallic"])


def should_remove_mesh(obj: bpy.types.Object) -> bool:
    name = normalize_token(obj.name)

    if "onepiece" in name:
        return True
    if "mydesign" in name:
        return True
    if "tshirtsh" in name:
        return True
    if "tshirtsl" in name:
        return True
    if "tshirtsemm" in name:
        return True
    if "mouthsmile" in name or "mouthfrown" in name:
        return True

    return False


def filter_character_meshes() -> list[str]:
    removed: list[str] = []

    for obj in list(bpy.data.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
            continue

        if obj.type == "MESH" and should_remove_mesh(obj):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)

    return removed


def clear_source_actions(armature: bpy.types.Object) -> list[str]:
    source_actions = [action.name for action in bpy.data.actions]
    armature.animation_data_clear()

    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)

    return source_actions


def convert_character(
    record: dict,
    output_root: Path,
    target_height: float,
) -> dict:
    reset_scene()

    source_fbx = (PROJECT_ROOT / record["source_fbx"]).resolve()
    texture_dir = (PROJECT_ROOT / record["texture_dir"]).resolve()
    output = (output_root / f"{record['character_id']}.glb").resolve()

    if not source_fbx.is_file():
        raise FileNotFoundError(f"Source FBX missing: {source_fbx}")
    if not texture_dir.is_dir():
        raise FileNotFoundError(f"Texture directory missing: {texture_dir}")

    bpy.ops.import_scene.fbx(
        filepath=str(source_fbx),
        use_anim=True,
    )

    removed_meshes = filter_character_meshes()
    rebuild_materials(texture_dir)

    armatures = [
        obj for obj in bpy.data.objects
        if obj.type == "ARMATURE"
    ]

    if len(armatures) != 1:
        raise RuntimeError(
            f"{record['display_name']}: expected exactly one armature; found {len(armatures)}."
        )

    armature = armatures[0]

    # Goats and alligators use Tail_1 / Tail_2, while the existing StudyTown
    # animation generator targets S_Tail_1 / S_Tail_2. Renaming the bones keeps
    # the same tail motion without changing skin weights or gameplay code.
    tail_aliases = {
        "Tail_1": "S_Tail_1",
        "Tail_2": "S_Tail_2",
    }

    for source_name, target_name in tail_aliases.items():
        if (
            armature.data.bones.get(source_name) is not None
            and armature.data.bones.get(target_name) is None
        ):
            armature.data.bones[source_name].name = target_name

    bone_names = {bone.name for bone in armature.data.bones}
    missing_core_bones = sorted(CORE_ANIMATION_BONES - bone_names)

    if missing_core_bones:
        raise RuntimeError(
            f"{record['display_name']}: animation-compatible core bones missing: "
            + ", ".join(missing_core_bones)
        )

    source_actions = clear_source_actions(armature)
    scale_factor = normalize_height(target_height)

    # Exact same StudyTown action generator as the previous characters.
    create_actions(armature)

    bpy.context.scene.render.fps = 24
    output.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )

    generated_actions = sorted(action.name for action in bpy.data.actions)

    report = {
        "character_id": record["character_id"],
        "display_name": record["display_name"],
        "species": record["species"],
        "source_fbx": record["source_fbx"],
        "texture_dir": record["texture_dir"],
        "output": (
            "res://assets/dev_local/characters/"
            + record["character_id"]
            + ".glb"
        ),
        "armature": armature.name,
        "bone_count": len(armature.data.bones),
        "source_actions_removed": source_actions,
        "generated_actions": generated_actions,
        "loop_actions": sorted(LOOP_ACTIONS),
        "removed_meshes": removed_meshes,
        "target_height": target_height,
        "scale_factor": scale_factor,
    }

    output.with_suffix(".diagnostic.json").write_text(
        json.dumps(report, indent=2),
        encoding="utf-8",
    )

    return report


def main() -> None:
    args = parse_args()
    catalog_path = Path(args.catalog).expanduser().resolve()
    output_root = Path(args.output).expanduser().resolve()

    if not catalog_path.is_file():
        raise FileNotFoundError(
            "Character catalog does not exist. Run stage_character_pack.py first."
        )

    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    records = catalog.get("characters", [])

    requested = {
        value.strip()
        for value in args.only.split(",")
        if value.strip()
    }

    if requested:
        known = {record["character_id"] for record in records}
        unknown = requested - known

        if unknown:
            raise ValueError(
                "Unknown character IDs: " + ", ".join(sorted(unknown))
            )

        records = [
            record for record in records
            if record["character_id"] in requested
        ]

    output_root.mkdir(parents=True, exist_ok=True)
    reports: list[dict] = []

    print("")
    print("STUDYTOWN VILLAGER CHARACTER CONVERSION")
    print("=======================================")
    print(f"Characters: {len(records)}")
    print("")

    for index, record in enumerate(records, start=1):
        print(
            f"[{index:02d}/{len(records):02d}] "
            f"{record['display_name']} ({record['species']})"
        )

        reports.append(
            convert_character(
                record,
                output_root,
                args.target_height,
            )
        )

    summary_path = output_root / "character_pack_conversion.json"
    summary_path.write_text(
        json.dumps(
            {
                "converted": len(reports),
                "characters": reports,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print("")
    print("DONE")
    print(f"Converted: {len(reports)}")
    print(f"Summary:   {summary_path}")


if __name__ == "__main__":
    main()
