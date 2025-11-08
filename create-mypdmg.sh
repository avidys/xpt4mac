#!/bin/bash

# brew install create-dmg
# xcrun notarytool store-credentials "AC_PASSWORD" --apple-id $EMAIL --team-id $TEAM_ID

set -exu

APP_BUNDLE="$1"
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Usage: $0 <app-bundle-path>"
  exit 1
fi

# Extract version and name from the app bundle
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")

if [[ -z "$VERSION" ]]; then
  echo "Error: Could not determine version from Info.plist"
  exit 1
fi

APPNAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleName" "$INFO_PLIST")

if [[ -z "$APPNAME" ]]; then
  echo "Error: Could not determine name from Info.plist"
  exit 1
fi

IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | awk '{print $2}')

if [[ -z "$IDENTITY" ]]; then
  echo "Error: Could not determine signing identity. In order to sign the app, you need to request a Developer ID Application certificate from Apple."
  exit 1
fi

DMG_NAME="$APPNAME-$VERSION.dmg"
DMG_PATH="./$DMG_NAME"
VOLUME_NAME="$APPNAME $VERSION"

echo "Creating DMG for $APPNAME $VERSION -> $DMG_PATH"

# Create DMG (using create-dmg)
create-dmg \
  --volname "$VOLUME_NAME" \
  --volicon "$APP_BUNDLE/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "${APPNAME}.app" 200 190 \
  --hide-extension "${APPNAME}.app" \
  --app-drop-link 600 185 \
  --codesign "$IDENTITY" \
  --notarize AC_PASSWORD \
  "$DMG_PATH" \
  "$APP_BUNDLE"