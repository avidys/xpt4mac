# PRODUCT_BUNDLE_IDENTIFIER = com.avidys.XPTMacViewer;

- SUBJID, USUBJID, STUDYID, DOMAIN are always factor
- when a table is exported, open the folder automatically
- add "copy to clipboard" button in popups

- detect ISO date-time as date-time; all columns names ending with DTC are iso date or date-time

## Command Line Build

### Basic build:

```bash
xcodebuild -project XPTViewer/XPTViewer.xcodeproj -scheme XPTViewer -configuration Release build
```

### Build an archive (for distribution):

```bash
xcodebuild -project XPTViewer/XPTViewer.xcodeproj \
           -scheme XPTViewer \
           -configuration Release \
           -archivePath build/XPTViewer.xcarchive \
           -destination 'generic/platform=macOS,name=Any Mac' \
           archive
```

### Quick debug build:

```bash
xcodebuild -project XPTViewer/XPTViewer.xcodeproj \
           -scheme XPTViewer \
           build
```

## Finding the Executable

After building, the executable is located at:
Debug build:
~/
~/Library/Developer/Xcode/DerivedData/XPTViewer-*/Build/Products/Debug/XPTViewer.app
Release build:
~/Library/Developer/Xcode/DerivedData/XPTViewer-*/Build/Products/Release/XPTViewer.app
Archive build:
app
build/XPTViewer.xcarchive/Products/Applications/XPTViewer.app

Quick way to find it:
```bash
# Find the most recent buildfind 
~/Library/Developer/Xcode/DerivedData -name "XPTViewer.app" -type d | head -1
# Or use xcodebuild to show the build path
xcodebuild -project XPTViewer/XPTViewer.xcodeproj -scheme XPTViewer -showBuildSettings | grep -m 1 "BUILT_PRODUCTS_DIR"
```

## Signing

```bash
security find-identity -v -p codesigning
codesign --deep --force --verify --verbose \
         --sign "Developer ID Application: Your Name (TEAM_ID)" \
         --options runtime \
         XPTViewer.app
# testing
codesign --deep --force --verify --verbose \
         --sign "Apple Development: Your Name (TEAM_ID)" \
         XPTViewer.app
```

## Verify signature

```bash
codesign --verify --verbose XPTViewer.app
spctl --assess --verbose XPTViewer.app
```

## Notarize (for Developer ID distribution)

```bash
xcrun notarytool submit XPTViewer.zip \
       --apple-id "avidys@gmail.com" \
       --team-id "Avidys" \
       --password "Cristal" \
       --wait
```

## staple

```bash
xcrun stapler staple XPTViewer.app
```

## script to test

```bash
# Quick build and launch
./test-app.sh

# Clean build (removes old build products)
./test-app.sh clean

# Build Release configuration
CONFIGURATION=Release ./test-app.sh
```

ditto -c -k --sequesterRsrc --keepParent XPTViewer.app XPTViewer.zip
