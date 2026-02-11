#!/bin/bash
# Kuato Mac Setup
#
# Sets up automatic Claude Code session sync to Supabase from your Mac.
# Sessions are tagged with source=mac-jon so they're distinguishable from
# PAI server sessions.
#
# Usage:
#   git clone https://github.com/jonhilt/kuato.git && cd kuato && bash mac/setup.sh
#
# What it does:
#   1. Installs bun (if not present)
#   2. Clones kuato to ~/.kuato/repo (if not present)
#   3. Installs dependencies
#   4. Prompts for DATABASE_URL and saves to ~/.kuato/.env
#   5. Installs launchd plist to run sync every 15 minutes
#   6. Runs an initial sync

set -euo pipefail

# Resolve the directory this script lives in (handles both direct run and symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The kuato repo root is one level up from mac/
SCRIPT_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

KUATO_DIR="$HOME/.kuato"
KUATO_REPO="$KUATO_DIR/repo"
PLIST_NAME="com.kuato.sync"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
ENV_FILE="$KUATO_DIR/.env"

echo "==========================="
echo "  Kuato Mac Setup"
echo "==========================="
echo ""

# ── Step 1: Check/install bun ────────────────────────────
echo "Step 1: Checking for bun..."
if command -v bun &>/dev/null; then
  echo "  bun found: $(bun --version)"
else
  echo "  Installing bun..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  echo "  bun installed: $(bun --version)"
fi
echo ""

# ── Step 2: Set up kuato repo ────────────────────────────
echo "Step 2: Setting up kuato repo..."
mkdir -p "$KUATO_DIR"

if [ "$SCRIPT_REPO_ROOT" != "$KUATO_REPO" ]; then
  # Running from a different location — copy or symlink to ~/.kuato/repo
  if [ -d "$KUATO_REPO/.git" ]; then
    echo "  Repo exists at $KUATO_REPO, pulling latest..."
    cd "$KUATO_REPO" && git pull --quiet
  else
    echo "  Cloning kuato from fork..."
    git clone --quiet https://github.com/jonhilt/kuato.git "$KUATO_REPO"
  fi
else
  echo "  Already running from $KUATO_REPO"
fi
echo ""

# ── Step 3: Install dependencies ────────────────────────
echo "Step 3: Installing dependencies..."
cd "$KUATO_REPO/postgres"
bun install --silent
echo "  Done."
echo ""

# ── Step 4: Configure DATABASE_URL ──────────────────────
echo "Step 4: Database configuration..."
if [ -f "$ENV_FILE" ] && grep -q "DATABASE_URL" "$ENV_FILE"; then
  echo "  DATABASE_URL already configured in $ENV_FILE"
  read -p "  Overwrite? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "  Keeping existing config."
  else
    read -p "  Enter DATABASE_URL: " DB_URL
    echo "DATABASE_URL=\"$DB_URL\"" > "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "  Saved to $ENV_FILE"
  fi
else
  echo "  Enter your Supabase DATABASE_URL (connection pooler URI)."
  echo "  Find it at: Supabase Dashboard > Settings > Database > Connection Pooling"
  echo ""
  read -p "  DATABASE_URL: " DB_URL
  echo "DATABASE_URL=\"$DB_URL\"" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "  Saved to $ENV_FILE (chmod 600)"
fi
echo ""

# ── Step 5: Install launchd plist ───────────────────────
echo "Step 5: Installing launchd agent..."

# Unload existing if present
if launchctl list | grep -q "$PLIST_NAME" 2>/dev/null; then
  echo "  Unloading existing agent..."
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# Copy sync.sh (from the directory this script lives in, not ~/.kuato/repo)
SYNC_SH="$KUATO_DIR/sync.sh"
cp "$SCRIPT_DIR/sync.sh" "$SYNC_SH"
chmod +x "$SYNC_SH"

# Generate plist from template
mkdir -p "$HOME/Library/LaunchAgents"
sed \
  -e "s|KUATO_SYNC_SH_PATH|$SYNC_SH|g" \
  -e "s|KUATO_DIR|$KUATO_DIR|g" \
  -e "s|HOME_DIR|$HOME|g" \
  "$SCRIPT_DIR/com.kuato.sync.plist" > "$PLIST_DEST"

# Load the agent
launchctl load "$PLIST_DEST"
echo "  Agent installed and loaded."
echo "  Syncs every 15 minutes."
echo ""

# ── Step 6: Initial sync ───────────────────────────────
echo "Step 6: Running initial sync..."
echo ""
bash "$SYNC_SH" 2>&1 | tail -20
# Also show the log output
echo ""
if [ -f "$KUATO_DIR/sync.log" ]; then
  echo "Sync log:"
  tail -10 "$KUATO_DIR/sync.log"
fi
echo ""

# ── Done ────────────────────────────────────────────────
echo "==========================="
echo "  Setup complete!"
echo "==========================="
echo ""
echo "Sessions from this Mac will be tagged: source=mac-jon"
echo ""
echo "Useful commands:"
echo "  View sync log:     tail -f ~/.kuato/sync.log"
echo "  Manual sync:       bash ~/.kuato/sync.sh"
echo "  Stop auto-sync:    launchctl unload ~/Library/LaunchAgents/com.kuato.sync.plist"
echo "  Restart auto-sync: launchctl load ~/Library/LaunchAgents/com.kuato.sync.plist"
echo "  Update kuato:      cd ~/.kuato/repo && git pull && bun install --cwd postgres"
echo ""
