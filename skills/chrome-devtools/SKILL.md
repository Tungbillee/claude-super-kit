---
name: sk:chrome-devtools
description: Automate browsers with Puppeteer CLI scripts and persistent sessions. Use for screenshots, performance analysis, network monitoring, web scraping, form automation, JavaScript debugging.
license: Apache-2.0
argument-hint: "[url or task]"
metadata:
  author: claudekit
  version: "1.1.0"
  last_updated: "2026-04-25"
---

# Chrome DevTools Agent Skill

Browser automation via Puppeteer scripts with persistent sessions. All scripts output JSON.

## Skill Location

Skills can exist in **project-scope** or **user-scope**. Priority: project-scope > user-scope.

```bash
SKILL_DIR=""
if [ -d ".claude/skills/chrome-devtools/scripts" ]; then
  SKILL_DIR=".claude/skills/chrome-devtools/scripts"
elif [ -d "$HOME/.claude/skills/chrome-devtools/scripts" ]; then
  SKILL_DIR="$HOME/.claude/skills/chrome-devtools/scripts"
fi
# Run scripts with full path: node "$SKILL_DIR/script.js" --args
```

## Choosing Your Approach

| Scenario | Approach |
|----------|----------|
| **Source-available sites** | Read source code first, write selectors directly |
| **Unknown layouts** | Use `aria-snapshot.js` for semantic discovery |
| **Visual inspection** | Take screenshots to verify rendering |
| **Debug issues** | Collect console logs, analyze with session storage |
| **Accessibility audit** | Use ARIA snapshot for semantic structure analysis |

## Automation Running Mode

`resolveHeadless()` in `lib/browser.js` auto-detects:

| Environment | Default | Why |
|-------------|---------|-----|
| **macOS / Windows** | **Headed** (visible) | Better debugging, OAuth login support |
| **Linux / WSL** | **Headless** | Servers typically have no display |
| **CI** (env vars: `CI`, `GITHUB_ACTIONS`, etc.) | **Headless** | No display available |

Override with `--headless true/false`. Run multiple scripts in parallel to simulate real users or different device types.

## Quick Start

```bash
# Install dependencies (one-time)
npm install --prefix "$SKILL_DIR"
# Linux/WSL only: run install-deps.sh first for Chrome system libraries

node "$SKILL_DIR/navigate.js" --url https://example.com
# Output: {"success": true, "url": "...", "title": "..."}
```

## Session Persistence

Browser state persists via `.browser-session.json`. Scripts disconnect but keep browser running for reuse.

```bash
node "$SKILL_DIR/navigate.js" --url https://example.com/login
node "$SKILL_DIR/fill.js" --selector "#email" --value "user@example.com"
node "$SKILL_DIR/click.js" --selector "button[type=submit]"
node "$SKILL_DIR/navigate.js" --url about:blank --close true  # close when done
```

## Available Scripts

> Full options and auth methods → [references/scripts-documentation.md](references/scripts-documentation.md)

| Script | Purpose |
|--------|---------|
| `navigate.js` | Navigate to URLs |
| `screenshot.js` | Capture screenshots (auto-compress >5MB via Sharp) |
| `click.js` | Click elements |
| `fill.js` | Fill form fields |
| `evaluate.js` | Execute JS in page context |
| `snapshot.js` | Extract interactive elements (JSON) |
| `aria-snapshot.js` | Get ARIA accessibility tree (YAML + refs) |
| `select-ref.js` | Interact with elements by ARIA ref |
| `console.js` | Monitor console messages/errors |
| `network.js` | Track HTTP requests/responses |
| `performance.js` | Measure Core Web Vitals |
| `ws-debug.js` | Debug WebSocket connections (basic) |
| `ws-full-debug.js` | Debug WebSocket with full events/frames |
| `inject-auth.js` | Inject cookies/tokens for authentication |
| `import-cookies.js` | Import cookies from JSON/Netscape file |
| `connect-chrome.js` | Connect to Chrome with remote debugging |

## Workflow Loop

1. **Execute** focused script for single task
2. **Observe** JSON output
3. **Assess** completion status
4. **Decide** next action
5. **Repeat** until done

## ARIA Snapshot (Element Discovery)

When page structure is unknown, use `aria-snapshot.js` for YAML accessibility tree with refs.

```bash
node "$SKILL_DIR/aria-snapshot.js" --url https://example.com
node "$SKILL_DIR/aria-snapshot.js" --url https://example.com --output ./.claude/chrome-devtools/snapshots/page.yaml
```

**ARIA notation:** `[ref=eN]` stable ID · `[checked]` · `[disabled]` · `[expanded]` · `/url:` · `/value:`

**Interact by ref:**
```bash
node "$SKILL_DIR/select-ref.js" --ref e5 --action click
node "$SKILL_DIR/select-ref.js" --ref e10 --action fill --value "search query"
```

**Workflow for unknown pages:**
1. Get snapshot → 2. Identify `[ref=eN]` → 3. Interact by ref → 4. Verify with screenshot

