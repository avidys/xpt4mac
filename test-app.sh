#!/bin/bash
# Quick build and test script for XPTViewer
# Usage: ./test-app.sh [clean]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="XPTViewer/XPTViewer.xcodeproj"
SCHEME="XPTViewer"
CONFIGURATION="${CONFIGURATION:-Debug}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 XPTViewer Quick Test Script${NC}"
echo ""

# Clean if requested
if [[ "${1:-}" == "clean" ]]; then
    echo -e "${YELLOW}🧹 Cleaning build products...${NC}"
    xcodebuild -project "$PROJECT" \
               -scheme "$SCHEME" \
               clean
    rm -rf build
    echo -e "${GREEN}✓ Clean complete${NC}"
    echo ""
fi

# Build the app
echo -e "${BLUE}🔨 Building $CONFIGURATION configuration...${NC}"
BUILD_OUTPUT=$(xcodebuild -project "$PROJECT" \
           -scheme "$SCHEME" \
           -configuration "$CONFIGURATION" \
           -derivedDataPath build/DerivedData \
           build 2>&1)

# Show important build messages
echo "$BUILD_OUTPUT" | grep -E "(error|warning:|BUILD)" || true

# Check build result
if echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
    echo -e "${GREEN}✓ Build succeeded${NC}"
elif echo "$BUILD_OUTPUT" | grep -q "BUILD FAILED"; then
    echo -e "${YELLOW}❌ Build failed! Check errors above.${NC}"
    exit 1
fi

# Find the built app
APP_PATH=$(find build/DerivedData -name "XPTViewer.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    # Fallback to default DerivedData location
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "XPTViewer.app" -type d -newest | head -1)
fi

if [ -z "$APP_PATH" ]; then
    echo -e "${YELLOW}❌ Could not find XPTViewer.app${NC}"
    echo "Try running: xcodebuild -project $PROJECT -scheme $SCHEME -showBuildSettings | grep BUILT_PRODUCTS_DIR"
    exit 1
fi

echo -e "${GREEN}✓ Build complete${NC}"
echo -e "${BLUE}📦 App location: $APP_PATH${NC}"
echo ""

# Kill any existing instances
echo -e "${BLUE}🛑 Stopping any running instances...${NC}"
pkill -f "XPTViewer" || true
sleep 0.5

# Launch the app
echo -e "${BLUE}🚀 Launching XPTViewer...${NC}"
open "$APP_PATH"

echo ""
echo -e "${GREEN}✓ App launched!${NC}"
echo ""
echo "Tips:"
echo "  - Open an .xpt file via File → Open or drag & drop"
echo "  - Check Console.app for any runtime errors"
echo "  - Run './test-app.sh clean' to do a clean build"
echo ""

