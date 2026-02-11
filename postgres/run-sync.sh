#!/bin/bash
# Load DATABASE_URL from PAI secrets
set -a
. /var/lib/pai/secrets/.env
set +a

cd /root/utils/kuato/postgres

# Sync host sessions (direct Claude Code)
CLAUDE_SESSIONS_DIR=/root/.claude/projects \
  SYNC_SOURCE=pai \
  PATH="/root/.bun/bin:$PATH" bun run sync

# Sync bot sessions (sandboxed Claude via Telegram)
CLAUDE_SESSIONS_DIR=/var/lib/pai/secrets/claude/projects \
  SYNC_SOURCE=pai \
  PATH="/root/.bun/bin:$PATH" bun run sync
