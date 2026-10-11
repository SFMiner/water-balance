#!/bin/bash
# Run every headless suite. Usage (from water_balance/): GODOT=../../../Godot_v4.5-stable_win64.exe bash tests/run_all_tests.sh
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 1
"$GODOT" --headless --path . --editor --quit-after 200 > /dev/null 2>&1  # registers class_names first
FAILED=0
for suite in run_model_tests run_controller_tests run_ui_tests; do
	echo "--- $suite"
	OUT=$(timeout 300 "$GODOT" --headless --path . --script "res://tests/$suite.gd" 2>&1)
	CODE=$?
	echo "$OUT" | grep -E "checks|failures|passed|SCRIPT ERROR|Parse Error"
	if [ $CODE -ne 0 ] || echo "$OUT" | grep -q "SCRIPT ERROR"; then FAILED=$((FAILED + 1)); echo "FAILED: $suite"; fi
done
echo "Suites failed: $FAILED"
exit $FAILED
