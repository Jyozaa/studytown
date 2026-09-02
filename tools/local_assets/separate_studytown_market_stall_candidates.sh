#!/bin/bash
set -euo pipefail

# StudyTown market-stall candidate separator
#
# Run this from the StudyTown repo root.
# It searches the FULL extracted archive under ~/Downloads, copies only the
# likely stall/market candidates into assets/dev_local/inspection_reports,
# preserves the originals, and writes a manifest of exactly what was copied.

PROJECT_ROOT="${1:-$PWD}"
DOWNLOADS_ROOT="${HOME}/Downloads"
DEST_ROOT="${PROJECT_ROOT}/assets/dev_local/inspection_reports"
DEST="${DEST_ROOT}/StudyTown Market Stall Candidates"

if [[ ! -f "${PROJECT_ROOT}/project.godot" ]]; then
    echo "ERROR: project.godot was not found in:"
    echo "  ${PROJECT_ROOT}"
    echo
    echo "Run this from the StudyTown repo root, e.g.:"
    echo "  ./tools/local_assets/separate_studytown_market_stall_candidates.sh"
    exit 1
fi

if [[ ! -d "${DOWNLOADS_ROOT}" ]]; then
    echo "ERROR: Downloads folder does not exist: ${DOWNLOADS_ROOT}"
    exit 1
fi

mkdir -p "${DEST_ROOT}"
rm -rf "${DEST}"
mkdir -p "${DEST}"

# Prevent Godot from trying to import raw archive DAE/texture sources.
touch "${DEST}/.gdignore"

PROJECT_ROOT="${PROJECT_ROOT}" DOWNLOADS_ROOT="${DOWNLOADS_ROOT}" DEST="${DEST}" python3 - <<'PY'
from pathlib import Path
import json
import os
import shutil
import sys

project_root = Path(os.environ["PROJECT_ROOT"]).resolve()
downloads = Path(os.environ["DOWNLOADS_ROOT"]).expanduser().resolve()
dest = Path(os.environ["DEST"]).resolve()

# The four FtrStandMarket assets are the strongest direct stall candidates.
# The Idr* assets are included because they contain related counter/stand/
# shelf architecture and may be useful either as a better stall or for parts.
candidates = [
    ("01_direct_stands", "FtrStandMarket01M.Nin_NX_NVN"),
    ("01_direct_stands", "FtrStandMarket01S.Nin_NX_NVN"),
    ("01_direct_stands", "FtrStandMarket02M.Nin_NX_NVN"),
    ("01_direct_stands", "FtrStandMarket02S.Nin_NX_NVN"),
    ("02_market_scene_parts", "IdrMarket01.Nin_NX_NVN"),
    ("02_market_scene_parts", "IdrMarket02.Nin_NX_NVN"),
    ("03_market_props", "IdrObjMarket01Shelf.Nin_NX_NVN"),
    ("03_market_props", "IdrObjMarket02Shelf.Nin_NX_NVN"),
    ("03_market_props", "IdrObjMarket02Board.Nin_NX_NVN"),
]

# Prefer common extracted-archive roots first, but fall back to all Downloads.
preferred_roots = [
    downloads / "Model",
    downloads / "model",
    downloads / "Models",
    downloads / "models",
]
search_roots = [p for p in preferred_roots if p.is_dir()]
search_roots.append(downloads)

# Deduplicate nested roots while preserving priority.
unique_roots = []
seen = set()
for root in search_roots:
    key = str(root.resolve())
    if key not in seen:
        seen.add(key)
        unique_roots.append(root)


