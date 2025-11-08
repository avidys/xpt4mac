# xpt4mac

A simple native macOS document-based application for previewing SAS transport (`.xpt`) datasets. The project ships with a SwiftUI interface that renders XPT data in an Excel-like table and associates the `.xpt` extension with the app so you can right-click any transport file and choose **Open With → XPTViewer** once the app is installed.

## Downloading a packaged build

You can download a ready-to-run build without opening Xcode:

## Building the app

### Using the test script (recommended)

```bash
./test-app.sh          # Quick build and launch
./test-app.sh clean    # Clean build
```

### Using Xcode

1. Open `XPTViewer/XPTViewer.xcodeproj` in Xcode 15 or newer on macOS 13+.
2. Select the **XPTViewer** scheme and build/run (`⌘R`).
3. The app launches ready to open `.xpt` files via **File → Open…** or by double-clicking files associated with the app.

### Using command line

```bash
# Debug build
xcodebuild -project XPTViewer/XPTViewer.xcodeproj \
           -scheme XPTViewer \
           build

# Release build
xcodebuild -project XPTViewer/XPTViewer.xcodeproj \
           -scheme XPTViewer \
           -configuration Release \
           build
```

## Installing the app

To install a shareable `.app` bundle that macOS will register for `.xpt` files:

1. Download the packaged ZIP from here
2. If you downloaded the ZIP, unzip it and move `XPTViewer.app` to `/Applications`.

After the app is in `/Applications`, Finder's **Open With** menu and double-clicking `.xpt` files will route to XPTViewer because the document type is declared in `Info.plist`.

## Features

- Document-based macOS application using SwiftUI.
- Automatic association with `.xpt` (SAS transport) files.
- Parses dataset metadata (variable names, labels, creation/modification timestamps) and renders rows in a scrollable table.
- IBM 360 floating point decoding for numeric columns and whitespace-trimming for character fields.
- Async statistics calculation for large datasets.
- Comprehensive variable statistics with charts and visualizations.

