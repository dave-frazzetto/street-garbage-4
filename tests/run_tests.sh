#!/usr/bin/env bash
# Runs all headless test scenes. Each must print a "DONE:" line and exit 0.
# Usage: GODOT=/path/to/Godot_console.exe tests/run_tests.sh
set -u
GODOT="${GODOT:-/d/Programs/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1
fail=0
for t in test_rules test_player_input test_game_flow test_touch test_destructibles test_audio test_zombie_model test_player_model test_mobile test_combat_feel test_difficulty test_world_edges test_vfx test_model_look test_tuning test_pressure; do
  extra=""
  # Tests that need simulated time run unthrottled instead of in real time.
  if [ "$t" = "test_pressure" ]; then extra="--fixed-fps 60"; fi
  out=$(timeout 60 "$GODOT" --headless $extra --path . "res://tests/$t.tscn" 2>&1)
  code=$?
  line=$(echo "$out" | grep "DONE:")
  if [ $code -ne 0 ] || [ -z "$line" ] || echo "$out" | grep -q "SCRIPT ERROR"; then
    echo "FAIL $t (exit $code)"; echo "$out" | grep -E "FAIL|ERROR" | head -20; fail=1
  else
    echo "ok   $t: $line"
  fi
done
exit $fail
