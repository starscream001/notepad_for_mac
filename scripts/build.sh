#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-$(cat VERSION)}"
UNIVERSAL="${UNIVERSAL:-0}"
if [[ "$UNIVERSAL" == "1" ]]; then
  swift build -c release --triple arm64-apple-macosx13.0 --product NotepadMac
  swift build -c release --triple arm64-apple-macosx13.0 --product NotepadUpdater
  ARM_DIR="$(swift build -c release --triple arm64-apple-macosx13.0 --show-bin-path)"
  swift build -c release --triple x86_64-apple-macosx13.0 --product NotepadMac
  swift build -c release --triple x86_64-apple-macosx13.0 --product NotepadUpdater
  INTEL_DIR="$(swift build -c release --triple x86_64-apple-macosx13.0 --show-bin-path)"
  mkdir -p dist/universal
  lipo -create "$ARM_DIR/NotepadMac" "$INTEL_DIR/NotepadMac" -output dist/universal/NotepadMac
  lipo -create "$ARM_DIR/NotepadUpdater" "$INTEL_DIR/NotepadUpdater" -output dist/universal/NotepadUpdater
  BIN_DIR=dist/universal
else
  swift build -c release --product NotepadMac
  swift build -c release --product NotepadUpdater
  BIN_DIR="$(swift build -c release --show-bin-path)"
fi
APP="dist/Notepad Mac.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp "$BIN_DIR/NotepadMac" "$APP/Contents/MacOS/NotepadMac"
cp "$BIN_DIR/NotepadUpdater" "$APP/Contents/Helpers/NotepadUpdater"
cp Resources/Vendor/formatter.js "$APP/Contents/Resources/formatter.js"
cp Resources/Vendor/sql-formatter-LICENSE.txt "$APP/Contents/Resources/sql-formatter-LICENSE.txt"
cp Resources/Vendor/marked.js "$APP/Contents/Resources/marked.js"
cp Resources/Vendor/marked-LICENSE.txt "$APP/Contents/Resources/marked-LICENSE.txt"
cp Resources/AppIcon.png "$APP/Contents/Resources/AppIcon.png"
cp Resources/Palettes.json "$APP/Contents/Resources/Palettes.json"
cp Resources/SyncCore.js "$APP/Contents/Resources/SyncCore.js"
cp Resources/GitHubOAuth.json "$APP/Contents/Resources/GitHubOAuth.json"
cp Resources/Donation.json "$APP/Contents/Resources/Donation.json"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
swift scripts/icon.swift dist/AppIcon.iconset
iconutil -c icns dist/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP/Contents/Helpers/NotepadUpdater"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
ARCH="$(uname -m)"
if [[ "$UNIVERSAL" == "1" ]]; then ARCH=universal; fi
ARCHIVE="dist/Notepad-Mac-${VERSION}-${ARCH}.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
(cd dist && shasum -a 256 "$(basename "$ARCHIVE")") > "$ARCHIVE.sha256"
printf 'Application: %s\nArchive: %s\n' "$APP" "$ARCHIVE"
