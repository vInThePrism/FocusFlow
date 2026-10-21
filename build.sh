#!/bin/bash
# Build FocusFlow.app
#   bash build.sh            build, then open it from ./build
#   bash build.sh --install  build, copy to /Applications, then open it
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="FocusFlow"

if ! command -v swift >/dev/null 2>&1; then
    echo "Swift isn't installed. Run: xcode-select --install"
    exit 1
fi

echo "▸ Building (the first build takes a minute)…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/FocusFlow"

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/FocusFlow"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

if [[ "${1:-}" == "--install" ]]; then
    pkill -x FocusFlow 2>/dev/null || true
    sleep 0.5
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    echo "✓ Installed to /Applications/$APP_NAME.app"
    open "/Applications/$APP_NAME.app"
else
    echo "✓ Built $APP"
    open "$APP"
fi
