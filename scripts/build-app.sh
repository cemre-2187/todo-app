#!/bin/zsh
# MacTodo.app paketini oluşturur: ./scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# SwiftUI macro'ları Xcode araç zincirini gerektirir.
if [[ -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

swift build -c release

APP=build/MacTodo.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/MacTodo" "$APP/Contents/MacOS/MacTodo"

# İkon: PNG çiz, tüm boyutlara ölçekle, .icns'e çevir.
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
swift scripts/make-icon.swift build/AppIcon.png >/dev/null
for px in 16 32 128 256 512; do
  sips -z $px $px build/AppIcon.png --out "$ICONSET/icon_${px}x${px}.png" >/dev/null
  sips -z $((px * 2)) $((px * 2)) build/AppIcon.png --out "$ICONSET/icon_${px}x${px}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MacTodo</string>
  <key>CFBundleDisplayName</key><string>To Do</string>
  <key>CFBundleIdentifier</key><string>com.cemre.mactodo</string>
  <key>CFBundleExecutable</key><string>MacTodo</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDevelopmentRegion</key><string>tr</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Hazır: $APP"
echo "Uygulamalar klasörüne kopyalamak için: cp -R $APP /Applications/"
