#!/bin/bash
# Build and launch Mori. Regenerates the Xcode project, builds Debug, and runs.
#
#   ./run.sh            build + launch
#   ./run.sh --release  build the Release configuration
#   ./run.sh --gen      only (re)generate the Xcode project
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="Debug"
[ "${1:-}" = "--release" ] && CONFIG="Release"

# 1. Ensure the CEF wrapper static lib exists (built once).
WRAPPER="third_party/cef/build/libcef_dll_wrapper/libcef_dll_wrapper.a"
if [ ! -f "$WRAPPER" ]; then
  echo "Building libcef_dll_wrapper…"
  ( cd third_party/cef && mkdir -p build && cd build \
      && cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DPROJECT_ARCH=arm64 .. >/dev/null \
      && make libcef_dll_wrapper -j"$(sysctl -n hw.ncpu)" >/dev/null )
fi

# 2. Generate the Xcode project from project.yml.
echo "Generating Xcode project…"
xcodegen generate >/dev/null

[ "${1:-}" = "--gen" ] && { echo "Project generated."; exit 0; }

# 3. Build.
echo "Building ($CONFIG)…"
xcodebuild -project Mori.xcodeproj -scheme Mori -configuration "$CONFIG" \
  -derivedDataPath build/dd build 2>&1 | \
  grep -E "error:|warning: .*Swift|BUILD SUCCEEDED|BUILD FAILED" || true

APP="build/dd/Build/Products/$CONFIG/Mori.app"
[ -d "$APP" ] || { echo "Build failed: $APP not found"; exit 1; }

# 4. Launch (kill any prior instance first).
pkill -f "Mori.app/Contents/MacOS/Mori" 2>/dev/null || true
sleep 0.5
echo "Launching $APP"
open "$APP"
