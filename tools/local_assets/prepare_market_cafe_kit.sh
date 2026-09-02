#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${1:-$PWD}"
DOWNLOADS_ROOT="${HOME}/Downloads"
KIT_ROOT="${PROJECT_ROOT}/assets/dev_local/source_assets/market_cafe_kit"
MARKET_FOLDER="${KIT_ROOT}/IdrMarket01.Nin_NX_NVN"
SHELF_FOLDER="${KIT_ROOT}/IdrObjMarket01Shelf.Nin_NX_NVN"

if [[ ! -f "${PROJECT_ROOT}/project.godot" ]]; then
    echo "ERROR: project.godot was not found in ${PROJECT_ROOT}"
    echo "Run this from the StudyTown repo root."
    exit 1
fi

if [[ ! -d "${DOWNLOADS_ROOT}" ]]; then
    echo "ERROR: Downloads folder does not exist: ${DOWNLOADS_ROOT}"
    exit 1
fi

mkdir -p "${KIT_ROOT}"
touch "${KIT_ROOT}/.gdignore"

PROJECT_ROOT="${PROJECT_ROOT}" DOWNLOADS_ROOT="${DOWNLOADS_ROOT}" KIT_ROOT="${KIT_ROOT}" python3 - <<'PY'
from pathlib import Path
import os
import shutil
import json

root = Path(os.environ['DOWNLOADS_ROOT']).expanduser().resolve()
kit = Path(os.environ['KIT_ROOT']).resolve()

# Main donor model + useful display shelf.
required_model_folders = {
    'IdrMarket01.Nin_NX_NVN',
    'IdrObjMarket01Shelf.Nin_NX_NVN',
}

# The full archive stores IdrMarket01 material maps in separate folders.
# Copy all of them once, then flatten the PNGs beside IdrMarket01.dae so the
# Blender converter can resolve the DAE's normal texture names directly.
texture_folders = {
    'IdrMarket01_Tex_mCounterSet_Alb.Nin_NX_NVN',
    'IdrMarket01_Tex_mCounterSet_Mix.Nin_NX_NVN',
    'IdrMarket01_Tex_mCounterSet_Nrm.Nin_NX_NVN',
    'IdrMarket01_Tex_mDecoSet01_Alb.Nin_NX_NVN',
    'IdrMarket01_Tex_mDecoSet01_Mix.Nin_NX_NVN',
    'IdrMarket01_Tex_mDecoSet01_Nrm.Nin_NX_NVN',
    'IdrMarket01_Tex_mFloor_Alb.Nin_NX_NVN',
    'IdrMarket01_Tex_mFloor_Mix.Nin_NX_NVN',
    'IdrMarket01_Tex_mFloor_Nrm.Nin_NX_NVN',
    'IdrMarket01_Tex_mMushiro_Alb.Nin_NX_NVN',
    'IdrMarket01_Tex_mMushiro_Mix.Nin_NX_NVN',
    'IdrMarket01_Tex_mMushiro_Nrm.Nin_NX_NVN',
    'IdrMarket01_Tex_mMushiro_OP.Nin_NX_NVN',
    'IdrMarket01_Tex_mNorenSet_Alb.Nin_NX_NVN',
    'IdrMarket01_Tex_mNorenSet_Mix.Nin_NX_NVN',
    'IdrMarket01_Tex_mNorenSet_Nrm.Nin_NX_NVN',
    'IdrMarket01_Tex_mStand_Alb.Nin_NX_NVN',
    'IdrMarket01_Tex_mStand_Mix.Nin_NX_NVN',
    'IdrMarket01_Tex_mStand_Nrm.Nin_NX_NVN',
    'IdrMarket01_Tex_mWall_Alb.Nin_NX_NVN',
    'IdrMarket01_Tex_mWall_Mix.Nin_NX_NVN',
    'IdrMarket01_Tex_mWall_Nrm.Nin_NX_NVN',
}

wanted = required_model_folders | texture_folders
found = {name: [] for name in wanted}

print('Scanning the FULL Downloads archive once...')
for dirpath, dirnames, filenames in os.walk(root):
    current = Path(dirpath)
    for dirname in list(dirnames):
        if dirname in wanted:
            found[dirname].append((current / dirname).resolve())


def choose(paths):
    if not paths:
        return None
    model_root = (root / 'Model').resolve()
    def rank(p):
        try:
            p.relative_to(model_root)
            in_model = 0
        except ValueError:
            in_model = 1
        return (in_model, len(p.parts), len(str(p)))
    return sorted(paths, key=rank)[0]

selected = {name: choose(paths) for name, paths in found.items()}
missing = [name for name, path in selected.items() if path is None]
if missing:
    print('\nERROR: missing required archive folders:')
    for name in sorted(missing):
        print('  -', name)
    raise SystemExit(1)

# Recreate only this small local kit. The giant Downloads archive is untouched.
for child in list(kit.iterdir()):
    if child.name == '.gdignore':
        continue
    if child.is_dir():
        shutil.rmtree(child)
    else:
        child.unlink()

market_dest = kit / 'IdrMarket01.Nin_NX_NVN'
shelf_dest = kit / 'IdrObjMarket01Shelf.Nin_NX_NVN'

for name, dest in [
    ('IdrMarket01.Nin_NX_NVN', market_dest),
    ('IdrObjMarket01Shelf.Nin_NX_NVN', shelf_dest),
]:
    src = selected[name]
    print(f'COPY {name}')
    print(f'  from: {src}')
    print(f'  to:   {dest}')
    shutil.copytree(src, dest)

raw_tex = kit / '_raw_market_texture_folders'
raw_tex.mkdir(parents=True, exist_ok=True)

flattened = []
for name in sorted(texture_folders):
    src = selected[name]
    dest = raw_tex / name
    shutil.copytree(src, dest)

    pngs = list(dest.rglob('*.png'))
    if not pngs:
        print(f'WARNING: no PNG found in {name}')
        continue

    for png in pngs:
        target = market_dest / png.name
        shutil.copy2(png, target)
        flattened.append(png.name)

manifest = {
    'downloads_root': str(root),
    'kit_root': str(kit),
    'models': {
        key: str(selected[key])
        for key in sorted(required_model_folders)
    },
    'texture_folders': {
        key: str(selected[key])
        for key in sorted(texture_folders)
    },
    'flattened_market_textures': sorted(set(flattened)),
}
(kit / 'market_cafe_kit_manifest.json').write_text(
    json.dumps(manifest, indent=2),
    encoding='utf-8',
)

print('\nSTUDYTOWN_MARKET_KIT_READY')
print('Project-local source kit:')
print(' ', kit)
print('Godot ignores this source folder because .gdignore is present.')
print('The full Downloads archive was not modified.')
PY

echo
echo "Next command:"
echo "/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/local_assets/blender_market_cafe_kit.py -- --source \"assets/dev_local/source_assets/market_cafe_kit\" --output \"assets/dev_local/blender_generated/runtime\""
