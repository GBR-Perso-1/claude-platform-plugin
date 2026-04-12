#!/bin/bash
# InstructionsLoaded hook: logs which instruction files are loaded and why.
# Output: .claude/instructions-loaded.log (overwritten each session start, appended during session)

INPUT=$(cat)
LOG_FILE="$CLAUDE_PROJECT_DIR/.claude/instructions-loaded.log"

# Parse fields from JSON without jq
parse_field() {
  echo "$INPUT" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"//;s/\"$//"
}

FILE_PATH=$(parse_field "file_path")
LOAD_REASON=$(parse_field "load_reason")
MEMORY_TYPE=$(parse_field "memory_type")
TRIGGER_FILE=$(parse_field "trigger_file_path")

# Normalise paths for readability — strip project dir prefix
SHORT_PATH="${FILE_PATH#$CLAUDE_PROJECT_DIR/}"
SHORT_TRIGGER="${TRIGGER_FILE#$CLAUDE_PROJECT_DIR/}"

TIMESTAMP=$(date '+%H:%M:%S')

# Clear log on session start (first file loaded)
if [[ "$LOAD_REASON" == "session_start" ]]; then
  # Only clear once — check if log already has a session_start entry with today's timestamp
  TODAY=$(date '+%Y-%m-%d')
  if ! grep -q "^=== Session $TODAY" "$LOG_FILE" 2>/dev/null; then
    echo "=== Session $TODAY $TIMESTAMP ===" > "$LOG_FILE"
  fi
fi

# Build log line
LINE="[$TIMESTAMP] [$LOAD_REASON] [$MEMORY_TYPE] $SHORT_PATH"
if [[ -n "$TRIGGER_FILE" ]]; then
  LINE="$LINE  (triggered by: $SHORT_TRIGGER)"
fi

echo "$LINE" >> "$LOG_FILE"

exit 0
