#!/bin/bash
# Claude Super Kit - Add Interactive UI protocol reference to ALL skills (Option B)
# Appends a "User Interaction" section to every SKILL.md that doesn't have one

set -e

BASE_DIR="${1:-.}"
cd "$BASE_DIR"

echo "=== Adding Interactive UI references to all skills ==="
echo ""

ADDED=0
SKIPPED=0
SKILLS_TOTAL=0

# Skills to skip (utility/shared folders)
SKIP_SKILLS=("_shared" "common" "document-skills")

# Reference block to append
REF_BLOCK='

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).

**Rules:**
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts like "Please answer: 1) X? 2) Y?"
- Each question: 2-4 predefined options + auto "Something else"
- Exception: genuine free-form inputs (file paths, custom names, code snippets)

See rule for full specification.
'

for skill_dir in skills/*/; do
    skill_name=$(basename "$skill_dir")

    # Skip utility folders
    skip=false
    for s in "${SKIP_SKILLS[@]}"; do
        [[ "$skill_name" == "$s" ]] && skip=true
    done
    [[ "$skip" == true ]] && continue

    ((SKILLS_TOTAL++))
    skill_file="$skill_dir/SKILL.md"

    # Skip if SKILL.md doesn't exist
    [[ ! -f "$skill_file" ]] && continue

    # Skip if already has the reference
    if grep -q "interactive-ui-protocol" "$skill_file" 2>/dev/null; then
        ((SKIPPED++))
        continue
    fi

    # Append reference block
    echo "$REF_BLOCK" >> "$skill_file"
    ((ADDED++))
    echo "  ✓ Added to: $skill_name"
done

echo ""
echo "=== Summary ==="
echo "Skills total:    $SKILLS_TOTAL"
echo "References added: $ADDED"
echo "Already had ref:  $SKIPPED"
echo ""
echo "✓ Interactive UI references added to all skills"
