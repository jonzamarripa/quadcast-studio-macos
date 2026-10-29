#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This app must be built on macOS with Apple Command Line Tools or Xcode." >&2
  exit 1
fi
if ! command -v swift >/dev/null 2>&1; then
  echo "Swift is unavailable. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

# Apple Command Line Tools often omit the XCTest frameworks needed by SwiftPM's
# XCTest test target. The release executable can still be compiled directly.
# Don't silently report skipped tests as passing.
DEVELOPER_DIR_SELECTED="$(/usr/bin/xcode-select -p 2>/dev/null || true)"
echo "Selected developer directory: ${DEVELOPER_DIR_SELECTED:-unknown}"
if [[ "$DEVELOPER_DIR_SELECTED" == *"/CommandLineTools"* ]]; then
  echo "[1/5] SKIPPED unit tests: Command Line Tools do not provide XCTest."
  echo "      Install/select full Xcode to run 'swift test' later."
elif [[ "${SKIP_TESTS:-0}" == "1" ]]; then
  echo "[1/5] SKIPPED unit tests at user request (SKIP_TESTS=1)."
else
  echo "[1/5] Building and running XCTest unit tests..."
  swift test
fi

echo "[2/5] Compiling native release binary (QuadCastStudio only)..."
if ! swift build -c release --product QuadCastStudio; then
  echo "Release compilation failed. If SwiftUI/SDK modules are unavailable, install full Xcode and select it." >&2
  exit 1
fi

APP="$ROOT/dist/QuadCast Studio.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/release/QuadCastStudio" "$MACOS/QuadCastStudio"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
chmod 755 "$MACOS/QuadCastStudio"

echo "[3/5] Generating the application icon..."
ICONSET="$ROOT/.build/QuadCastStudio.iconset"
mkdir -p "$ICONSET"
for entry in "16:icon_16x16.png" "32:icon_16x16@2x.png" "32:icon_32x32.png" "64:icon_32x32@2x.png" "128:icon_128x128.png" "256:icon_128x128@2x.png" "256:icon_256x256.png" "512:icon_256x256@2x.png" "512:icon_512x512.png"; do
  px="${entry%%:*}"
  filename="${entry#*:}"
  /usr/bin/sips -z "$px" "$px" "$ROOT/Resources/Icon1024.png" \
    --out "$ICONSET/$filename" >/dev/null
done
cp "$ROOT/Resources/Icon1024.png" "$ICONSET/icon_512x512@2x.png"
/usr/bin/iconutil -c icns "$ICONSET" -o "$RESOURCES/QuadCastStudio.icns"

echo "[4/5] Ad-hoc signing the local application..."
/usr/bin/codesign --force --sign - "$APP"

echo "[5/5] Build complete."
if [[ "$DEVELOPER_DIR_SELECTED" == *"/CommandLineTools"* ]]; then
  echo "NOTE: Unit tests were NOT run; do not treat this as a fully verified release."
fi
echo "Open Finder and double-click: $APP"
echo "Or run: open '$APP'"
