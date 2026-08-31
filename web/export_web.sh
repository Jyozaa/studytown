#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

mkdir -p "$PROJECT_DIR/web/build"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release Web "$PROJECT_DIR/web/build/index.html"
echo "Web build ready in $PROJECT_DIR/web/build"

