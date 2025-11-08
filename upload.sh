
#!/bin/bash
# Upload script for XPTViewer to App Store Connect
# Usage: ./upload.sh [--api-key]

set -euo pipefail

ZIP_PATH="build/XPTViewer.zip"
BUNDLE_ID="com.avidys.XPTMacViewer"

# Check if ZIP exists
if [ ! -f "$ZIP_PATH" ]; then
    echo "Error: $ZIP_PATH not found. Run build+sign.sh first."
    exit 1
fi

# Method 1: Using API Key (Recommended - more secure)
if [[ "${1:-}" == "--api-key" ]]; then
    # You need to create an API key in App Store Connect:
    # 1. Go to https://appstoreconnect.apple.com
    # 2. Users and Access → Keys → App Store Connect API
    # 3. Create a new key and download the .p8 file
    # 4. Note the Key ID and Issuer ID
    
    API_KEY_PATH="${API_KEY_PATH:-/Users/jean/dev/xpt4mac/Assets/AuthKey_FWY432868K.p8}"  # Path to your .p8 key file
    API_KEY_ID="${API_KEY_ID:-FWY432868K}"                    # Your Key ID
    API_ISSUER_ID="${API_ISSUER_ID:-1aef3be8-ac80-4b0d-8700-9c9a3dff3ee7}"  # Your Issuer ID
    
    echo "Uploading to App Store Connect using API key..."
    xcrun altool --upload-app \
        --file "$ZIP_PATH" \
        --type macos \
        --apiKey "$API_KEY_ID" \
        --apiIssuer "$API_ISSUER_ID" \
        --verbose

# Method 2: Using Username/Password (Legacy - still works but less secure)
else
    APPLE_ID="${APPLE_ID:-avidys@gmail.com}"
    APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:-}"  # Generate at appleid.apple.com
    
    if [ -z "$APP_SPECIFIC_PASSWORD" ]; then
        echo "Error: APP_SPECIFIC_PASSWORD not set."
        echo "Generate an app-specific password at: https://appleid.apple.com"
        echo "Then run: APP_SPECIFIC_PASSWORD='your-password' ./upload.sh"
        exit 1
    fi
    
    echo "Uploading to App Store Connect using username/password..."
    xcrun altool --upload-app \
        --file "$ZIP_PATH" \
        --type macos \
        --username "$APPLE_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --verbose
fi

echo ""
echo "Upload complete! Check App Store Connect for processing status."

