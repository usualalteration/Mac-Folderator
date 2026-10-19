#!/bin/bash
# =============================================================================
#  Mac Folderator — build.sh
#  Builds "Mac Folderator.app" and the disk image "Mac Folderator.dmg" (app + Applications shortcut) from Sources/.
#  Run it on a Mac (needs the Xcode Command Line Tools: xcode-select --install).
#
#    ./build.sh            builds dist/Mac Folderator.app and dist/Mac Folderator.dmg
#    ./build.sh --app      builds only the .app
# =============================================================================
set -u
cd "$(dirname "$0")"

VERSION="1.0"
BUILD="$(date +%Y%m%d%H%M)"
NAME="Mac Folderator"
DIST="dist"
APP="$DIST/$NAME.app"
ONLY_APP=0
[ "${1:-}" = "--app" ] && ONLY_APP=1

say() { printf '\033[38;5;149m▸\033[0m %s\n' "$*"; }
die() { printf '\033[38;5;204m✗\033[0m %s\n' "$*"; exit 1; }

[ "$(uname)" = "Darwin" ] || die "Build on a Mac (macOS)."
xcrun --find swiftc >/dev/null 2>&1 || die "Swift compiler not found. Install the Command Line Tools:  xcode-select --install"
[ -f Sources/main.swift ] || die "Sources/main.swift not found."

rm -rf "$DIST"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# ---- compile (universal binary when possible)
say "Compiling…"
BIN="$APP/Contents/MacOS/MacFolderator"
ok_arm=0; ok_x86=0
if swiftc -O -swift-version 5 -target arm64-apple-macos12.0 -o "$DIST/mf-arm64" Sources/*.swift 2>"$DIST/build-arm64.log"; then ok_arm=1; fi
if swiftc -O -swift-version 5 -target x86_64-apple-macos12.0 -o "$DIST/mf-x86_64" Sources/*.swift 2>"$DIST/build-x86_64.log"; then ok_x86=1; fi
if [ $ok_arm -eq 1 ] && [ $ok_x86 -eq 1 ]; then
  lipo -create -output "$BIN" "$DIST/mf-arm64" "$DIST/mf-x86_64" || die "lipo failed"
  say "Universal binary (Apple silicon + Intel)"
elif [ $ok_arm -eq 1 ] || [ $ok_x86 -eq 1 ]; then
  [ $ok_arm -eq 1 ] && cp "$DIST/mf-arm64" "$BIN" || cp "$DIST/mf-x86_64" "$BIN"
  say "Single-architecture binary"
else
  # last resort: build for the machine you are on, and show the real error
  if swiftc -O -swift-version 5 -o "$BIN" Sources/*.swift 2>"$DIST/build.log"; then
    say "Native binary"
  else
    echo "----- compiler output -----"; cat "$DIST/build.log"; echo "---------------------------"
    die "Compilation failed (log: $DIST/build.log). Please send that log to the maintainer."
  fi
fi
rm -f "$DIST"/mf-arm64 "$DIST"/mf-x86_64

# ---- icon
say "Building the icon…"
ICONSET="$DIST/AppIcon.iconset"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" || die "iconutil failed"
rm -rf "$ICONSET"

# ---- Info.plist
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$NAME</string>
<key>CFBundleDisplayName</key><string>$NAME</string>
<key>CFBundleExecutable</key><string>MacFolderator</string>
<key>CFBundleIdentifier</key><string>it.macfolderator.app</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSAppleEventsUsageDescription</key><string>Mac Folderator reads which folders are selected in the Finder.</string>
<key>CFBundleDocumentTypes</key>
<array><dict>
<key>CFBundleTypeName</key><string>Folder</string>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSItemContentTypes</key><array><string>public.folder</string></array>
</dict></array>
</dict></plist>
PLIST

[ -f scripts/uninstall.sh ] || die "scripts/uninstall.sh not found (it goes inside the app and does the uninstall)."
cp scripts/uninstall.sh "$APP/Contents/Resources/uninstall.sh"
chmod +x "$APP/Contents/Resources/uninstall.sh"

codesign --force --deep --sign - "$APP" 2>/dev/null || say "(ad-hoc signing skipped)"
say "Built: $APP"
[ $ONLY_APP -eq 1 ] && exit 0

# ---- disk image (just the app and an Applications shortcut)
say "Creating the disk image…"
STAGE="$DIST/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "$DIST/$NAME.dmg" >/dev/null || die "hdiutil failed"
rm -rf "$STAGE"
cp "$DIST/$NAME.dmg" "$DIST/Mac-Folderator-$VERSION.dmg"
say "Done: $DIST/$NAME.dmg   (version $VERSION, build $BUILD)"
say "For GitHub Releases upload: $DIST/Mac-Folderator-$VERSION.dmg"
echo
echo "Install: open the .dmg and drag \"$NAME\" to Applications."
