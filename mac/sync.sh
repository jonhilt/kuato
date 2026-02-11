#!/bin/bash
# Kuato session sync wrapper for macOS
# Called by launchd every 15 minutes
#
# Loads DATABASE_URL from ~/.kuato/.env and runs sync with source=mac-jon

set -euo pipefail

KUATO_DIR="$HOME/.kuato"
KUATO_REPO="$KUATO_DIR/repo"
LOG_FILE="$KUATO_DIR/sync.log"
ENV_FILE="$KUATO_DIR/.env"

# Rotate log if > 1MB
if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)" -gt 1048576 ]; then
  mv "$LOG_FILE" "$LOG_FILE.old"
fi

{
  echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"

  if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: $ENV_FILE not found. Run setup.sh first."
    exit 1
  fi

  # Load DATABASE_URL
  set -a
  source "$ENV_FILE"
  set +a

  if [ -z "${DATABASE_URL:-}" ]; then
    echo "ERROR: DATABASE_URL not set in $ENV_FILE"
    exit 1
  fi

  # Run sync
  cd "$KUATO_REPO/postgres"
  SYNC_SOURCE=mac-jon \
    CLAUDE_SESSIONS_DIR="$HOME/.claude/projects" \
    "$HOME/.bun/bin/bun" run sync.ts

  echo "Sync complete."
} >> "$LOG_FILE" 2>&1
