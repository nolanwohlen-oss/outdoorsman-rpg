#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_version="$(tr -d '\r\n' < "$project_root/.godot-version")"
install_dir="$project_root/.tools/godot"
download_dir="$project_root/.tools/downloads"
base_url="https://github.com/godotengine/godot-builds/releases/download/${godot_version}-stable"
mkdir -p "$install_dir" "$download_dir"

download_verified() {
  local filename="$1"
  curl --fail --location --silent --show-error --retry 3 "$base_url/$filename" -o "$download_dir/$filename"
  curl --fail --location --silent --show-error --retry 3 "$base_url/SHA512-SUMS.txt" -o "$download_dir/SHA512-SUMS.txt"
  (cd "$download_dir" && awk -v file="$filename" '$2 == file || $2 == "*" file {print; found=1} END {if (!found) exit 1}' SHA512-SUMS.txt | sha512sum --check --status)
}

if [[ ! -x "$install_dir/godot" ]] || ! timeout 15 "$install_dir/godot" --version >/dev/null 2>&1; then
  archive="Godot_v${godot_version}-stable_linux.x86_64.zip"
  download_verified "$archive"
  unzip -q -o "$download_dir/$archive" -d "$install_dir"
  mv "$install_dir/Godot_v${godot_version}-stable_linux.x86_64" "$install_dir/godot"
  chmod +x "$install_dir/godot"
fi

# Keep editor settings and templates inside this disposable tool installation.
touch "$install_dir/_sc_"
"$install_dir/godot" --version

if [[ "${1:-}" == "--templates" ]]; then
  template_dir="$install_dir/editor_data/export_templates/${godot_version}.stable"
  if [[ ! -f "$template_dir/android_debug.apk" || ! -f "$template_dir/linux_debug.x86_64" ]]; then
    archive="Godot_v${godot_version}-stable_export_templates.tpz"
    download_verified "$archive"
    mkdir -p "$template_dir"
    unzip -q -o -j "$download_dir/$archive" 'templates/android_debug.apk' 'templates/linux_debug.x86_64' 'templates/version.txt' -d "$template_dir"
    chmod +x "$template_dir/linux_debug.x86_64"
  fi
fi
