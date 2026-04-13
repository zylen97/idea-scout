#!/bin/bash
# Idea Scout — Setup Script
# Generates launchd plists from templates and loads them.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="${LOG_DIR:-$REPO_DIR/logs}"

echo "Idea Scout Setup"
echo "==================="
echo "Repo:    $REPO_DIR"
echo "Logs:    $LOG_DIR"
echo ""

# Check config/local.sh exists
if [ ! -f "$REPO_DIR/config/local.sh" ]; then
    echo "ERROR: config/local.sh not found."
    echo "  cp config/env.example config/local.sh"
    echo "  Then edit config/local.sh with your paths and credentials."
    exit 1
fi

mkdir -p "$LOG_DIR"

# Generate plists from templates
for pipeline in ft50 cepm cnki; do
    TEMPLATE="$REPO_DIR/config/launchd/com.idea-scout.${pipeline}.plist"
    OUTPUT="$PLIST_DIR/com.idea-scout.${pipeline}.plist"

    if [ ! -f "$TEMPLATE" ]; then
        echo "SKIP: template not found: $TEMPLATE"
        continue
    fi

    sed -e "s|{INSTALL_PATH}|$REPO_DIR|g" \
        -e "s|{LOG_PATH}|$LOG_DIR|g" \
        -e "s|{HOME}|$HOME|g" \
        "$TEMPLATE" > "$OUTPUT"

    # Unload if already loaded, then load
    launchctl unload "$OUTPUT" 2>/dev/null || true
    launchctl load "$OUTPUT"
    echo "Loaded: $OUTPUT"
done

echo ""
echo "Done. Pipelines scheduled:"
echo "  FT50:  daily at 9:00"
echo "  CE/PM: daily at 9:10"
echo "  CNKI:  daily at 9:20"
echo ""
echo "Test manually:"
echo "  bash $REPO_DIR/pipeline/ft50-daily.sh"
