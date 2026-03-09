#!/usr/bin/env bash
# install-ccg.sh — Install the codeagent-wrapper and role prompts.
#
# Installs:
#   ~/.claude/bin/codeagent-wrapper      (bridge script for multi-* commands)
#   ~/.claude/.ccg/prompts/codex/*.md    (Codex role prompts)
#   ~/.claude/.ccg/prompts/gemini/*.md   (Gemini role prompts)
#
# Usage:
#   ./scripts/install-ccg.sh
#
# The script is idempotent — safe to re-run after updates.

set -euo pipefail

# Resolve the repo root (handles symlinks from npm bin)
SCRIPT_PATH="$0"
while [ -L "$SCRIPT_PATH" ]; do
    link_dir="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$link_dir/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

WRAPPER_SRC="$SCRIPT_DIR/codeagent-wrapper.sh"
PROMPTS_SRC="$SCRIPT_DIR/ccg-prompts"

# ---------------------------------------------------------------------------
# Validate source files exist
# ---------------------------------------------------------------------------
if [[ ! -f "$WRAPPER_SRC" ]]; then
    echo "Error: $WRAPPER_SRC not found. Run this script from the repo root." >&2
    exit 1
fi

if [[ ! -d "$PROMPTS_SRC" ]]; then
    echo "Error: $PROMPTS_SRC/ not found. Run this script from the repo root." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Create target directories
# ---------------------------------------------------------------------------
BIN_DIR="$HOME/.claude/bin"
PROMPTS_DIR="$HOME/.claude/.ccg/prompts"

mkdir -p "$BIN_DIR"
mkdir -p "$PROMPTS_DIR/codex"
mkdir -p "$PROMPTS_DIR/gemini"

# ---------------------------------------------------------------------------
# Install wrapper script
# ---------------------------------------------------------------------------
echo "Installing codeagent-wrapper -> $BIN_DIR/codeagent-wrapper"
cp "$WRAPPER_SRC" "$BIN_DIR/codeagent-wrapper"
chmod +x "$BIN_DIR/codeagent-wrapper"

# ---------------------------------------------------------------------------
# Install role prompts
# ---------------------------------------------------------------------------
echo "Installing Codex role prompts -> $PROMPTS_DIR/codex/"
for f in "$PROMPTS_SRC/codex"/*.md; do
    [[ -f "$f" ]] && cp "$f" "$PROMPTS_DIR/codex/"
done

echo "Installing Gemini role prompts -> $PROMPTS_DIR/gemini/"
for f in "$PROMPTS_SRC/gemini"/*.md; do
    [[ -f "$f" ]] && cp "$f" "$PROMPTS_DIR/gemini/"
done

# ---------------------------------------------------------------------------
# Verify PATH
# ---------------------------------------------------------------------------
echo ""
echo "Done. Installed files:"
echo "  $BIN_DIR/codeagent-wrapper"
ls -1 "$PROMPTS_DIR/codex/" 2>/dev/null | sed "s|^|  $PROMPTS_DIR/codex/|"
ls -1 "$PROMPTS_DIR/gemini/" 2>/dev/null | sed "s|^|  $PROMPTS_DIR/gemini/|"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo ""
    echo "Note: $BIN_DIR is not in your PATH."
    echo "The multi-* commands invoke the wrapper via absolute path (~/.claude/bin/codeagent-wrapper),"
    echo "so this is fine for normal usage. To call it directly, add to your shell profile:"
    echo "  export PATH=\"\$HOME/.claude/bin:\$PATH\""
fi
