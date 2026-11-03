#!/usr/bin/env bash
# Export release builds of The Deep Vault.
# Requires Godot 4.5.1 and its export templates installed.
#   GODOT=/path/to/godot tools/build.sh [windows|linux|macos|all]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TARGET="${1:-all}"
"$GODOT" --headless --path game --import
build() {
  local preset="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  "$GODOT" --headless --path game --export-release "$preset" "$(realpath -m "$out")"
  echo "built $preset -> $out"
}
case "$TARGET" in
  windows) build Windows builds/windows/TheDeepVault.exe ;;
  linux)   build Linux builds/linux/TheDeepVault.x86_64 ;;
  macos)   build macOS builds/macos/TheDeepVault.zip ;;
  all)
    build Windows builds/windows/TheDeepVault.exe
    build Linux builds/linux/TheDeepVault.x86_64
    build macOS builds/macos/TheDeepVault.zip ;;
esac
