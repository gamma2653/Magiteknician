#!/usr/bin/env bash
# Runs the headless test suite.
#
#   tests/run.sh                 run everything
#   tests/run.sh --only=rhythm   run the tests whose path or name contains "rhythm"
#
# Set GODOT to the editor binary if `godot` isn't on your PATH.
set -uo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot="${GODOT:-godot}"

if ! command -v "$godot" >/dev/null 2>&1; then
	echo "Could not find Godot at '$godot'. Set GODOT to the editor binary." >&2
	exit 2
fi

# Registers new class_name scripts and imports new assets. Its own exit
# status is not meaningful; the test run below is what decides the result.
"$godot" --headless --path "$project_dir" --import >/dev/null 2>&1

user_args=()
if [ "$#" -gt 0 ]; then
	user_args=(-- "$@")
fi

"$godot" --headless --path "$project_dir" res://tests/test_runner.tscn "${user_args[@]}"
