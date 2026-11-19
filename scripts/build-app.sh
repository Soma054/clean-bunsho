#!/usr/bin/env bash
# くりーんぶんしょ.app を組み立て、アドホック署名して .dmg を作る（macOS で実行）
#
#   VERSION=0.1.0 BUILD_NUMBER=1 scripts/build-app.sh
#
# 出力: dist/くりーんぶんしょ.app, dist/${DMG_NAME:-CleanBunsho-$VERSION}.dmg
set -euo pipefail

VERSION="${VERSION:-0.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DMG_NAME="${DMG_NAME:-CleanBunsho-$VERSION}"
APP_NAME="くりーんぶんしょ"

cd "$(dirname "$0")/.."

echo "==> swift build (release, arm64)"
swift build -c release --arch arm64 --product CleanBunsho
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

echo "==> .app を組み立て"
rm -rf dist
APP="dist/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CleanBunsho" "$APP/Contents/MacOS/CleanBunsho"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> アドホック署名"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --verbose=2 "$APP"

echo "==> .dmg を作成"
STAGE="dist/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "dist/$DMG_NAME.dmg"
rm -rf "$STAGE"

echo "==> 完了: dist/$DMG_NAME.dmg"
