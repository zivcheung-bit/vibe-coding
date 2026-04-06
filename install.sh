#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_CMD_DIR="$HOME/.claude/commands"

mkdir -p "$CLAUDE_CMD_DIR"
cp "$SCRIPT_DIR/vibe.md" "$CLAUDE_CMD_DIR/vibe.md"
echo "Installed to $CLAUDE_CMD_DIR/vibe.md"
echo ""
echo "Done! Open Claude Code in any project and type /vibe to start."
