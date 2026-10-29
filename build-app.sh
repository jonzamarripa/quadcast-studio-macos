#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SWIFT_ARGS=(--package-path "$ROOT")
# Optional build settings for restricted development workspaces. No arbitrary command text.
if [[ "${BUILD_SYSTEM:-}" == "native" ]]; then SWIFT_ARGS+=(--build-system native); fi
if [[ "${DISABLE_PACKAGE_SANDBOX:-0}" == "1" ]]; then SWIFT_ARGS+=(--disable-sandbox); fi

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
  swift test "${SWIFT_ARGS[@]}"
fi

echo "[2/5] Compiling native release binary (QuadCastStudio only)..."
if ! swift build "${SWIFT_ARGS[@]}" -c release --product QuadCastStudio; then
  echo "Release compilation failed. If SwiftUI/SDK modules are unavailable, install full Xcode and select it." >&2
  exit 1
fi

APP="$ROOT/dist/QuadCast Studio.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
mkdir -p "$MACOS" "$RESOURCES"
BIN_DIR="$(swift build "${SWIFT_ARGS[@]}" -c release --show-bin-path)"
cp "$BIN_DIR/QuadCastStudio" "$MACOS/QuadCastStudio"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
chmod 755 "$MACOS/QuadCastStudio"

echo "[3/5] Copying the unchanged application icon..."
# Preserved from the working v0.1.1 app; no icon redesign in this release.
cp "$ROOT/Resources/QuadCastStudio.icns" "$RESOURCES/QuadCastStudio.icns"

echo "[4/5] Ad-hoc signing the local application..."
/usr/bin/codesign --force --sign - "$APP"

echo "[5/5] Build complete."
if [[ "$DEVELOPER_DIR_SELECTED" == *"/CommandLineTools"* ]]; then
  echo "NOTE: Unit tests were NOT run; do not treat this as a fully verified release."
fi
echo "Open Finder and double-click: $APP"
echo "Or run: open '$APP'"
