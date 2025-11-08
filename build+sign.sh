#!/bin/bash
set -euo pipefail

PROJECT="XPTViewer/XPTViewer.xcodeproj"
SCHEME="XPTViewer"
ARCHIVE_PATH="build/XPTViewer.xcarchive"
APP_PATH="build/XPTViewer.app"
ZIP_PATH="build/XPTViewer.zip"

# Build archive
echo "Building archive..."
xcodebuild -project "$PROJECT" \
           -scheme "$SCHEME" \
           -configuration Release \
           -archivePath "$ARCHIVE_PATH" \
           -destination 'generic/platform=macOS,name=Any Mac' \
           archive

# Extract app from archive
echo "Extracting app..."
rm -rf "$APP_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/XPTViewer.app" "$APP_PATH"

# Sign the app (replace with your identity)
SIGNING_IDENTITY="Developer ID Application: Avidys LLC (59PTHDP385)"
echo "Signing app with $SIGNING_IDENTITY..."
codesign --deep --force --verify --verbose \
         --sign "$SIGNING_IDENTITY" \
         --options runtime \
         "$APP_PATH"

# Verify signature
echo "Verifying signature..."
codesign --verify --verbose "$APP_PATH"
spctl --assess --verbose "$APP_PATH"

# Package as ZIP
echo "Packaging..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Done! App is at: $APP_PATH"
echo "ZIP is at: $ZIP_PATH"

xcrun altool --notarize-app --primary-bundle-id "com.avidys.XPTMacViewer" --username "avidys@gmail.com" --password "Cristal321!" --file $ZIP_PATH    