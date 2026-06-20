#!/bin/sh
set -eu

# Safety net: ensure the Godot iOS Xcode project exists before xcodebuild runs.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/ci_post_clone.sh"
