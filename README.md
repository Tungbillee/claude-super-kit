# Claude Super Kit

**The Vietnamese-first ClaudeKit fork — 120+ skills, zero bloat, interactive-by-default.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Skills](https://img.shields.io/badge/Skills-119-blue)](./skills)
[![Namespace](https://img.shields.io/badge/Namespace-%2Fsk%3A*-green)](./rules)

---

## What is Claude Super Kit?

Super Kit is a curated, Vietnam-focused fork of [ClaudeKit](https://github.com/anthropics/claude-kit) with:

- ✅ **Zero duplicates** — cleanup of 8 overlapping skills from upstream
- ✅ **Interactive UI by default** — all skills use `AskUserQuestion` (keyboard navigate, no typing)
- ✅ **LLM-aware planning** — auto-suggest Claude vs GPT per task/phase
- ✅ **Vietnam-first** — Vue/Nuxt, Electron, Wails, VN payments (SePay/Pay2s/VNPay/MoMo/ZaloPay)
- ✅ **Observability built-in** — logging, tracing, metrics, errors, APM
- ✅ **Namespace `/sk:*`** — coexists with original `/ck:*` during migration

---

## Quick Start

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/tungpc/claude-super-kit/main/install.sh | bash
```

Or manual:

```bash
git clone https://github.com/tungpc/claude-super-kit.git
cd claude-super-kit
./install.sh
```

### Verify

Open Claude Code and try:

```
/sk:plan "Build authentication system"
```

You should see interactive question UI (no typing required).

---

## Feature Matrix

| Category | Super Kit | ClaudeKit | Claudex |
|---|---|---|---|
| Total skills | **119** | 84 | ~40 |
| Vietnamese stack coverage | **95%** | 65% | 70% |
| Duplicate skills | **0** | 8 | 0 |
| VN payment providers | **5** | 1 | 0 |
| FE frameworks | **React + Vue + Svelte + SolidJS + Astro** | React only | React |
| Desktop frameworks | **Electron + Wails** | 0 | 0 |
| Observability skills | **5** | 0 | 0 |
| Interactive UI enforcement | ✅ Mandatory | ⚠️ Optional | ⚠️ Partial |
| LLM recommendation | ✅ Per phase/task | ❌ | ❌ |
| License | MIT | MIT | Unlisted |

See full comparison: [46-row comparison table](./docs/comparison-matrix.md)

---

## Core Skills (Top 20)

| Skill | Purpose |
|---|---|
| `/sk:plan` | Plan implementations with phases + LLM tagging |
| `/sk:cook` | Implement features step-by-step |
| `/sk:fix` | Fix bugs with root-cause analysis |
| `/sk:debug` | Systematic debugging (9 techniques) |
| `/sk:test` | Unit/integration/e2e/perf/a11y/visual tests |
| `/sk:review` | Adversarial code review (3-stage) |
| `/sk:brainstorm` | Solution exploration with interactive UI |
| `/sk:bootstrap` | Scaffold new projects |
| `/sk:scout` | Fast codebase exploration |
| `/sk:git` | Conventional commits + PR flow |
| `/sk:deploy` | Multi-platform deployment |
| `/sk:design` | UI/UX design system |
| `/sk:frontend-design` | Production-ready UI (with `--pro` tier) |
| `/sk:security` | STRIDE + OWASP audit (with `--fix` flag) |
| `/sk:docs` | Documentation management |
| `/sk:journal` | Work journal entries |
| `/sk:ask` | Technical Q&A |
| `/sk:research` | In-depth research |
| `/sk:watzup` | Session wrap-up |
| `/sk:ship` | Full ship pipeline |

---

## Specialized Skills

### Vietnam Stack (VN-focused)
- Payment: `sk-payment-sepay`, `sk-payment-pay2s`, `sk-payment-vnpay`, `sk-payment-momo`, `sk-payment-zalopay`
- Desktop: `sk-electron-apps`, `sk-wails-desktop`
- Frontend: `sk-vue-development`, `sk-nuxt-full-stack`

### Modern Frontend
- `sk-svelte-development`, `sk-sveltekit-full-stack`, `sk-solidjs-development`, `sk-astro-static`

### Backend & Data
- `sk-go-backend-advanced`, `sk-redis-advanced`, `sk-firebase-realtime`, `sk-elasticsearch`
- `sk-graphql-advanced`, `sk-message-queues`

### Observability (5-skill suite)
- `sk-structured-logging`, `sk-distributed-tracing`, `sk-metrics-monitoring`
- `sk-error-tracking`, `sk-apm-profiling`

### Testing Advanced
- `sk-performance-testing`, `sk-mutation-testing`, `sk-a11y-testing`, `sk-visual-regression`

### Modern Web
- `sk-i18n-localization`, `sk-seo-optimization`, `sk-pwa-development`

### DX Tools
- `sk-code-reuse-checker` (YAGNI enforcement)
- `sk-semantic-release` (auto versioning)

---

## Key Features

### 1. Interactive UI (Mandatory)

All skills use `AskUserQuestion` — no free-text prompts:

```
┌─────────────────────────────────────────┐
│ Which framework?              1 of 3    │
├─────────────────────────────────────────┤
│ [1] Next.js                             │
│ [2] Nuxt                                │
│ [3] SvelteKit                           │
│ [✎] Something else                      │
└─────────────────────────────────────────┘
      ↑↓ navigate · Enter select
```

See: [rules/interactive-ui-protocol.md](./rules/interactive-ui-protocol.md)

### 2. LLM-Aware Planning

`/sk:plan` and `/sk:brainstorm` auto-tag tasks with recommended LLM:

```
Phase 1: Database schema
  - [llm: claude] Design ERD  (complex reasoning)
  - [llm: gpt] Write migrations (boilerplate)

Phase 2: OAuth flows
  - [llm: claude] Callback logic (security-critical)
  - [llm: gpt] Config setup (standard pattern)
```

Final confirmation via `AskUserQuestion` — user approves or overrides.

### 3. Response Language Auto-Detection

- User asks in Vietnamese → respond Vietnamese
- User asks in English → respond English
- Skills stay in English (LLM training data optimization)

---

## Documentation

- [Installation Guide](./INSTALLATION.md)
- [Interactive UI Protocol](./rules/interactive-ui-protocol.md)
- [Contributing](./CONTRIBUTING.md)
- [Changelog](./CHANGELOG.md)
- [Deprecations](./DEPRECATIONS.md)
- [Migration Guide (from ClaudeKit)](./MIGRATION-GUIDE.md)

---

## Philosophy

> **YAGNI. KISS. DRY. Vietnamese-first.**

1. **YAGNI** — No speculative features. If not needed today, don't build.
2. **KISS** — Simple over clever. Hardcoded rules > dynamic inference.
3. **DRY** — Zero duplicates. `sk-code-reuse-checker` enforces this.
4. **Vietnamese-first** — Target VN market: payments, stack, community.

---

## Differences from ClaudeKit

| Aspect | ClaudeKit | Super Kit |
|---|---|---|
| Duplicates | `debugging` + `ck-debug`, `planning` + `ck-plan`, etc. | Cleaned up |
| Bloat | `ui-ux-pro-max` 661 lines | Refactored ≤400 |
| VN payments | SePay only | 5 providers |
| Desktop | None | Electron + Wails |
| Vue/Nuxt | None | Full specialization |
| UI pattern | Optional AskUserQuestion | Mandatory |
| Namespace | `/ck:*` | `/sk:*` |

---

## Roadmap

### v1.0 (Current) — Core + VN Stack
- All foundational skills
- VN payment providers
- Vue/Nuxt/Electron/Wails
- Observability suite

### v1.1 — Multi-Provider LLM
- Cursor, Gemini CLI, Codex integrations
- Cross-LLM skill handoff

### v1.2 — Enterprise Features
- Legal/Compliance (GDPR)
- SBOM generation
- Cost optimization

### v2.0 — Community-driven
- TBD based on user feedback

---

## Contributing

Pull requests welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md).

**Quick guidelines:**
- All skills must follow [Interactive UI Protocol](./rules/interactive-ui-protocol.md)
- Skill SKILL.md ≤ 400 lines (hard limit)
- Include frontmatter with `name`, `description`, `version`, `author`
- English source, Vietnamese CLAUDE.md
- Conventional commits

---

## License

[MIT](./LICENSE) © tungpc + Claude Super Kit contributors

---

## Credits

Forked and enhanced from [ClaudeKit](https://github.com/claudekit) by Dexteryy.

**Maintainer:** [@tungpc](https://github.com/tungpc)
**Contact:** sanpema1998@gmail.com
