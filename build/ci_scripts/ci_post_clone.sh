#!/bin/sh
set -eu

# Xcode Cloud: install Godot + export templates, then generate build/NeoChameleon.xcodeproj.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_DIR="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
cd "$WORKSPACE_DIR"

GODOT_VERSION="${GODOT_VERSION:-4.6.2-stable}"
GODOT_VERSION_DIR="${GODOT_VERSION_DIR:-4.6.2.stable}"
CACHE_DIR="$HOME/.cache/godot/${GODOT_VERSION}"
GODOT_ZIP="$CACHE_DIR/godot.zip"
TEMPLATES_TPZ="$CACHE_DIR/templates.tpz"

mkdir -p "$CACHE_DIR"

if [ ! -f "$GODOT_ZIP" ]; then
	curl -fL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_macos.universal.zip" -o "$GODOT_ZIP"
fi

if [ ! -d "$CACHE_DIR/Godot.app" ] && [ ! -d "$CACHE_DIR/Godot_macos.app" ]; then
	ditto -x -k "$GODOT_ZIP" "$CACHE_DIR"
fi

xattr -dr com.apple.quarantine "$CACHE_DIR" 2>/dev/null || true

if [ -x "$CACHE_DIR/Godot.app/Contents/MacOS/Godot" ]; then
	GODOT_BIN="$CACHE_DIR/Godot.app/Contents/MacOS/Godot"
elif [ -x "$CACHE_DIR/Godot_macos.app/Contents/MacOS/Godot" ]; then
	GODOT_BIN="$CACHE_DIR/Godot_macos.app/Contents/MacOS/Godot"
else
	echo "Could not find Godot binary after unzip" >&2
	exit 1
fi

if [ ! -f "$TEMPLATES_TPZ" ]; then
	curl -fL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz" -o "$TEMPLATES_TPZ"
fi

TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/${GODOT_VERSION_DIR}"
if [ ! -f "$TEMPLATES_DIR/.installed" ]; then
	TMP_TEMPLATES_DIR="$CACHE_DIR/templates_unpack"
	rm -rf "$TMP_TEMPLATES_DIR"
	mkdir -p "$TMP_TEMPLATES_DIR" "$TEMPLATES_DIR"
	ditto -x -k "$TEMPLATES_TPZ" "$TMP_TEMPLATES_DIR"

	if [ -d "$TMP_TEMPLATES_DIR/templates" ]; then
		cp -f "$TMP_TEMPLATES_DIR/templates"/* "$TEMPLATES_DIR/"
	else
		cp -f "$TMP_TEMPLATES_DIR"/* "$TEMPLATES_DIR/"
	fi

	touch "$TEMPLATES_DIR/.installed"
fi

EXPORT_PATH="$WORKSPACE_DIR/build/NeoChameleon.xcodeproj"
mkdir -p "$WORKSPACE_DIR/build"
rm -rf "$EXPORT_PATH"
"$GODOT_BIN" --headless --path "$WORKSPACE_DIR" --export-release "iOS" "$EXPORT_PATH"

if [ ! -d "$EXPORT_PATH" ]; then
	echo "Failed to generate $EXPORT_PATH" >&2
	exit 1
fi

INFO_PLIST="$WORKSPACE_DIR/build/NeoChameleon/NeoChameleon-Info.plist"
PBXPROJ="$EXPORT_PATH/project.pbxproj"

if [ -f "$INFO_PLIST" ]; then
	# Empty privacy usage keys → App Store Connect prepare fails.
	for key in NSCameraUsageDescription NSMicrophoneUsageDescription NSPhotoLibraryUsageDescription; do
		val="$(/usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true)"
		if [ -z "$val" ]; then
			/usr/libexec/PlistBuddy -c "Delete :$key" "$INFO_PLIST" 2>/dev/null || true
			echo "Removed empty $key from Info.plist"
		fi
	done

	# Empty CFBundleIcons can block Asset Catalog icons during ASC validation.
	for key in CFBundleIcons "CFBundleIcons~ipad"; do
		/usr/libexec/PlistBuddy -c "Delete :$key" "$INFO_PLIST" 2>/dev/null || true
	done
fi

# Avoid CFBundleVersion collisions with previous TestFlight / ASC uploads.
if [ -f "$PBXPROJ" ] && [ -n "${CI_BUILD_NUMBER:-}" ]; then
	sed -i.bak "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER}/g" "$PBXPROJ"
	rm -f "${PBXPROJ}.bak"
	echo "Set CURRENT_PROJECT_VERSION=${CI_BUILD_NUMBER}"
fi

echo "Generated $EXPORT_PATH for Xcode Cloud"