def find_candidate(folder_name: str):
    """Return best exact directory match, preferring shallower/Model paths."""
    matches = []
    checked = set()
    for root in unique_roots:
        # Fast exact root-level case first.
        direct = root / folder_name
        if direct.is_dir():
            rp = direct.resolve()
            if str(rp) not in checked:
                matches.append(rp)
                checked.add(str(rp))

        # Recursive fallback. Permission errors are ignored.
        try:
            for p in root.rglob(folder_name):
                try:
                    if p.is_dir():
                        rp = p.resolve()
                        if str(rp) not in checked:
                            matches.append(rp)
                            checked.add(str(rp))
                except OSError:
                    continue
        except (OSError, PermissionError):
            pass

    if not matches:
        return None, []

    # Prefer a path under ~/Downloads/Model, then shortest path depth.
    model_root = (downloads / "Model").resolve()
    def rank(p: Path):
        try:
            under_model = p.is_relative_to(model_root)
        except AttributeError:
            try:
                p.relative_to(model_root)
                under_model = True
            except ValueError:
                under_model = False
        return (0 if under_model else 1, len(p.parts), len(str(p)))

    matches.sort(key=rank)
    return matches[0], matches

manifest = {
    "source_root": str(downloads),
    "destination": str(dest),
    "requested": [],
    "copied": [],
    "missing": [],
    "duplicate_matches": [],
}

print("StudyTown Market Stall Candidate Separation")
print(f"Searching: {downloads}")
print(f"Output:    {dest}")
print()

for group, folder_name in candidates:
    manifest["requested"].append(folder_name)
    source, matches = find_candidate(folder_name)

    if source is None:
        print(f"MISSING  {folder_name}")
        manifest["missing"].append(folder_name)
        continue

    if len(matches) > 1:
        manifest["duplicate_matches"].append({
            "name": folder_name,
            "selected": str(source),
            "all_matches": [str(x) for x in matches],
        })

    group_dir = dest / group
    group_dir.mkdir(parents=True, exist_ok=True)
    target = group_dir / folder_name

    print(f"COPY     {folder_name}")
    print(f"         from: {source}")
    print(f"         to:   {target}")

    shutil.copytree(source, target, copy_function=shutil.copy2)

    file_count = 0
    total_bytes = 0
    extensions = {}
    for p in target.rglob("*"):
        if not p.is_file():
            continue
        file_count += 1
        try:
            total_bytes += p.stat().st_size
        except OSError:
            pass
        ext = p.suffix.lower() or "<none>"
        extensions[ext] = extensions.get(ext, 0) + 1

    manifest["copied"].append({
        "name": folder_name,
        "group": group,
        "source": str(source),
        "destination": str(target),
        "file_count": file_count,
        "size_mb": round(total_bytes / (1024 * 1024), 3),
        "extensions": dict(sorted(extensions.items())),
    })

manifest_path = dest / "stall_candidate_manifest.json"
manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

readme = dest / "README.txt"
readme.write_text(
    "StudyTown Market Stall Candidates\n"
    "=================================\n\n"
    "01_direct_stands\n"
    "  Strongest candidates for a freestanding vendor/cafe stall.\n\n"
    "02_market_scene_parts\n"
    "  Larger market scene assets that may contain useful stand/counter pieces.\n\n"
    "03_market_props\n"
    "  Shelves/board props that may be useful for dressing the stall.\n\n"
    "The original archive in Downloads was NOT modified. These are copies.\n"
    "This folder contains .gdignore so Godot does not import the raw DAE files.\n",
    encoding="utf-8",
)

print()
print("SUMMARY")
print(f"  requested: {len(candidates)}")
print(f"  copied:    {len(manifest['copied'])}")
print(f"  missing:   {len(manifest['missing'])}")
print(f"  manifest:  {manifest_path}")

if manifest["missing"]:
    print()
    print("Missing candidates:")
    for name in manifest["missing"]:
        print(f"  - {name}")

print()
print("Done. Compress this folder and send it for inspection:")
print(f'  "{dest}"')
PY

echo
echo "Optional compression command:"
echo "cd \"${DEST_ROOT}\" && ditto -c -k --sequesterRsrc --keepParent \"StudyTown Market Stall Candidates\" \"StudyTown Market Stall Candidates.zip\""
