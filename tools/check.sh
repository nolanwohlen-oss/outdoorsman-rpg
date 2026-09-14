#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-$project_root/.tools/godot/godot}"
mkdir -p "$project_root/build"
touch "$project_root/build/.gdignore"
if rg -n --glob '*.gd' --glob '*.cfg' --glob '*.py' '([0-9]+ tokens truncated|content truncated|omitted [0-9]+ lines)' "$project_root"; then
  echo "Possible truncated tool output found in source; restore the complete source." >&2
  exit 1
fi
timeout 90 "$godot_bin" --headless --path "$project_root" --editor --import 2>&1 | tee "$project_root/build/import.log"
timeout 60 "$godot_bin" --headless --path "$project_root" --script tests/run.gd 2>&1 | tee "$project_root/build/tests.log"
timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2o.gd 2>&1 | tee "$project_root/build/phase-2o.log"
probe_dir="$(mktemp -d "$project_root/build/process-save-XXXXXX")"
timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/persistence_probe.gd -- write "$probe_dir" 2>&1 | tee "$project_root/build/save-write.log"
timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/persistence_probe.gd -- read "$probe_dir" 2>&1 | tee "$project_root/build/save-read.log"
if grep -E 'SCRIPT ERROR:|^ERROR:' "$project_root/build/import.log" "$project_root/build/tests.log" "$project_root/build/phase-2o.log" "$project_root/build/save-write.log" "$project_root/build/save-read.log"; then
  exit 1
fi
