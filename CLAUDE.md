# CLAUDE.md - Claude Super Kit

This file provides guidance to Claude Code when working with the Claude Super Kit codebase.

---

## Project Identity

**Name:** Claude Super Kit
**Namespace:** `/sk:*`
**Purpose:** Vietnamese-first ClaudeKit fork with 119+ skills, zero bloat, interactive-by-default
**License:** MIT
**Maintainer:** tungpc

---

## Mandatory Rules

### 1. Interactive UI Protocol
**ALL skills MUST use `AskUserQuestion` tool for user clarifications.**
See: [rules/interactive-ui-protocol.md](./rules/interactive-ui-protocol.md)

### 2. Response Language Auto-Detection
- User asks in Vietnamese → respond Vietnamese
- User asks in English → respond English
- Skill source code stays English (LLM optimization)
See: [rules/language-response.md](./rules/language-response.md)

### 3. YAGNI / KISS / DRY
- No speculative features
- Simple over clever
- Zero duplicates (enforced by `sk-code-reuse-checker`)

### 4. Skill Standards
- Max 400 lines per SKILL.md (hard limit, split via references/)
- Mandatory frontmatter: `name`, `description`, `version`, `author`
- File naming: `kebab-case` for JS/TS/Python/shell

### 5. Conventional Commits
Format: `<type>(<scope>): <description>`
Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `style`

### 6. Vietnamese Quality (when responding in Vietnamese)
- Full diacritics required (`không`, not `khong`)
- Formal friendly tone (anh/em)
- Keep technical terms in English when no clear VN equivalent

---

## Codebase Structure

```
claude-super-kit/
├── README.md              # Branding + quick start
├── LICENSE                # MIT
├── CONTRIBUTING.md        # How to add/update skills
├── CHANGELOG.md           # Auto-generated via semantic-release
├── DEPRECATIONS.md        # Removed/replaced skills
├── CLAUDE.md              # This file
├── INSTALLATION.md        # Setup guide
├── install.sh             # Installer (macOS/Linux)
├── install.ps1            # Installer (Windows)
├── package.json           # NPM metadata
├── skills/                # 119 skills (sk-* prefix for framework skills)
│   ├── sk-plan/
│   ├── sk-cook/
│   ├── sk-fix/
│   └── ...
├── commands/              # /sk:* command definitions
├── rules/                 # Governance rules
│   ├── interactive-ui-protocol.md
│   ├── language-response.md
│   ├── primary-workflow.md
│   ├── development-rules.md
│   ├── orchestration-protocol.md
│   ├── team-coordination-rules.md
│   └── documentation-management.md
├── workflows/             # Workflow templates
├── scripts/               # Build/release/validation scripts
└── .github/workflows/     # CI/CD
```

---

## Development Workflow

### Adding a new skill
1. `mkdir skills/sk-your-skill && touch skills/sk-your-skill/SKILL.md`
2. Write SKILL.md with required frontmatter
3. Follow Interactive UI Protocol (use AskUserQuestion)
4. Run `./scripts/validate-skills.sh`
5. Test: symlink to `~/.claude/skills/` and invoke
6. Commit + PR

### Updating an existing skill
1. Read current SKILL.md
2. Make changes (preserve frontmatter, update `version` + `last_updated`)
3. Run validator
4. Commit with conventional format

### Refactoring
1. Keep behavior identical
2. Reduce line count when possible
3. Extract examples → references/
4. Document in CHANGELOG

---

## Scripts

- `scripts/rename-namespace.sh` - One-time namespace migration `ck → sk`
- `scripts/validate-skills.sh` - Validate frontmatter compliance
- `scripts/add-interactive-ui-ref.sh` - Append UI protocol reference to all skills

---

## Governance

### Skill quality enforcement
- CI/CD runs `validate-skills.sh` on every PR
- CI/CD checks for `/ck:` references (must be 0)
- CI/CD warns on skills > 400 lines

### Deprecation policy
1. Mark skill frontmatter: `deprecated: true` + `replaced_by: sk-name`
2. Update `DEPRECATIONS.md`
3. Keep deprecated skill for 1 release cycle
4. Remove in next major version

### Versioning
- Semantic versioning (MAJOR.MINOR.PATCH)
- Pre-release: `-alpha`, `-beta`, `-rc`
- Auto-release via `semantic-release` (planned for Phase 7)

---

## When Working on This Codebase

1. **Read this file first** before making changes
2. **Check existing skills** before creating new ones (DRY)
3. **Run validator** before commit: `./scripts/validate-skills.sh`
4. **Use Interactive UI** in all skill prompts (no free-text questions)
5. **Update CHANGELOG.md** for user-facing changes
6. **Tag PRs** with conventional commit type

---

## Migration from ClaudeKit

If you're migrating from ClaudeKit:
- See [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md) (TBD)
- All `/ck:*` commands → `/sk:*`
- 7 skills removed (see `DEPRECATIONS.md`)
- Interactive UI now mandatory

---

## Contact

- Issues: GitHub Issues
- Email: sanpema1998@gmail.com
- Maintainer: @tungpc

---

**Last updated:** 2026-04-25
