#!/bin/bash

echo "🌊 Updating WaveTalk..."

# 1. Target Directory
APP_DIR="/Applications/WaveTalk"
sudo mkdir -p "$APP_DIR/Source"
sudo mkdir -p "$APP_DIR/Scripts"
sudo chown -R $(whoami) "$APP_DIR"

# 2. Copy Files (except transcribe.js if it exists with a key)
cp WaveTalk.swift "$APP_DIR/Source/"
cp Scripts/process.sh "$APP_DIR/Scripts/"

if [ ! -f "$APP_DIR/Scripts/transcribe.js" ] || grep -q "YOUR_DEEPGRAM_API_KEY_HERE" "$APP_DIR/Scripts/transcribe.js"; then
    echo "📄 Installing/Updating transcribe.js..."
    cp Scripts/transcribe.js "$APP_DIR/Scripts/"
else
    echo "✅ Keeping existing transcribe.js (API Key preserved)"
fi

chmod +x "$APP_DIR/Scripts/process.sh"

# 3. Compile
echo "🔨 Compiling WaveTalk..."
swiftc "$APP_DIR/Source/WaveTalk.swift" -o "$APP_DIR/WaveTalk" -framework Cocoa -framework AVFoundation -framework SwiftUI

# 4. Kill old process if running
pkill -f "/Applications/WaveTalk/WaveTalk"

echo "✅ Done! Starting WaveTalk..."
"$APP_DIR/WaveTalk" &
