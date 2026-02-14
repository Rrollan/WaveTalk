#!/bin/bash

# Config
# Это IP твоего сервера и порт OpenClaw
GATEWAY_URL="http://46.101.240.233:18789"
# Твой секретный токен для доступа к серверу
GATEWAY_TOKEN="2098505848d24781e7f766169a95e66e8b3f99ddf5c5189564b1bc877d5f173a"

AUDIO_FILE="/tmp/wavetalk_input.m4a"
LOG_FILE="/tmp/wavetalk.log"
SCRIPTS_DIR="/Applications/WaveTalk/Scripts"
NODE_BIN="/opt/homebrew/bin/node"

# 1. Проверка размера файла
FILE_SIZE=$(stat -f%z "$AUDIO_FILE" 2>/dev/null || stat -c%s "$AUDIO_FILE" 2>/dev/null)
if [ -z "$FILE_SIZE" ] || [ "$FILE_SIZE" -lt 1000 ]; then exit 0; fi

# 2. Транскрибация (используем твой ключ из transcribe.js)
MESSAGE=$($NODE_BIN "$SCRIPTS_DIR/transcribe.js" "$AUDIO_FILE" 2>>$LOG_FILE)

# 3. Отправка напрямую в OpenClaw (чтобы я получил сообщение и ответил)
if [ ! -z "$MESSAGE" ] && [ ${#MESSAGE} -gt 1 ]; then
    # Отправляем сообщение в чат Telegram через сервер OpenClaw
    curl -s -X POST "$GATEWAY_URL/api/v1/messages" \
         -H "Authorization: Bearer $GATEWAY_TOKEN" \
         -H "Content-Type: application/json" \
         -d "{
               \"text\": \"$MESSAGE\",
               \"channel\": \"telegram\",
               \"to\": \"1345815453\"
             }" > /dev/null
    
    rm -f "$AUDIO_FILE"
fi
