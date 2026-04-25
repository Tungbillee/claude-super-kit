#!/bin/bash
# Claude Super Kit - Namespace rename: ck → sk
# Usage: ./scripts/rename-namespace.sh [base_dir]

set -e

BASE_DIR="${1:-.}"
cd "$BASE_DIR"

echo "=== Claude Super Kit Namespace Rename ==="
echo "Base dir: $(pwd)"
echo ""

# Step 1: Rename ck-* skill directories to sk-*
echo "[1/4] Renaming skill directories ck-* → sk-*..."
RENAMED=0
for dir in skills/ck-*/; do
    if [ -d "$dir" ]; then
        new_dir=$(echo "$dir" | sed 's|skills/ck-|skills/sk-|')
        mv "$dir" "$new_dir"
        echo "  ✓ $dir → $new_dir"
        ((RENAMED++))
    fi
done
echo "  Renamed $RENAMED directories"
echo ""

# Step 2: Rename commands ck-*.md → sk-*.md (at root of commands/)
echo "[2/4] Renaming command files ck-*.md → sk-*.md..."
RENAMED=0
for f in commands/ck-*.md; do
    if [ -f "$f" ]; then
        new_f=$(echo "$f" | sed 's|commands/ck-|commands/sk-|')
        mv "$f" "$new_f"
        echo "  ✓ $f → $new_f"
        ((RENAMED++))
    fi
done
echo "  Renamed $RENAMED files"
echo ""

# Step 3: Replace /ck: and ck: references in all .md files
echo "[3/4] Replacing /ck: → /sk: and ck: → sk: in all .md files..."
COUNT=0
# Use find + sed with backup, then delete backups
find . -type f -name "*.md" -not -path "./node_modules/*" -not -path "./.git/*" | while read -r file; do
    if grep -qE "(/ck:|ck:|ck-)" "$file" 2>/dev/null; then
        # Replace /ck: → /sk:
        sed -i.bak 's|/ck:|/sk:|g' "$file"
        # Replace standalone ck: → sk: (careful with colons)
        sed -i.bak 's| ck:| sk:|g' "$file"
        sed -i.bak 's|`ck:|`sk:|g' "$file"
        sed -i.bak 's|"ck:|"sk:|g' "$file"
        sed -i.bak "s|'ck:|'sk:|g" "$file"
        # Replace ck- prefixed skill names (ck-plan → sk-plan, etc.)
        sed -i.bak 's|ck-plan|sk-plan|g' "$file"
        sed -i.bak 's|ck-debug|sk-debug|g' "$file"
        sed -i.bak 's|ck-fix|sk-fix|g' "$file"
        sed -i.bak 's|ck-security|sk-security|g' "$file"
        sed -i.bak 's|ck-scenario|sk-scenario|g' "$file"
        sed -i.bak 's|ck-predict|sk-predict|g' "$file"
        sed -i.bak 's|ck-loop|sk-loop|g' "$file"
        sed -i.bak 's|ck-autoresearch|sk-autoresearch|g' "$file"
        sed -i.bak 's|ck-help|sk-help|g' "$file"
    fi
done
# Cleanup backup files
find . -name "*.bak" -delete
COUNT=$(find . -type f -name "*.md" | wc -l | tr -d ' ')
echo "  Scanned $COUNT markdown files"
echo ""

# Step 4: Verify
echo "[4/4] Verification..."
REMAINING=$(grep -rE '(/ck:|"ck:)' . --include="*.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -eq 0 ]; then
    echo "  ✓ Zero /ck: references remaining"
else
    echo "  ⚠ Warning: $REMAINING /ck: references still found:"
    grep -rE '(/ck:|"ck:)' . --include="*.md" 2>/dev/null | head -10
fi

CK_DIRS=$(ls -d skills/ck-* 2>/dev/null | wc -l | tr -d ' ')
if [ "$CK_DIRS" -eq 0 ]; then
    echo "  ✓ Zero ck-* skill directories remaining"
else
    echo "  ⚠ Warning: $CK_DIRS ck-* directories still exist"
fi

SK_DIRS=$(ls -d skills/sk-* 2>/dev/null | wc -l | tr -d ' ')
echo "  ✓ $SK_DIRS sk-* skill directories created"

echo ""
echo "=== Namespace rename complete: ck → sk ==="
