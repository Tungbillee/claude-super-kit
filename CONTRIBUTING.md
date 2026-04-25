# Contributing to Claude Super Kit

Thanks for your interest. Super Kit is a curated, Vietnam-focused fork of ClaudeKit. Contributions welcome.

---

## Quick Rules

1. **YAGNI / KISS / DRY** — no speculative features
2. **Interactive UI mandatory** — all skills use `AskUserQuestion` (see `rules/interactive-ui-protocol.md`)
3. **SKILL.md ≤ 400 lines** — split large content into `references/`
4. **Conventional commits** — `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
5. **English source** — skills in English; CLAUDE.md + reports in Vietnamese

---

## Adding a New Skill

### 1. Create folder

```bash
mkdir -p skills/sk-your-skill/{references,scripts,assets}
touch skills/sk-your-skill/SKILL.md
```

### 2. Write SKILL.md with required frontmatter

```yaml
---
name: sk-your-skill
description: One-line description of what this skill does
version: 1.0.0
author: Your Name
type: capability
namespace: sk
category: frontend | backend | desktop | payment | devops | etc.
last_updated: YYYY-MM-DD
when_to_use: >
  Triggers:
  - User asks about X
  - Project contains file Y
  - Dependencies include Z
---

# Your Skill Name

## Overview
...

## When to Use
...

## How It Works
...

## User Interaction (MANDATORY)
This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
```

### 3. Validate

```bash
./scripts/validate-skills.sh
```

### 4. Test locally

```bash
# Symlink to ~/.claude/skills/ for testing
ln -s "$(pwd)/skills/sk-your-skill" ~/.claude/skills/sk-your-skill

# Invoke in Claude Code
/sk:your-skill
```

### 5. Submit PR

- Branch: `feat/sk-your-skill`
- Commit: `feat: add sk-your-skill for [purpose]`
- PR description: use case, decision rationale, test results

---

## Updating Existing Skills

### Bug fixes
- Branch: `fix/sk-skill-name`
- Include repro steps in PR
- Update `version` in frontmatter

### Refactoring
- Branch: `refactor/sk-skill-name`
- Keep behavior identical
- Reduce line count when possible

### Breaking changes
- Branch: `feat/sk-skill-name-v2`
- Major version bump
- Update `DEPRECATIONS.md`

---

## Skill Review Checklist

Before requesting review:

- [ ] Frontmatter complete (name, description, version, author, last_updated)
- [ ] `when_to_use` clear triggers
- [ ] SKILL.md ≤ 400 lines (or references/ used)
- [ ] Interactive UI protocol followed (AskUserQuestion usage)
- [ ] No free-text prompts ("Please tell me:", "Answer the following:")
- [ ] Anti-patterns section if applicable
- [ ] Examples concrete and runnable
- [ ] Tested locally with real use case
- [ ] `validate-skills.sh` passes

---

## Commit Message Conventions

Format:
```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

**Types:**
- `feat` — new feature/skill
- `fix` — bug fix
- `docs` — docs only changes
- `refactor` — code refactor, no behavior change
- `test` — adding/updating tests
- `chore` — tooling, configs, dependencies
- `perf` — performance improvement
- `style` — formatting (no code change)

**Examples:**
```
feat(sk-vue-development): add Composition API patterns reference

fix(sk-payment-vnpay): correct HMAC signature verification order

docs(contributing): add skill review checklist

refactor(sk-ui-ux-pro-max): split examples into references/
```

---

## Development Workflow

1. Fork repo
2. Create feature branch: `git checkout -b feat/your-feature`
3. Make changes
4. Run validator: `./scripts/validate-skills.sh`
5. Commit with conventional format
6. Push to your fork
7. Open PR against `main`

---

## Testing Your Changes

### Skill validation
```bash
./scripts/validate-skills.sh
```

### Syntax check (rename script)
```bash
bash -n scripts/rename-namespace.sh
```

### Integration test
Install locally + test in real Claude Code session:
```bash
./install.sh
# Test your skill
```

---

## Code of Conduct

Be kind. Assume good intent. Sacrifice grammar for concision in reports. Vietnamese or English, both OK.

---

## Questions?

- GitHub Issues: [github.com/tungpc/claude-super-kit/issues](https://github.com/tungpc/claude-super-kit/issues)
- Email: sanpema1998@gmail.com

---

**Last updated:** 2026-04-25
