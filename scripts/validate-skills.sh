#!/bin/bash
# Claude Super Kit - Skill frontmatter validator
# Validates all skills have proper SKILL.md with required frontmatter

set -e

BASE_DIR="${1:-.}"
cd "$BASE_DIR"

echo "=== Claude Super Kit Skill Validator ==="
echo ""

ISSUES=0
SKILLS_CHECKED=0
MISSING_SKILL_MD=0
MISSING_FRONTMATTER=0
MISSING_FIELDS=0

# Skills to skip (utility/shared, not proper skills)
SKIP_SKILLS=("_shared" "common" "document-skills")

for skill_dir in skills/*/; do
    skill_name=$(basename "$skill_dir")

    # Skip utility folders
    skip=false
    for s in "${SKIP_SKILLS[@]}"; do
        [[ "$skill_name" == "$s" ]] && skip=true
    done
    [[ "$skip" == true ]] && continue

    ((SKILLS_CHECKED++))
    skill_file="$skill_dir/SKILL.md"

    # Check SKILL.md exists
    if [[ ! -f "$skill_file" ]]; then
        echo "✗ MISSING SKILL.md: $skill_name"
        ((MISSING_SKILL_MD++))
        ((ISSUES++))
        continue
    fi

    # Check frontmatter exists
    if ! head -1 "$skill_file" | grep -q "^---"; then
        echo "✗ NO FRONTMATTER: $skill_name"
        ((MISSING_FRONTMATTER++))
        ((ISSUES++))
        continue
    fi

    # Check required fields
    MISSING=""
    for field in name description; do
        if ! head -20 "$skill_file" | grep -qE "^$field:"; then
            MISSING="$MISSING $field"
        fi
    done

    if [[ -n "$MISSING" ]]; then
        echo "✗ MISSING FIELDS ($MISSING): $skill_name"
        ((MISSING_FIELDS++))
        ((ISSUES++))
    fi
done

echo ""
echo "=== Validation Summary ==="
echo "Skills checked:        $SKILLS_CHECKED"
echo "Missing SKILL.md:      $MISSING_SKILL_MD"
echo "Missing frontmatter:   $MISSING_FRONTMATTER"
echo "Missing fields:        $MISSING_FIELDS"
echo "Total issues:          $ISSUES"
echo ""

if [[ $ISSUES -eq 0 ]]; then
    echo "✓ All skills pass validation"
    exit 0
else
    echo "✗ Found $ISSUES issue(s)"
    exit 1
fi
