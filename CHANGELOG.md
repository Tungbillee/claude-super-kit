# Changelog

All notable changes to Claude Super Kit will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added
- Phase 0 foundation complete
- Namespace `/sk:*` established
- Interactive UI Protocol mandatory for all skills
- Response language auto-detection rule
- 80 skills with explicit Interactive UI references (Option B)

### Changed
- Forked from ClaudeKit v2.15.1
- Renamed all `ck-*` skills → `sk-*` (8 framework skills)
- Replaced all `/ck:` command references → `/sk:`

### Removed
- None yet (deferred to Phase 1)

---

## [0.1.0-alpha] - 2026-04-25

### Added
- Initial fork from ClaudeKit v2.15.1
- 84 skills copied from upstream
- 62 commands copied from upstream
- 5 rules files + new `interactive-ui-protocol.md`
- Governance files: README, LICENSE (MIT), CONTRIBUTING, CHANGELOG
- Scripts: `rename-namespace.sh`, `validate-skills.sh`, `add-interactive-ui-ref.sh`
- CI/CD workflow scaffolding

### Roadmap
- Phase 1: Cleanup (delete duplicates, merge overlaps, refactor bloat) — 6 days
- Phase 2: Critical capabilities (Vue, Nuxt, Electron, VN payments) — 10 days
- Phase 3: High-priority frameworks + databases — 10 days
- Phase 4: Observability stack — 5 days
- Phase 5: Testing advanced — 4 days
- Phase 6: Modern web (i18n, SEO, PWA) — 3 days
- Phase 7: Nice-to-have — 10 days
- Phase 8: Release v1.0.0 — 2 days

**Total timeline:** 10 weeks

---

## Version Policy

- **Major** (x.0.0): Breaking changes in skill API, namespace changes
- **Minor** (0.x.0): New skills, new features
- **Patch** (0.0.x): Bug fixes, doc updates

Pre-release tags:
- `-alpha`: Experimental
- `-beta`: Feature-complete, testing
- `-rc`: Release candidate
