#!/bin/bash
set -euo pipefail

# Build SensibleSideButtons from the command line
# Requires: Xcode (full install, not just Command Line Tools)
#
# Usage:
#   ./build.sh                  # Release, Swift target (default)
#   ./build.sh Debug            # Debug, Swift target
#   ./build.sh Release objc     # Release, ObjC target
#   ./build.sh Debug swift      # Debug, Swift target

BUILD_DIR="build"
CONFIG="${1:-Release}"
VARIANT="${2:-swift}"
APP_NAME="SensibleSideButtons"

if [ "$VARIANT" = "swift" ]; then
    TARGET="SensibleSideButtonsSwift"
else
    TARGET="SensibleSideButtons"
fi

echo "==> Building $APP_NAME ($CONFIG, $VARIANT target)..."

xcodebuild \
    -project SwipeSimulator.xcodeproj \
    -target "$TARGET" \
    -configuration "$CONFIG" \
    -arch arm64 -arch x86_64 \
    SYMROOT="$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ENABLE_HARDENED_RUNTIME=YES \
    | tail -5

APP_PATH="$BUILD_DIR/$CONFIG/$APP_NAME.app"

if [ -d "$APP_PATH" ]; then
    echo "==> Build succeeded: $APP_PATH"
    echo ""
    echo "To run:  open $APP_PATH"
    echo "To install: cp -R $APP_PATH /Applications/"
else
    echo "==> Build failed."
    exit 1
fi
