#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_CMD_DIR="$HOME/.claude/commands"

mkdir -p "$CLAUDE_CMD_DIR"
cp "$SCRIPT_DIR/vibe-production.md" "$CLAUDE_CMD_DIR/vibe-production.md"
echo "Installed to $CLAUDE_CMD_DIR/vibe-production.md"
echo ""
echo "Done! Open Claude Code in any project and type /vibe-production to start."
