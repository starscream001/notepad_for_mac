#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-$(cat VERSION)}"
UNIVERSAL="${UNIVERSAL:-0}"
if [[ "$UNIVERSAL" == "1" ]]; then
  swift build -c release --triple arm64-apple-macosx13.0 --product NotepadMac
  ARM_DIR="$(swift build -c release --triple arm64-apple-macosx13.0 --show-bin-path)"
  swift build -c release --triple x86_64-apple-macosx13.0 --product NotepadMac
  INTEL_DIR="$(swift build -c release --triple x86_64-apple-macosx13.0 --show-bin-path)"
  mkdir -p dist/universal
  lipo -create "$ARM_DIR/NotepadMac" "$INTEL_DIR/NotepadMac" -output dist/universal/NotepadMac
  BIN_DIR=dist/universal
else
  swift build -c release --product NotepadMac
  BIN_DIR="$(swift build -c release --show-bin-path)"
fi
APP="dist/Notepad Mac.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NotepadMac" "$APP/Contents/MacOS/NotepadMac"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
swift scripts/icon.swift dist/AppIcon.iconset
iconutil -c icns dist/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
ARCH="$(uname -m)"
if [[ "$UNIVERSAL" == "1" ]]; then ARCH=universal; fi
ARCHIVE="dist/Notepad-Mac-${VERSION}-${ARCH}.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
(cd dist && shasum -a 256 "$(basename "$ARCHIVE")") > "$ARCHIVE.sha256"
printf 'Application: %s\nArchive: %s\n' "$APP" "$ARCHIVE"
