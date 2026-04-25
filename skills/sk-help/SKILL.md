---
name: sk-help
description: Claude Super Kit usage guide - just type naturally and skill will route to relevant capability
version: 1.0.0
author: Claude Super Kit
type: meta-skill
namespace: sk
last_updated: 2026-04-25
when_to_use: User asks "how do I use Super Kit", "help", "what can this do", "/sk:help"
---

# Claude Super Kit Help

## Overview

This skill provides guided help for Claude Super Kit users. When invoked, it presents an interactive menu of available skills grouped by category.

## When to Use

- User says "help", "/sk:help", "how do I..."
- User unsure which skill fits their task
- New user onboarding

## How It Works

1. Detect user intent from their message
2. Present interactive menu via `AskUserQuestion`
3. Route to the most relevant skill

## Categories

### Core Workflow
- `/sk:plan` - Plan implementation with phases
- `/sk:cook` - Implement features step-by-step
- `/sk:fix` - Fix bugs with root-cause analysis
- `/sk:debug` - Systematic debugging
- `/sk:test` - Run tests
- `/sk:review` - Code review

### Productivity
- `/sk:brainstorm` - Solution exploration
- `/sk:scout` - Codebase exploration
- `/sk:ask` - Technical Q&A
- `/sk:journal` - Work journal
- `/sk:watzup` - Session wrap-up

### Specialized
- `/sk:design` - UI/UX design
- `/sk:bootstrap` - Project scaffolding
- `/sk:deploy` - Multi-platform deployment
- `/sk:git:cm`, `/sk:git:cp`, `/sk:git:pr` - Git operations
- `/sk:ship` - Full release pipeline

### Frameworks (when applicable)
- `/sk:vue-development`, `/sk:nuxt-full-stack`
- `/sk:electron-apps`, `/sk:wails-desktop`
- `/sk:svelte-development`, `/sk:solidjs-development`

### Payments (Vietnam)
- `/sk:payment-sepay`, `/sk:payment-pay2s`
- `/sk:payment-vnpay`, `/sk:payment-momo`, `/sk:payment-zalopay`

## Quick Decision Tree

```
What do you want to do?
├── Plan something → /sk:plan
├── Implement code → /sk:cook
├── Fix a bug → /sk:fix
├── Run tests → /sk:test
├── Review code → /sk:review
├── Design UI → /sk:design or /sk:frontend-design
├── Deploy → /sk:deploy
└── Don't know? → /sk:brainstorm
```

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).

**Rules:**
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

See rule for full specification.

## Documentation

- [README](../../README.md) - Overview
- [CONTRIBUTING](../../CONTRIBUTING.md) - How to contribute
- [Interactive UI Protocol](../../rules/interactive-ui-protocol.md)
- [Language Response Rule](../../rules/language-response.md)
