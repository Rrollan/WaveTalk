#!/bin/bash

echo "🌊 Installing WaveTalk..."

# 1. Create Target Directory
APP_DIR="/Applications/WaveTalk"
sudo mkdir -p "$APP_DIR/Source"
sudo mkdir -p "$APP_DIR/Scripts"
sudo chown -R $(whoami) "$APP_DIR"

# 2. Copy Files
cp WaveTalk.swift "$APP_DIR/Source/"
cp Scripts/process.sh "$APP_DIR/Scripts/"
cp Scripts/transcribe.js "$APP_DIR/Scripts/"

chmod +x "$APP_DIR/Scripts/process.sh"

# 3. Compile
echo "🔨 Compiling WaveTalk..."
swiftc "$APP_DIR/Source/WaveTalk.swift" -o "$APP_DIR/WaveTalk" -framework Cocoa -framework AVFoundation -framework SwiftUI

echo "✅ Done! Run the app with: /Applications/WaveTalk/WaveTalk &"
