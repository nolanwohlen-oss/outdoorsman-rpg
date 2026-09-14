#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-$project_root/.tools/godot/godot}"
mkdir -p "$project_root/build"
touch "$project_root/build/.gdignore"
if ! PROJECT_ROOT="$project_root" python3 - <<'PY'
import os
from pathlib import Path
import re
import sys

root = Path(os.environ["PROJECT_ROOT"])
pattern = re.compile(r"([0-9]+ tokens truncated|content truncated|omitted [0-9]+ lines)")
found = []
for path in root.rglob("*"):
    if not path.is_file() or path.suffix not in {".gd", ".cfg", ".py"}:
        continue
    if any(part in {".git", ".tools", "build"} for part in path.parts):
        continue
    for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        if pattern.search(line):
            found.append(f"{path.relative_to(root)}:{number}:{line}")
if found:
    print("\n".join(found))
    sys.exit(1)
PY
then
  echo "Possible truncated tool output found in source; restore the complete source." >&2
  exit 1
fi
timeout 90 "$godot_bin" --headless --path "$project_root" --editor --import 2>&1 | tee "$project_root/build/import.log"
timeout 60 "$godot_bin" --headless --path "$project_root" --script tests/run.gd 2>&1 | tee "$project_root/build/tests.log"
timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2o.gd 2>&1 | tee "$project_root/build/phase-2o.log"
timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2p.gd 2>&1 | tee "$project_root/build/phase-2p.log"
probe_dir="$(mktemp -d "$project_root/build/process-save-XXXXXX")"
timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/persistence_probe.gd -- write "$probe_dir" 2>&1 | tee "$project_root/build/save-write.log"
timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/persistence_probe.gd -- read "$probe_dir" 2>&1 | tee "$project_root/build/save-read.log"
if grep -E 'SCRIPT ERROR:|^ERROR:' "$project_root/build/import.log" "$project_root/build/tests.log" "$project_root/build/phase-2o.log" "$project_root/build/phase-2p.log" "$project_root/build/save-write.log" "$project_root/build/save-read.log"; then
  exit 1
fi
