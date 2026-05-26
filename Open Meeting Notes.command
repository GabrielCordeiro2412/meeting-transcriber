#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/.derivedData/Build/Products/Debug/MeetingNotes.app"
BACKEND_DIR="$SCRIPT_DIR/backend"
BACKEND_ENV="$BACKEND_DIR/.env"
BACKEND_LOG="$BACKEND_DIR/.meeting-notes-backend.log"
BACKEND_PID_FILE="$BACKEND_DIR/.meeting-notes-backend.pid"

backend_is_healthy() {
  curl --silent --fail http://127.0.0.1:8787/health >/dev/null 2>&1
}

start_backend_if_configured() {
  if [ ! -f "$BACKEND_ENV" ]; then
    osascript -e 'display alert "Backend not configured" message "backend/.env was not found. The app will open, but sign-in and processing will not work until the SaaS backend is configured."'
    return
  fi

  if [ ! -d "$BACKEND_DIR/node_modules" ]; then
    osascript -e 'display alert "Backend dependencies missing" message "Run npm install inside the backend folder before launching the app shortcut."'
    return
  fi

  if backend_is_healthy; then
    return
  fi

  (
    cd "$BACKEND_DIR"
    nohup npm start >"$BACKEND_LOG" 2>&1 &
    echo $! >"$BACKEND_PID_FILE"
  )

  for _ in {1..20}; do
    if backend_is_healthy; then
      return
    fi
    sleep 0.5
  done

  osascript -e "display alert \"Backend failed to start\" message \"Check $BACKEND_LOG for details.\""
}

if [ ! -d "$APP_PATH" ]; then
  osascript -e 'display alert "MeetingNotes.app not found" message "Build the app first with xcodebuild before launching it from this shortcut."'
  exit 1
fi

start_backend_if_configured
open "$APP_PATH"
