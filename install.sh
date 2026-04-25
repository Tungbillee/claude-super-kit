#!/bin/bash
# Claude Super Kit Installer
# Symlinks skills/commands/rules into ~/.claude/ for Claude Code to read

set -e

SUPER_KIT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLAUDE_DIR="$HOME/.claude"

echo "=========================================="
echo "  Claude Super Kit Installer"
echo "=========================================="
echo ""
echo "Super Kit dir: $SUPER_KIT_DIR"
echo "Target dir:    $CLAUDE_DIR"
echo ""

# Ensure target dir exists
mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/rules"

# Symlink skills (sk-* prefix only, keep ck-* and others intact)
echo "[1/3] Linking skills/sk-*..."
LINKED_SKILLS=0
for skill_dir in "$SUPER_KIT_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    target="$CLAUDE_DIR/skills/$skill_name"

    if [ -L "$target" ]; then
        rm "$target"
    elif [ -e "$target" ]; then
        echo "  ⚠ Skip (exists, not symlink): $skill_name"
        continue
    fi

    ln -s "$skill_dir" "$target"
    ((LINKED_SKILLS++))
done
echo "  ✓ Linked $LINKED_SKILLS skills"

# Symlink commands (sk-* + sk subdirectory)
echo "[2/3] Linking commands/..."
LINKED_CMDS=0
for cmd_file in "$SUPER_KIT_DIR/commands"/sk*.md; do
    [ -f "$cmd_file" ] || continue
    cmd_name=$(basename "$cmd_file")
    target="$CLAUDE_DIR/commands/$cmd_name"

    if [ -L "$target" ]; then
        rm "$target"
    elif [ -e "$target" ]; then
        echo "  ⚠ Skip (exists): $cmd_name"
        continue
    fi

    ln -s "$cmd_file" "$target"
    ((LINKED_CMDS++))
done
echo "  ✓ Linked $LINKED_CMDS commands"

# Symlink rules (interactive-ui-protocol, language-response - new ones)
echo "[3/3] Linking new rules..."
LINKED_RULES=0
for rule_file in "$SUPER_KIT_DIR/rules"/interactive-ui-protocol.md "$SUPER_KIT_DIR/rules"/language-response.md; do
    [ -f "$rule_file" ] || continue
    rule_name=$(basename "$rule_file")
    target="$CLAUDE_DIR/rules/$rule_name"

    if [ -L "$target" ]; then
        rm "$target"
    elif [ -e "$target" ]; then
        echo "  ⚠ Skip (exists): $rule_name"
        continue
    fi

    ln -s "$rule_file" "$target"
    ((LINKED_RULES++))
done
echo "  ✓ Linked $LINKED_RULES rules"

echo ""
echo "=========================================="
echo "  Installation complete!"
echo "=========================================="
echo ""
echo "Test by running in Claude Code:"
echo "  /sk:plan \"Build something cool\""
echo ""
echo "To uninstall, run: ./uninstall.sh"
