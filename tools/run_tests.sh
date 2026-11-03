#!/usr/bin/env bash
# Automated runtime test: a scripted playthrough from character creation to
# victory, driven through real input actions, with screenshots.
#   GODOT=/path/to/godot tools/run_tests.sh [flow|shots] [out_dir]
# On a headless Linux box it uses xvfb-run (software rendering works).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
MODE="${1:-flow}"
OUT="$(realpath -m "${2:-test_output/$MODE}")"
mkdir -p "$OUT"
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
RUN=("$GODOT" --path game --resolution 960x540 -- "--autotest=$MODE" "--out=$OUT")
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
  RUN=(xvfb-run -a -s "-screen 0 1280x720x24" "${RUN[@]}")
fi
set +e
"${RUN[@]}" 2>&1 | tee "$OUT/log.txt" | grep -E "AUTOTEST"
code=${PIPESTATUS[0]}
echo "results: $OUT/results.json (exit $code)"
exit $code
