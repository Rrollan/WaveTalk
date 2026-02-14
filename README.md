# WaveTalk 🌊

AI Voice Assistant for macOS with a beautiful Liquid Glass UI.

## 🚀 Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/Rrollan/WaveTalk.git
   cd WaveTalk
   ```

2. Run the setup script:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Important:** Edit `Scripts/transcribe.js` and add your Deepgram API Key.

## ⌨️ Usage

- **Hold Cmd+B:** Start recording. A green liquid wavy indicator will appear.
- **Release Cmd+B:** Stop recording and send the message to Telegram.

## 🛠 Tech Stack
- **SwiftUI:** Modern macOS UI.
- **AVFoundation:** Audio recording.
- **Deepgram API:** Ultra-fast transcription.
- **Telegram Bot API:** Delivery.