## Screenshots

Store in `<project>/.claude/chrome-devtools/screenshots/`:

```bash
node "$SKILL_DIR/screenshot.js" --url https://example.com --output ./.claude/chrome-devtools/screenshots/page.png
node "$SKILL_DIR/screenshot.js" --url https://example.com --output ./page.png --full-page true
node "$SKILL_DIR/screenshot.js" --url https://example.com --selector ".main-content" --output ./element.png
```

**IMPORTANT:** Invoke `/sk:project-organization` skill to organize outputs.

## Console & Network Diagnostics

```bash
# Capture logs
node "$SKILL_DIR/console.js" --url https://example.com --types error,warn --duration 5000

# Session storage pattern
SESSION="$(date +%Y%m%d-%H%M%S)" && mkdir -p .claude/chrome-devtools/logs/$SESSION
node "$SKILL_DIR/console.js" --url https://example.com --duration 10000 > .claude/chrome-devtools/logs/$SESSION/console.json
node "$SKILL_DIR/network.js" --url https://example.com > .claude/chrome-devtools/logs/$SESSION/network.json

# Root cause: JS errors + network failures
node "$SKILL_DIR/console.js" --url https://example.com --types error,pageerror --duration 5000 | jq '.messages'
node "$SKILL_DIR/network.js" --url https://example.com | jq '.requests[] | select(.response.status >= 400)'
```

## Common Patterns

### Finding Elements
```bash
node "$SKILL_DIR/snapshot.js" --url https://example.com | jq '.elements[] | {tagName, text, selector}'
node "$SKILL_DIR/snapshot.js" --url https://example.com | jq '.elements[] | select(.text | contains("Submit"))'
```

### Web Scraping
```bash
node "$SKILL_DIR/evaluate.js" --url https://example.com --script "
  Array.from(document.querySelectorAll('.item')).map(el => ({
    title: el.querySelector('h2')?.textContent,
    link: el.querySelector('a')?.href
  }))
" | jq '.result'
```

### Form Automation
```bash
node "$SKILL_DIR/navigate.js" --url https://example.com/form
node "$SKILL_DIR/fill.js" --selector "#search" --value "query"
node "$SKILL_DIR/click.js" --selector "button[type=submit]"
```

### Performance Testing
```bash
node "$SKILL_DIR/performance.js" --url https://example.com | jq '.vitals'
```

## Local HTML Files

**NEVER** use `file://` protocol — blocks CORS, ES modules, fetch API, service workers.

```bash
npx serve ./dist -p 3000 &
node "$SKILL_DIR/navigate.js" --url http://localhost:3000
```

## Writing Custom Scripts

Write to `<project>/.claude/chrome-devtools/tmp/`. Key principles:
- Single-purpose: one script, one task
- Always call `disconnectBrowser()` at end (keeps browser running)
- Use `closeBrowser()` only when ending session completely
- Output JSON for easy parsing
- Plain JavaScript only in `page.evaluate()` callbacks

```bash
mkdir -p .claude/chrome-devtools/tmp
# Import from lib/browser.js: getBrowser, getPage, disconnectBrowser, outputJSON
```

## Authentication

Five methods available — see [references/scripts-documentation.md](references/scripts-documentation.md) for full details.

| Method | Best For |
|--------|----------|
| Inject cookies | Simple session cookies, API tokens |
| Import from extension | Multi-cookie auth, OAuth tokens |
| Chrome profile | 2FA, SSO, complex OAuth flows |
| Connect to Chrome | Debugging, visual verification |
| Interactive login (`--wait-for-login`) | OAuth/SSO with manual browser interaction |

Auth sessions saved to `.auth-session.json` for 24-hour reuse.

## Troubleshooting

| Error | Solution |
|-------|----------|
| `Cannot find package 'puppeteer'` | Run `npm install` in scripts directory |
| `libnss3.so` missing (Linux) | Run `./install-deps.sh` |
| Element not found | Use `snapshot.js` or `aria-snapshot.js` to find correct selector |
| Script hangs | Use `--timeout 60000` or `--wait-until load` |
| Screenshot >5MB | Auto-compressed; use `--max-size 3` for lower threshold |
| Session stale | Delete `.browser-session.json` and retry |
| Images missing in screenshot | Scroll into view first; wait for animations (`evaluate.js --script "await new Promise(r => setTimeout(r, 1500))"`) |

## Reference Documentation

- `./references/scripts-documentation.md` - Full script options + all auth methods
- `./references/cdp-domains.md` - Chrome DevTools Protocol domains
- `./references/puppeteer-reference.md` - Puppeteer API patterns
- `./references/performance-guide.md` - Core Web Vitals optimization
- `./scripts/README.md` - Detailed script options

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).

**Rules:**
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts like "Please answer: 1) X? 2) Y?"
- Each question: 2-4 predefined options + auto "Something else"
- Exception: genuine free-form inputs (file paths, custom names, code snippets)

See rule for full specification.
