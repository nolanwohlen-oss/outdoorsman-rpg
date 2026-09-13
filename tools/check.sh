#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-$project_root/.tools/godot/godot}"
mkdir -p "$project_root/build"
timeout 90 "$godot_bin" --headless --path "$project_root" --editor --import 2>&1 | tee "$project_root/build/import.log"
timeout 60 "$godot_bin" --headless --path "$project_root" --script tests/run.gd 2>&1 | tee "$project_root/build/tests.log"
if grep -E 'SCRIPT ERROR:|^ERROR:' "$project_root/build/import.log" "$project_root/build/tests.log"; then
  exit 1
fi
