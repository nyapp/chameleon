#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$(cd "$ROOT/../../plugins" && pwd)/appreview"
GODOT_PATH="$(cd "$ROOT/../godot" && pwd)"
BIN_DIR="$ROOT/bin"

mkdir -p "$BIN_DIR" "$OUT_DIR"
rm -rf "$OUT_DIR"/appreview.*.xcframework "$OUT_DIR"/appreview.*.a

build_one() {
	local target="$1"
	local arch="$2"
	local simulator="$3"
	(
		cd "$ROOT"
		python3 -m SCons \
			target="$target" \
			arch="$arch" \
			simulator="$simulator" \
			plugin=appreview \
			version=4.0 \
			godot_path="$GODOT_PATH" \
			target_path="$BIN_DIR/" \
			-j"$(sysctl -n hw.ncpu)"
	)
}

echo "==> Building AppReview (device arm64 debug/release)"
build_one debug arm64 no
build_one release arm64 no

echo "==> Building AppReview (simulator arm64 debug/release)"
build_one debug arm64 yes
build_one release arm64 yes

make_xcframework() {
	local target="$1"
	local out="$OUT_DIR/appreview.${target}.xcframework"
	local device="$BIN_DIR/appreview.arm64-ios.${target}.a"
	local sim="$BIN_DIR/appreview.arm64-simulator.${target}.a"
	rm -rf "$out"
	xcodebuild -create-xcframework \
		-library "$device" \
		-library "$sim" \
		-output "$out"
	echo "Wrote $out"
}

make_xcframework debug
make_xcframework release

cat > "$OUT_DIR/appreview.gdip" <<'EOF'
[config]
name="AppReview"
binary="appreview.xcframework"

initialization="register_appreview_types"
deinitialization="unregister_appreview_types"

[dependencies]
linked=[]
embedded=[]
system=["StoreKit.framework", "UIKit.framework"]

capabilities=[]

files=[]

linker_flags=["-ObjC"]

[plist]
EOF

echo "==> Done. Plugin ready at $OUT_DIR"
ls -la "$OUT_DIR"
