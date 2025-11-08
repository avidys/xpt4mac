#!/bin/bash
# Script to extract icon images from XPT.icns and populate XPT.appiconset

set -euo pipefail

ICNS_FILE="XPTViewer/XPTViewer/Assets.xcassets/XPT.icns"
ICONSET_DIR="XPTViewer/XPTViewer/Assets.xcassets/XPT.appiconset"
TEMP_ICONSET="/tmp/xpt_extract.iconset"

# Check if .icns file exists
if [ ! -f "$ICNS_FILE" ]; then
    echo "Error: $ICNS_FILE not found"
    echo "Please ensure XPT.icns exists in Assets.xcassets"
    exit 1
fi

echo "Extracting icons from $ICNS_FILE..."

# Extract iconset from .icns
iconutil --convert iconset --output "$TEMP_ICONSET" "$ICNS_FILE" 2>&1

# Ensure appiconset directory exists
mkdir -p "$ICONSET_DIR"

# Copy all extracted images to appiconset
echo "Copying icons to $ICONSET_DIR..."
if [ -d "$TEMP_ICONSET" ]; then
    # Map iconset naming to appiconset naming
    # iconset uses: icon_16x16.png, icon_16x16@2x.png, etc.
    # appiconset uses the same naming
    
    for icon in "$TEMP_ICONSET"/*.png; do
        if [ -f "$icon" ]; then
            filename=$(basename "$icon")
            cp "$icon" "$ICONSET_DIR/$filename"
            echo "  Copied: $filename"
        fi
    done
    
    # Clean up temp directory
    rm -rf "$TEMP_ICONSET"
    
    echo ""
    echo "✓ Icon extraction complete!"
    echo "Icons are now in: $ICONSET_DIR"
    echo ""
    echo "Next steps:"
    echo "1. Rebuild the app"
    echo "2. Verify the icon appears in Finder and the app bundle"
else
    echo "Error: Failed to extract iconset"
    exit 1
fi

