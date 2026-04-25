---
name: sk:template-skill
description: Replace with description of the skill and when Claude should use it.
metadata:
  author: claudekit
  version: "1.0.0"
---

# Insert instructions below


## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).

**Rules:**
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts like "Please answer: 1) X? 2) Y?"
- Each question: 2-4 predefined options + auto "Something else"
- Exception: genuine free-form inputs (file paths, custom names, code snippets)

See rule for full specification.

