#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${1:-$PWD}"
SOURCE="${HOME}/Downloads/StudyTown Garden Candidates"
DEST_ROOT="${PROJECT_ROOT}/assets/dev_local/source_assets"
DEST="${DEST_ROOT}/StudyTown Garden Candidates"

echo "StudyTown Garden source relocation"
echo "Project: ${PROJECT_ROOT}"
echo "Source:  ${SOURCE}"
echo "Dest:    ${DEST}"
echo

# Make sure this is actually the StudyTown project.
if [[ ! -f "${PROJECT_ROOT}/project.godot" ]]; then
    echo "ERROR: project.godot was not found in:"
    echo "  ${PROJECT_ROOT}"
    echo
    echo "Run this from the StudyTown repo root, or pass the repo path:"
    echo "  bash tools/local_assets/move_studytown_garden_sources.sh /Users/joe/Desktop/studytown"
    exit 1
fi

mkdir -p "${DEST_ROOT}"

# If the source has already been moved, succeed without doing anything.
if [[ ! -d "${SOURCE}" ]]; then
    if [[ -d "${DEST}" ]]; then
        echo "Already moved."
        echo "Garden source assets are here:"
        echo "  ${DEST}"
        exit 0
    fi

    echo "ERROR: Could not find the Garden source folder in Downloads:"
    echo "  ${SOURCE}"
    echo
    echo "And it is not already present at:"
    echo "  ${DEST}"
    echo
    echo "If the folder has another name/location, move it manually into:"
    echo "  ${DEST_ROOT}/"
    exit 1
fi

# Avoid silently merging two different copies.
if [[ -e "${DEST}" ]]; then
    echo "ERROR: Destination already exists:"
    echo "  ${DEST}"
    echo
    echo "Nothing was changed."
    echo "Remove/rename the destination first if you intentionally want to replace it."
    exit 1
fi

echo "Moving source assets into the project..."
mv "${SOURCE}" "${DEST}"

echo
echo "Verifying..."
if [[ ! -d "${DEST}" ]]; then
    echo "ERROR: Move did not complete."
    exit 1
fi

# Make sure some key folders/files expected by the current Garden importer exist.
EXPECTED=(
    "01_Trees"
    "02_Bushes_Weeds_Flowers"
    "03_Fountain_Pool"
    "04_Rocks_Paths"
    "05_Campfire"
    "06_Garden_Furniture"
    "07_Cafe"
)

missing=0
for item in "${EXPECTED[@]}"; do
    if [[ ! -e "${DEST}/${item}" ]]; then
        echo "WARNING: expected item not found: ${item}"
        missing=1
    fi
done

echo
echo "Done."
echo "Garden source assets now live at:"
echo "  ${DEST}"
echo
echo "Use this Blender command from now on:"
echo
echo "/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/local_assets/blender_garden_archive_assets.py -- --source \"assets/dev_local/source_assets/StudyTown Garden Candidates\" --output \"assets/dev_local/blender_generated/runtime\""
echo

if [[ "${missing}" -eq 1 ]]; then
    echo "The move succeeded, but one or more expected category folders were not found."
    echo "That may be fine if your candidate folder structure differs."
fi
