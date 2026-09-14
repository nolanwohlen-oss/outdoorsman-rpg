"""Generate build metadata and configure this project's isolated Godot editor."""

import json
import os
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
number = int(os.environ.get("GITHUB_RUN_NUMBER", "1"))
commit = os.environ.get("GITHUB_SHA", "local")[:8]
metadata = root / "config" / "build_info.json"
metadata.parent.mkdir(exist_ok=True)
metadata.write_text(json.dumps({"number": number, "commit": commit, "version": "0.11.0", "phase": "2J"}) + "\n")

preset = root / "export_presets.cfg"
text = preset.read_text()
text = re.sub(r"^version/code=\d+$", f"version/code={number}", text, flags=re.MULTILINE)
text = re.sub(r'^version/name="[^"]*"$', f'version/name="0.11.0-dev.{number}"', text, flags=re.MULTILINE)
preset.write_text(text)

android_sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
java_sdk = os.environ.get("JAVA_HOME")
if not android_sdk or not java_sdk:
    raise SystemExit("Set ANDROID_HOME (or ANDROID_SDK_ROOT) and JAVA_HOME before configuring Android export.")
if not (Path(android_sdk) / "platform-tools" / "adb").is_file():
    raise SystemExit("Android SDK is missing platform-tools/adb.")

settings_dir = root / ".tools" / "godot" / "editor_data"
settings_files = list(settings_dir.glob("editor_settings-*.tres"))
if len(settings_files) != 1:
    raise SystemExit("Run the pinned Godot editor once before preparing the Android build.")
settings_file = settings_files[0]
settings = settings_file.read_text()
values = {
    "export/android/android_sdk_path": str(Path(android_sdk).resolve()),
    "export/android/java_sdk_path": str(Path(java_sdk).resolve()),
    "export/android/debug_keystore": str(root / ".tools" / "debug-signing" / "debug.keystore"),
    "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",
}
for key, value in values.items():
    entry = f"{key} = {json.dumps(value)}"
    pattern = rf"^{re.escape(key)} = .*?$"
    if re.search(pattern, settings, flags=re.MULTILINE):
        settings = re.sub(pattern, lambda _: entry, settings, flags=re.MULTILINE)
    else:
        settings += "\n" + entry + "\n"
settings_file.write_text(settings)
print(f"Prepared Phase 2J build {number} ({commit})")
