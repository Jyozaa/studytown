#!/bin/bash
set -euo pipefail

# StudyTown - separate likely market/stall assets for inspection.
#
# Run from the StudyTown repo root:
#   chmod +x tools/local_assets/separate_market_stall_candidates.sh
#   ./tools/local_assets/separate_market_stall_candidates.sh
#
# Optional ZIP after copying:
#   ./tools/local_assets/separate_market_stall_candidates.sh --zip

PROJECT_ROOT="$PWD"
SOURCE_ROOT="${PROJECT_ROOT}/assets/dev_local/source_assets/StudyTown Garden Candidates"
OUTPUT_ROOT="${PROJECT_ROOT}/assets/dev_local/inspection_exports/market_stall_candidates"
MANIFEST="${OUTPUT_ROOT}/manifest.txt"

MAKE_ZIP=0
if [[ "${1:-}" == "--zip" ]]; then
    MAKE_ZIP=1
elif [[ $# -gt 0 ]]; then
    echo "Usage:"
    echo "  $0"
    echo "  $0 --zip"
    exit 1
fi

if [[ ! -f "${PROJECT_ROOT}/project.godot" ]]; then
    echo "ERROR: project.godot was not found in:"
    echo "  ${PROJECT_ROOT}"
    echo
    echo "Run this script from the StudyTown repo root."
    exit 1
fi

if [[ ! -d "${SOURCE_ROOT}" ]]; then
    echo "ERROR: source archive folder does not exist:"
    echo "  ${SOURCE_ROOT}"
    exit 1
fi

# Primary candidates: these are the four we most want to inspect.
PRIMARY=(
    "FtrStandMarket01M.Nin_NX_NVN"
    "FtrStandMarket01S.Nin_NX_NVN"
    "FtrStandMarket02M.Nin_NX_NVN"
    "FtrStandMarket02S.Nin_NX_NVN"
)

# Supporting market assets that may help identify the best stall or dress it later.
RELATED=(
    "IdrMarket01.Nin_NX_NVN"
    "IdrMarket02.Nin_NX_NVN"
    "IdrObjMarket01Shelf.Nin_NX_NVN"
    "IdrObjMarket02Shelf.Nin_NX_NVN"
    "IdrObjMarket02Board.Nin_NX_NVN"
    "IdrObjMarket01Fan.Nin_NX_NVN"
)

rm -rf "${OUTPUT_ROOT}"
mkdir -p "${OUTPUT_ROOT}/01_primary_stalls"
mkdir -p "${OUTPUT_ROOT}/02_related_market_assets"

# Prevent Godot from trying to import raw archive formats in this inspection folder.
touch "${OUTPUT_ROOT}/.gdignore"

{
    echo "StudyTown Market Stall Candidate Export"
    echo "======================================="
    echo
    echo "Source root:"
    echo "${SOURCE_ROOT}"
    echo
    echo "Generated:"
    date
    echo
} > "${MANIFEST}"

found=0
missing=0

copy_candidate() {
    local candidate="$1"
    local category="$2"

    # Exact directory-name search anywhere inside the archive source.
    local src
    src="$(find "${SOURCE_ROOT}" -type d -name "${candidate}" -print -quit)"

    if [[ -z "${src}" ]]; then
        echo "MISSING  ${candidate}"
        {
            echo "[MISSING] ${candidate}"
        } >> "${MANIFEST}"
        missing=$((missing + 1))
        return
    fi

    local dest_dir
    if [[ "${category}" == "primary" ]]; then
        dest_dir="${OUTPUT_ROOT}/01_primary_stalls/${candidate}"
    else
        dest_dir="${OUTPUT_ROOT}/02_related_market_assets/${candidate}"
    fi

    echo "COPYING  ${candidate}"
    echo "         ${src}"

    # ditto is built into macOS and preserves folder contents/metadata reliably.
    ditto "${src}" "${dest_dir}"

    local size
    size="$(du -sh "${dest_dir}" | awk '{print $1}')"

    {
        echo "[COPIED] ${candidate}"
        echo "  source: ${src}"
        echo "  output: ${dest_dir}"
        echo "  size:   ${size}"
        echo
    } >> "${MANIFEST}"

    found=$((found + 1))
}

echo
echo "=== Primary stall candidates ==="
for candidate in "${PRIMARY[@]}"; do
    copy_candidate "${candidate}" "primary"
done

echo
echo "=== Related market assets ==="
for candidate in "${RELATED[@]}"; do
    copy_candidate "${candidate}" "related"
done

{
    echo
    echo "Summary"
    echo "-------"
    echo "Found/copied: ${found}"
    echo "Missing:      ${missing}"
} >> "${MANIFEST}"

echo
echo "======================================"
echo "Done."
echo "Copied:  ${found}"
echo "Missing: ${missing}"
echo
echo "Inspection folder:"
echo "  ${OUTPUT_ROOT}"
echo
echo "Manifest:"
echo "  ${MANIFEST}"

if [[ "${MAKE_ZIP}" -eq 1 ]]; then
    ZIP_PATH="${PROJECT_ROOT}/market_stall_candidates.zip"
    rm -f "${ZIP_PATH}"

    echo
    echo "Creating ZIP:"
    echo "  ${ZIP_PATH}"

    (
        cd "$(dirname "${OUTPUT_ROOT}")"
        /usr/bin/zip -qry "${ZIP_PATH}" "$(basename "${OUTPUT_ROOT}")"
    )

    echo
    echo "ZIP ready:"
    echo "  ${ZIP_PATH}"
fi

echo
echo "If you're sending it to ChatGPT, the most useful folder is:"
echo "  assets/dev_local/inspection_exports/market_stall_candidates"
echo
