#!/bin/bash

# Build script for creating a release build of Sensible Side Buttons
# Usage: ./build-release.sh [version] [team_id]
# Team ID is optional - if not provided, builds unsigned release

set -e

VERSION="${1:-1.1.0}"
TEAM_ID="${2:-}"
BUILD_DIR="build/release-${VERSION}"
PRODUCT_NAME="SensibleSideButtons"
ROOT_DIR="$(pwd)"

echo "🔨 Building Sensible Side Buttons v${VERSION}"
echo "=================================="

if [ -z "$TEAM_ID" ]; then
    echo "⚠️  No Team ID provided - building UNSIGNED release"
    echo "   (This works fine! Users just right-click → Open to launch)"
    BUILD_UNSIGNED=1
else
    echo "✅ Building signed release (Team ID: $TEAM_ID)"
    BUILD_UNSIGNED=0
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
xcodebuild clean -project SwipeSimulator.xcodeproj -scheme SensibleSideButtons -configuration Release -derivedDataPath "$BUILD_DIR"

if [ $BUILD_UNSIGNED -eq 1 ]; then
    # Unsigned build - simple xcodebuild
    echo "📦 Building release (unsigned)..."
    xcodebuild build \
        -project SwipeSimulator.xcodeproj \
        -scheme SensibleSideButtons \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        -verbose
    
    # Copy app for distribution
    mkdir -p "$BUILD_DIR/export"
    cp -r "$BUILD_DIR/Build/Products/Release/SensibleSideButtons.app" "$BUILD_DIR/export/"
else
    # Signed build - archive and export
    echo "📦 Creating archive..."
    xcodebuild archive \
        -project SwipeSimulator.xcodeproj \
        -scheme SensibleSideButtons \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR" \
        -archivePath "$BUILD_DIR/${PRODUCT_NAME}.xcarchive" \
        -verbose

    # Export archive
    echo "📤 Exporting application..."

    # Create exportOptions.plist
    cat > "$BUILD_DIR/exportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
EOF

    xcodebuild -exportArchive \
        -archivePath "$BUILD_DIR/${PRODUCT_NAME}.xcarchive" \
        -exportPath "$BUILD_DIR/export" \
        -exportOptionsPlist "$BUILD_DIR/exportOptions.plist" \
        -verbose

    # Verify code signature
    echo "✅ Verifying code signature..."
    codesign --verify --deep --strict --verbose=2 "$BUILD_DIR/export/${PRODUCT_NAME}.app"

    # Display code signing info
    echo "📋 Code Signing Details:"
    codesign -dvvv "$BUILD_DIR/export/${PRODUCT_NAME}.app" | grep -E "Authority|Identifier|Version"
fi

# Create DMG
echo "📀 Creating DMG..."
if command -v create-dmg >/dev/null 2>&1; then
    if ! create-dmg \
        --volname "Sensible Side Buttons" \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${PRODUCT_NAME}.app" 100 200 \
        "$BUILD_DIR/${PRODUCT_NAME}-${VERSION}.dmg" \
        "$BUILD_DIR/export/${PRODUCT_NAME}.app"; then
        echo "⚠️  create-dmg failed (likely Finder/AppleScript permissions)."
        echo "   Falling back to plain DMG creation with hdiutil"

        TMP_DMG_DIR="$BUILD_DIR/dmg-src"
        rm -rf "$TMP_DMG_DIR"
        mkdir -p "$TMP_DMG_DIR"
        cp -R "$BUILD_DIR/export/${PRODUCT_NAME}.app" "$TMP_DMG_DIR/"
        hdiutil create \
            -volname "Sensible Side Buttons" \
            -srcfolder "$TMP_DMG_DIR" \
            -ov \
            -format UDZO \
            "$BUILD_DIR/${PRODUCT_NAME}-${VERSION}.dmg" >/dev/null
        rm -rf "$TMP_DMG_DIR"
    fi

    # Remove create-dmg intermediate writable images if they remain after failures/retries.
    find "$BUILD_DIR" -maxdepth 1 -type f -name "rw.*.${PRODUCT_NAME}-${VERSION}.dmg" -delete
else
    echo "⚠️  create-dmg not found. Install with: brew install create-dmg"
    echo "   Falling back to plain DMG creation with hdiutil"

    TMP_DMG_DIR="$BUILD_DIR/dmg-src"
    rm -rf "$TMP_DMG_DIR"
    mkdir -p "$TMP_DMG_DIR"
    cp -R "$BUILD_DIR/export/${PRODUCT_NAME}.app" "$TMP_DMG_DIR/"
    hdiutil create \
        -volname "Sensible Side Buttons" \
        -srcfolder "$TMP_DMG_DIR" \
        -ov \
        -format UDZO \
        "$BUILD_DIR/${PRODUCT_NAME}-${VERSION}.dmg" >/dev/null
    rm -rf "$TMP_DMG_DIR"
fi

# Create ZIP
echo "📦 Creating ZIP archive..."
cd "$BUILD_DIR/export"
zip -r "../${PRODUCT_NAME}-${VERSION}.zip" "${PRODUCT_NAME}.app" > /dev/null
cd "$ROOT_DIR"

# Generate checksums
echo "🔐 Generating checksums..."
cd "$BUILD_DIR"
if [ -f "${PRODUCT_NAME}-${VERSION}.dmg" ]; then
    shasum -a 256 "${PRODUCT_NAME}-${VERSION}.dmg" > "${PRODUCT_NAME}-${VERSION}.dmg.sha256"
fi
if [ -f "${PRODUCT_NAME}-${VERSION}.zip" ]; then
    shasum -a 256 "${PRODUCT_NAME}-${VERSION}.zip" > "${PRODUCT_NAME}-${VERSION}.zip.sha256"
fi
cd "$ROOT_DIR"

# Display results
echo ""
echo "✅ Build Complete!"
echo "=================================="
echo "📁 Output Directory: $(pwd)/$BUILD_DIR"
echo ""
echo "📦 Artifacts Created:"
ls -lh \
    "$BUILD_DIR/${PRODUCT_NAME}-${VERSION}.dmg" \
    "$BUILD_DIR/${PRODUCT_NAME}-${VERSION}.zip" \
    "$BUILD_DIR/${PRODUCT_NAME}-${VERSION}.dmg.sha256" \
    "$BUILD_DIR/${PRODUCT_NAME}-${VERSION}.zip.sha256" 2>/dev/null || echo "   (Expected artifacts missing; check logs above)"
echo ""

if [ $BUILD_UNSIGNED -eq 1 ]; then
    echo "Next Steps (Unsigned Build):"
    echo "1. Verify the app: open '$BUILD_DIR/export/${PRODUCT_NAME}.app'"
    echo "2. Test functionality with your mouse"
    echo "3. Upload DMG/ZIP to GitHub releases"
    echo "4. Users can launch with: right-click → Open"
else
    echo "Next Steps (Signed Build):"
    echo "1. Verify the app: open '$BUILD_DIR/export/${PRODUCT_NAME}.app'"
    echo "2. Test functionality with your mouse"
    echo "3. Optionally notarize (removes warnings):"
    echo "   xcrun notarytool submit $BUILD_DIR/${PRODUCT_NAME}-${VERSION}.dmg \\"
    echo "     --apple-id 'your-email@example.com' \\"
    echo "     --password 'app-specific-password' \\"
    echo "     --team-id '${TEAM_ID}' --wait"
    echo "4. Upload to GitHub releases"
fi
