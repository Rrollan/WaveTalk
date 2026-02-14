#!/bin/bash
# Config
BOT_TOKEN="8237515727:AAFHEJBxvRIajODU1VzKdnjjT_Wopd4Ofu4"
CHAT_ID="1345815453"
AUDIO_FILE="/tmp/wavetalk_input.m4a"
LOG_FILE="/tmp/wavetalk.log"
SCRIPTS_DIR="/Applications/WaveTalk/Scripts"
NODE_BIN="/opt/homebrew/bin/node"

# 1. Size Check
FILE_SIZE=$(stat -f%z "$AUDIO_FILE" 2>/dev/null || stat -c%s "$AUDIO_FILE" 2>/dev/null)
if [ -z "$FILE_SIZE" ] || [ "$FILE_SIZE" -lt 1000 ]; then exit 0; fi

# 2. Transcribe (using local script in repo)
MESSAGE=$($NODE_BIN "$SCRIPTS_DIR/transcribe.js" "$AUDIO_FILE" 2>>$LOG_FILE)

# 3. Send to Telegram
if [ ! -z "$MESSAGE" ] && [ ${#MESSAGE} -gt 1 ]; then
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
         -d "chat_id=$CHAT_ID" \
         -d "text=👤 **Ты:** $MESSAGE" \
         -d "parse_mode=Markdown" > /dev/null
    rm -f "$AUDIO_FILE"
fi
