#!/usr/bin/env bash
# Export release builds of Bobek's Adventure.
# Requires Godot 4.5.1 and its export templates installed.
#   GODOT=/path/to/godot tools/build.sh [windows|linux|macos|all]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TARGET="${1:-all}"
# Stamp the build number shown on the title screen and pause menu
STAMP="$(date -u +%Y-%m-%d) · $(git rev-parse --short HEAD 2>/dev/null || echo local)"
printf 'class_name BuildInfo\n## Stamped by tools/build.sh at export time (restored to "dev" afterwards), so\n## the title screen and pause menu show which build you'"'"'re playing.\nconst BUILD := "%s"\n' "$STAMP" > game/scripts/build_info.gd
trap 'git checkout -q -- game/scripts/build_info.gd 2>/dev/null || true' EXIT
"$GODOT" --headless --path game --import
build() {
  local preset="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  "$GODOT" --headless --path game --export-release "$preset" "$(realpath -m "$out")"
  echo "built $preset -> $out"
}
# The web / iPad build must stay inside the mobile budget: the whole first
# download (engine + game data) under 100 MB. The build fails if it grows past it.
WEB_BUDGET_MB="${WEB_BUDGET_MB:-100}"
build_web() {
  mkdir -p builds/web
  "$GODOT" --headless --path game --export-release Web "$(realpath -m builds/web/index.html)"
  local bytes; bytes=$(du -cb builds/web/* | tail -1 | cut -f1)
  local mb=$((bytes / 1000000))
  echo "web build: ${mb} MB (budget ${WEB_BUDGET_MB} MB)"
  if [ "$mb" -gt "$WEB_BUDGET_MB" ]; then
    echo "ERROR: the web/iPad download is over budget (${mb} MB > ${WEB_BUDGET_MB} MB)" >&2
    exit 1
  fi
}
case "$TARGET" in
  web)     build_web ;;
  windows) build Windows builds/windows/BobeksAdventure.exe ;;
  linux)   build Linux builds/linux/BobeksAdventure.x86_64 ;;
  macos)   build macOS builds/macos/BobeksAdventure.zip ;;
  all)
    build Windows builds/windows/BobeksAdventure.exe
    build Linux builds/linux/BobeksAdventure.x86_64
    build macOS builds/macos/BobeksAdventure.zip ;;
esac
