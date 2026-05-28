#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/.derivedData/Build/Products/Debug/MeetingNotes.app"

if [ ! -d "$APP_PATH" ]; then
  osascript -e 'display alert "MeetingNotes.app not found" message "Build the app first with xcodebuild before launching it from this shortcut."'
  exit 1
fi

open "$APP_PATH"
