#!/bin/bash
# Claude Super Kit Installer v2.0
# Full replace mode: symlinks ALL skills/commands/rules into ~/.claude/

set -e

SUPER_KIT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLAUDE_DIR="$HOME/.claude"

echo "=========================================="
echo "  Claude Super Kit Installer v2.0"
echo "=========================================="
echo ""
echo "Super Kit dir: $SUPER_KIT_DIR"
echo "Target dir:    $CLAUDE_DIR"
echo ""

# Ensure target dirs exist
mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/rules"

# 1. Symlink ALL skills (every folder)
echo "[1/3] Linking ALL skills..."
LINKED_SKILLS=0
REPLACED_SKILLS=0
for skill_dir in "$SUPER_KIT_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    target="$CLAUDE_DIR/skills/$skill_name"

    if [ -L "$target" ] || [ -e "$target" ]; then
        rm -rf "$target"
        ((REPLACED_SKILLS++))
    fi

    ln -s "$skill_dir" "$target"
    ((LINKED_SKILLS++))
done
echo "  ✓ Linked $LINKED_SKILLS skills (replaced $REPLACED_SKILLS existing)"

# 2. Symlink ALL commands (recursively for nested dirs)
echo "[2/3] Linking ALL commands..."
LINKED_CMDS=0
# Top-level files
for cmd_file in "$SUPER_KIT_DIR/commands"/*.md; do
    [ -f "$cmd_file" ] || continue
    cmd_name=$(basename "$cmd_file")
    target="$CLAUDE_DIR/commands/$cmd_name"

    [ -L "$target" ] || [ -e "$target" ] && rm -rf "$target"
    ln -s "$cmd_file" "$target"
    ((LINKED_CMDS++))
done
# Nested directories
for cmd_dir in "$SUPER_KIT_DIR/commands"/*/; do
    [ -d "$cmd_dir" ] || continue
    dir_name=$(basename "$cmd_dir")
    target="$CLAUDE_DIR/commands/$dir_name"

    [ -L "$target" ] || [ -e "$target" ] && rm -rf "$target"
    ln -s "$cmd_dir" "$target"
    ((LINKED_CMDS++))
done
echo "  ✓ Linked $LINKED_CMDS command items"

# 3. Symlink ALL rules
echo "[3/3] Linking ALL rules..."
LINKED_RULES=0
for rule_file in "$SUPER_KIT_DIR/rules"/*.md; do
    [ -f "$rule_file" ] || continue
    rule_name=$(basename "$rule_file")
    target="$CLAUDE_DIR/rules/$rule_name"

    [ -L "$target" ] || [ -e "$target" ] && rm -rf "$target"
    ln -s "$rule_file" "$target"
    ((LINKED_RULES++))
done
echo "  ✓ Linked $LINKED_RULES rules"

echo ""
echo "=========================================="
echo "  Installation complete!"
echo "=========================================="
echo ""
echo "Total: $LINKED_SKILLS skills, $LINKED_CMDS commands, $LINKED_RULES rules"
echo ""
echo "Test by running in Claude Code:"
echo "  /sk:plan \"Build something cool\""
echo "  /sk:brainstorm"
echo "  /sk:vue-development"
echo "  /sk:electron-apps"
echo ""
echo "All available skills: ls ~/.claude/skills/"
