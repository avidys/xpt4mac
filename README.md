# xpt4mac

A native macOS document-based application for previewing SAS transport (`.xpt`) datasets. The project ships with a SwiftUI interface that renders XPT data in an Excel-like table and associates the `.xpt` extension with the app so you can right-click any transport file and choose **Open With → XPTViewer** once the app is installed.

## Project layout

- `XPTViewer/` – macOS app sources and Xcode project
  - `XPTViewer.xcodeproj` – ready-to-open Xcode project
  - `XPTViewer/` – Swift sources, SwiftUI views, resources, and assets

## Downloading a packaged build

You can download a ready-to-run build without opening Xcode:

1. Open the repository’s **Actions** tab on GitHub.
2. Run the **Build XPTViewer** workflow via **Run workflow** (or pick the latest successful run on the `main` branch).
3. After the run completes, expand the job and download the `XPTViewer-macOS` artifact. The ZIP file contains `XPTViewer.app` packaged and ready to copy into `/Applications`.

Artifacts remain available for 14 days after each workflow completes. Re-run the workflow whenever you need a refreshed build.

## Building the app

1. Open `XPTViewer/XPTViewer.xcodeproj` in Xcode 15 or newer on macOS 13+.
2. Select the **XPTViewer** scheme and build/run (`⌘R`).
3. The app launches ready to open `.xpt` files via **File → Open…** or by double-clicking files associated with the app.

## Installing the app

To install a shareable `.app` bundle that macOS will register for `.xpt` files:

1. Download the packaged ZIP from the build workflow (above) **or** archive the app from Xcode following the steps below.
2. If you downloaded the ZIP, unzip it and move `XPTViewer.app` to `/Applications`.
3. In Xcode, choose **Product → Archive** with the **XPTViewer** scheme selected.
4. When the archive finishes, click **Distribute App** in the Organizer window.
5. Choose **Copy App**, then **Next**, and pick an output folder (for local distribution) or use **Built Products** to export the unsigned `.app`.
6. Move the exported `XPTViewer.app` to `/Applications` (or another folder in your `PATH`).
7. On first launch you may need to right-click the app and select **Open** to approve the unsigned binary.

After the app is in `/Applications`, Finder’s **Open With** menu and double-clicking `.xpt` files will route to XPTViewer because the document type is declared in `Info.plist`.
1. In Xcode, choose **Product → Archive** with the **XPTViewer** scheme selected.
2. When the archive finishes, click **Distribute App** in the Organizer window.
3. Choose **Copy App**, then **Next**, and pick an output folder (for local distribution) or use **Built Products** to export the unsigned `.app`.
4. Move the exported `XPTViewer.app` to `/Applications` (or another folder in your `PATH`).
5. On first launch you may need to right-click the app and select **Open** to approve the unsigned binary.

After the app is in `/Applications`, Finder’s **Open With** menu and double-clicking `.xpt` files will route to XPTViewer because the document type is declared in `Info.plist`.
Xcode automatically registers the document type described in `Info.plist` so that the installer associates `.xpt` files with XPTViewer. After building an archive and installing the resulting `.app`, macOS Finder will include XPTViewer in the contextual menu when right-clicking an `.xpt` file.

## Features

- Document-based macOS application using SwiftUI.
- Automatic association with `.xpt` (SAS transport) files.
- Parses dataset metadata (variable names, labels, creation/modification timestamps) and renders rows in a scrollable table.
- IBM 360 floating point decoding for numeric columns and whitespace-trimming for character fields.

## Icons

Placeholder icon filenames are declared in `Assets.xcassets/AppIcon.appiconset/Contents.json`. Replace them with your artwork before distributing the app.
