#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
APP="启动台.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 \
  -framework AppKit \
  -framework Carbon \
  -framework CoreImage \
  -framework ImageIO \
  -framework ServiceManagement \
  -o "$APP/Contents/MacOS/ClassicLaunchpad" \
  Sources/Library.swift \
  Sources/Arrangement.swift \
  Sources/Wallpaper.swift \
  Sources/LaunchpadUI.swift \
  Sources/main.swift
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - "$APP"
echo "built $(pwd)/$APP"
