# Chrome DevTools — Scripts Documentation

All scripts in `.claude/skills/chrome-devtools/scripts/`. Output JSON unless noted.

## Script Reference

### Navigation & Interaction
| Script | Purpose | Key Options |
|--------|---------|-------------|
| `navigate.js` | Navigate to URL | `--url`, `--wait-until`, `--wait-for-login <pattern>`, `--login-timeout <ms>`, `--close true` |
| `click.js` | Click element | `--selector` (CSS or XPath) |
| `fill.js` | Fill form field | `--selector`, `--value` |
| `select-ref.js` | Interact by ARIA ref | `--ref eN`, `--action click\|fill\|text\|screenshot\|focus\|hover`, `--value` |

### Capture & Inspection
| Script | Purpose | Key Options |
|--------|---------|-------------|
| `screenshot.js` | Capture screenshots | `--url`, `--output`, `--selector`, `--full-page true`, `--max-size <MB>`, `--no-compress` |
| `snapshot.js` | Extract interactive elements (JSON) | `--url` |
| `aria-snapshot.js` | Get ARIA accessibility tree (YAML + refs) | `--url`, `--output <file>` |
| `evaluate.js` | Execute JS in page context | `--url`, `--script "<js>"` |

### Diagnostics
| Script | Purpose | Key Options |
|--------|---------|-------------|
| `console.js` | Monitor console messages/errors | `--url`, `--types error,warn`, `--duration <ms>` |
| `network.js` | Track HTTP requests/responses | `--url` |
| `performance.js` | Measure Core Web Vitals | `--url` |
| `ws-debug.js` | Debug WebSocket connections (basic) | `--url` |
| `ws-full-debug.js` | Debug WebSocket with full events/frames | `--url` |

### Authentication
| Script | Purpose | Key Options |
|--------|---------|-------------|
| `inject-auth.js` | Inject cookies/tokens | `--url`, `--cookies '[{...}]'`, `--token`, `--header`, `--clear true` |
| `import-cookies.js` | Import cookies from JSON/Netscape file | `--file`, `--url`, `--format netscape`, `--strict-domain` |
| `connect-chrome.js` | Connect to Chrome with remote debugging | `--browser-url http://localhost:9222`, `--launch`, `--port`, `--url` |

## Global Options (All Scripts)
- `--headless true/false` — Override auto-detected headless mode
- `--close true` — Close browser completely (default: stay running)
- `--timeout <ms>` — Set timeout (default: 30000)
- `--wait-until networkidle2` — Wait strategy

## Screenshot Auto-Compression
Screenshots >5MB auto-compress via Sharp (4-5x faster than ImageMagick):
```bash
# Custom threshold
node "$SKILL_DIR/screenshot.js" --output ./page.png --max-size 3
# Disable compression
node "$SKILL_DIR/screenshot.js" --output ./page.png --no-compress
```

## Authentication Methods

### Method 1: Inject Cookies Directly
```bash
node "$SKILL_DIR/inject-auth.js" --url https://site.com \
  --cookies '[{"name":"session","value":"abc123","domain":".site.com"}]'
# With Bearer token
node "$SKILL_DIR/inject-auth.js" --url https://api.site.com \
  --token "Bearer eyJhbG..." --header Authorization
```

### Method 2: Import from Browser Extension
```bash
# Export via "Cookie-Editor" Chrome extension → save to cookies.json
node "$SKILL_DIR/import-cookies.js" --file ./cookies.json --url https://site.com
# Netscape format
node "$SKILL_DIR/import-cookies.js" --file ./cookies.txt --format netscape --url https://site.com
```

### Method 3: Use Chrome Profile
```bash
node "$SKILL_DIR/navigate.js" --url https://site.com --use-default-profile true
```
**Profile paths:** macOS: `~/Library/Application Support/Google/Chrome` | Windows: `%LOCALAPPDATA%/Google/Chrome/User Data` | Linux: `~/.config/google-chrome`
**[!]** Chrome must be fully closed (single instance lock).

### Method 4: Connect to Running Chrome
```bash
# Launch Chrome with remote debugging
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
# Connect and automate
node "$SKILL_DIR/connect-chrome.js" --browser-url http://localhost:9222 --url https://site.com
```

### Method 5: Interactive Login (OAuth/SSO)
```bash
node "$SKILL_DIR/navigate.js" --url https://app.example.com/login \
  --wait-for-login "/dashboard" --login-timeout 600000
```
Opens headed browser, waits for manual login, saves cookies to `.auth-session.json` (24h reuse).

### Choosing Auth Method
| Method | Best For | Complexity |
|--------|----------|------------|
| Inject cookies | Simple session cookies, API tokens | Low |
| Import from extension | Multi-cookie auth, OAuth tokens | Medium |
| Chrome profile | 2FA, SSO, complex OAuth flows | Low* |
| Connect to Chrome | Debugging, visual verification | Medium |
| Interactive login | OAuth/SSO with manual browser interaction | Low |

*Requires Chrome closed first
