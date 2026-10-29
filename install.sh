#!/usr/bin/env bash
# Install the penpot-builder skill into your OpenCode skills directory.
set -euo pipefail

DEST="${1:-$HOME/.config/opencode/skills/penpot-builder}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$DEST"
cp "$SRC_DIR/SKILL.md" "$DEST/SKILL.md"

echo "Installed penpot-builder skill to: $DEST"
echo
echo "Next steps:"
echo "  1. Register the Penpot MCP server in your OpenCode config (see README.md)."
echo "  2. Open a Penpot file and connect the MCP plugin (File -> MCP Server -> Connect)."
echo "  3. Prompt your agent to build/edit/prototype a design."
