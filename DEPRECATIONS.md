# Deprecations Policy

This document tracks skills that have been removed, merged, or replaced in Claude Super Kit.

---

## Deprecation Process

1. **Mark deprecated** — Add `deprecated: true` and `replaced_by: <new-skill>` to frontmatter
2. **Document here** — Add entry to "Removed in v0.2.0" or appropriate section below
3. **One release cycle** — Keep deprecated skill for at least one minor version
4. **Remove** — Delete in next major version

---

## Removed in v1.1.0 (2026-04-25)

### Merged: sk:debug + sk:fix → sk:debug-fix

| Old commands | New unified command |
|---|---|
| `/sk:debug` (investigation only) | `/sk:debug-fix` |
| `/sk:fix` (fixing only) | `/sk:debug-fix` |

**Lý do:** User workflow điển hình là debug → fix sequential, gộp 1 command tránh switch context + share state.

**Migration:**
```
# Old (2-step):
/sk:debug "API 500 error"
/sk:fix

# New (1-step):
/sk:debug-fix "API 500 error"
```

`/sk:debug-fix` includes:
- 7-step workflow: Mode Selection → Scout → Investigate → Diagnose → Complexity Assessment → Fix → Verify+Prevent → Finalize
- 26 references gộp từ cả 2 skills
- Scripts: find-polluter.sh
- LLM Mismatch Warning

---

## Removed in v0.2.0-cleanup (2026-04-25)

### Duplicate / Stale skills (deleted entirely)

| Skill | Reason | Replacement |
|---|---|---|
| `debugging` | Exact duplicate of `sk-debug` (Dec 2024 stale) | Use `/sk:debug` |
| `planning` | Subsumed by `sk-plan` (Dec 2024 stale) | Use `/sk:plan` |
| `template-skill` | Placeholder leftover (9 lines) | Use `/sk:skill:create` instead |

### Merged skills (consolidated)

| Source (deleted) | Target (kept) | Migration |
|---|---|---|
| `security-scan` | `sk-security` | Use `/sk:security` (scan-only by default) or `/sk:security --fix` for autoresearch fix mode |
| `frontend-design-pro` | `frontend-design` | Use `/sk:frontend-design` (default) or `/sk:frontend-design --pro` for agency-grade output |
| `web-testing` | `test` | Use `/sk:test` — now includes Playwright, k6 (perf), axe-core (a11y), Percy/Chromatic (visual regression) references |
| `use-mcp` | `mcp-builder` | Use `/sk:mcp-builder` — quick usage section absorbed |

### Refactored (kept but slimmed down)

| Skill | Before | After | Notes |
|---|---|---|---|
| `ui-ux-pro-max` | 675 lines | 255 lines | Examples + advanced patterns moved to `references/` |
| `chrome-devtools` | 644 lines | 250 lines | Script docs + automation patterns moved to `references/` |

### Metadata fixes

| Skill | Fix |
|---|---|
| `ai-multimodal` | Added `version`, `author`, `type`, `namespace`, `category`, `last_updated` fields |
| `claude-code` | Added metadata + clarified scope (`type: documentation`, `scope: documentation-only` to distinguish from `sk-review`) |

---

## Migration Guide for Users

### From ClaudeKit `/ck:*` to Super Kit `/sk:*`

All commands renamed:
```
/ck:plan       → /sk:plan
/ck:cook       → /sk:cook
/ck:fix        → /sk:fix
/ck:debug      → /sk:debug
/ck:security   → /sk:security
... (and so on)
```

### From legacy skills

**Before:**
```
/debugging     ❌ removed
/planning      ❌ removed
/security-scan ❌ removed
/frontend-design-pro ❌ removed
/web-testing   ❌ removed
/use-mcp       ❌ removed
```

**After:**
```
/sk:debug                          ✅
/sk:plan                           ✅
/sk:security                       ✅ (or /sk:security --fix)
/sk:frontend-design --pro          ✅
/sk:test                           ✅ (now includes web testing)
/sk:mcp-builder                    ✅
```

---

## How to Report Issues

If you depended on a removed skill and need help migrating:
- Open an issue: [github.com/Tungbillee/claude-super-kit/issues](https://github.com/Tungbillee/claude-super-kit/issues)
- Email: sanpema1998@gmail.com

---

**Last updated:** 2026-04-25
**Next review:** v0.3.0 (Phase 2 complete)
