#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot4}"
"$GODOT_BIN" --headless --editor --import --quit
"$GODOT_BIN" --headless --script res://tests/PhysicsTests.gd
"$GODOT_BIN" --headless --script res://tests/SceneTests.gd
"$GODOT_BIN" --headless --script res://tests/CompactPhysicsTests.gd
"$GODOT_BIN" --headless --script res://tests/CompactSceneTests.gd
