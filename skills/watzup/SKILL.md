---
name: sk:watzup
description: "Review recent changes and wrap up the current work session."
metadata:
  author: claudekit
  version: "1.0.0"
---

# Wrap Up

Review my current branch and the most recent commits.
Provide a detailed summary of all changes, including what was modified, added, or removed.
Analyze the overall impact and quality of the changes.

**IMPORTANT**: **Do not** start implementing.


## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).

**Rules:**
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts like "Please answer: 1) X? 2) Y?"
- Each question: 2-4 predefined options + auto "Something else"
- Exception: genuine free-form inputs (file paths, custom names, code snippets)

See rule for full specification.

