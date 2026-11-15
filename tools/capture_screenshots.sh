#!/usr/bin/env bash
# Regenerates the README and handbook screenshots in docs/screenshots/ from the real app.
#
# Usage:  tools/capture_screenshots.sh [output-dir]
#         (default output directory: docs/screenshots, relative to the repository root)
#
# Requirements:
#   - Godot 4.7.x on PATH as `godot`, or set GODOT=/path/to/godot.
#   - A desktop session. Every capture opens a real, windowed Godot window; the harness cannot run headless.
#   - The script runs `godot --import` first, so the project must import cleanly.
#
# Each capture renders the app with a deterministic fixture profile written to a temporary
# PM_USER_DATA directory. The script never reads or writes your real Program Manager data.
# The captures grab only the app viewport, so no other window or desktop content appears in them.
# The window's focus state at capture time changes its title-bar colour. A regenerated image can therefore differ
# from the committed one in that strip. In the 2026-11-14 check, 24 of 25 images were byte-identical.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
out_dir="${1:-$repo_root/docs/screenshots}"
godot_bin="${GODOT:-godot}"

# "<--capture scenario> <output file name without .png>"
shots=(
  "wfw-desktop wfw-311-program-manager"
  "wfw-group-properties wfw-group-properties"
  "wfw-new-group wfw-new-group"
  "win95-start win95-start-menu"
  "win95-programs win95-programs"
  "win95-my-computer win95-my-computer"
  "win95-folder-details win95-folder-details"
  "win95-find win95-find"
  "win95-properties win95-properties"
  "win95-run win95-run"
  "win95-shutdown win95-shutdown"
  "win95-scale2 win95-scale2"
  "mac-folder mac-launcher-hd"
  "mac-menu mac-menu"
  "mac-getinfo mac-getinfo"
  "mac-find mac-find"
  "mac-dark mac-dark"
  "mac-scale2 mac-scale2"
  "be-deskbar be-deskbar"
  "be-folder be-folder"
  "be-details be-details"
  "be-getinfo be-getinfo"
  "be-find be-find"
  "be-dark be-dark"
  "be-scale3 be-scale3"
)

if ! command -v "$godot_bin" >/dev/null 2>&1; then
  echo "error: Godot not found (looked for '$godot_bin'). Set GODOT=/path/to/godot." >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pm-capture.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
export PM_USER_DATA="$tmp_dir/data" PM_MARKER_DIR="$tmp_dir/markers" PM_NO_SINGLE_INSTANCE=1
mkdir -p "$PM_USER_DATA" "$PM_MARKER_DIR" "$out_dir"
: > "$out_dir/.gdignore"

echo "Importing project..."
"$godot_bin" --headless --path "$repo_root" --import > "$tmp_dir/import.log" 2>&1 || {
  echo "error: project import failed; see $tmp_dir/import.log" >&2
  exit 1
}

failures=0
for entry in "${shots[@]}"; do
  view="${entry%% *}"
  name="${entry#* }"
  target="$out_dir/$name.png"
  rm -f "$target"
  if "$godot_bin" --path "$repo_root" -- --capture="$view" --out="$target" \
       < /dev/null > "$tmp_dir/$view.log" 2>&1 && [ -s "$target" ]; then
    echo "ok       $view -> $target"
  else
    echo "FAILED   $view (log: $tmp_dir/$view.log)" >&2
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "$failures capture(s) failed." >&2
  exit 1
fi
echo "Captured ${#shots[@]} screenshots into $out_dir"
