#!/bin/bash

# Configuration
APP_NAME="Vela IPTV"
APP_PATH="build/Vela.app"
DMG_NAME="VelaIPTV.dmg"
DMG_PATH="build/$DMG_NAME"
VOLUME_NAME="Vela IPTV Installer"

echo "[Vela IPTV] Creating DMG..."

# 1. Clean up previous DMG
if [ -f "$DMG_PATH" ]; then
    rm "$DMG_PATH"
fi

# 2. Create a temporary folder for the DMG contents
TEMP_DIR="build/temp_dmg"
mkdir -p "$TEMP_DIR"
cp -R "$APP_PATH" "$TEMP_DIR/"

# 3. Add a symlink to Applications folder
ln -s /Applications "$TEMP_DIR/Applications"

# 4. Create the DMG using hdiutil
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$TEMP_DIR" -ov -format UDZO "$DMG_PATH"

# 5. Clean up
rm -rf "$TEMP_DIR"

echo "[Vela IPTV] DMG created at $DMG_PATH"
