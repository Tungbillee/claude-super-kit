---
name: sk:security
description: "STRIDE + OWASP-based security audit with optional auto-fix. Scans code for vulnerabilities, categorizes by severity, and can iteratively fix findings using sk:autoresearch pattern. Includes quick scan mode for lightweight secret/dep/pattern checks."
argument-hint: "<scope glob or 'full'> [--fix] [--iterations N] [--scan] [--secrets-only] [--deps-only]"
metadata:
  author: claudekit
  attribution: "Security audit pattern adapted from autoresearch by Udit Goenka (MIT)"
  license: MIT
  version: "1.1.0"
  last_updated: "2026-04-25"
---

# sk:security — Security Audit

Runs a structured STRIDE + OWASP security audit on a given scope. Produces a severity-ranked findings report. With `--fix`, applies fixes iteratively using the sk:autoresearch guard pattern.

## When to Use

- Before a release or major deployment
- After adding auth, payment, or data-handling features
- Periodic security review (monthly/quarterly)
- Compliance check (SOC 2, GDPR, PCI-DSS prep)

## When NOT to Use

- Purely cosmetic changes (CSS, copy edits)
- No user-facing code or data handling involved

---

## Modes

| Mode | Invocation | Behavior |
|------|-----------|----------|
| Audit only | `/sk:security <scope>` | Scan → categorize → report |
| Audit + Fix | `/sk:security <scope> --fix` | Scan → categorize → fix iteratively |
| Bounded fix | `/sk:security <scope> --fix --iterations N` | Limit fix iterations to N |
| Quick scan | `/sk:security <scope> --scan` | Lightweight grep-based scan (no STRIDE, fast) |
| Secrets only | `/sk:security --secrets-only` | Only secret/credential detection |
| Deps only | `/sk:security --deps-only` | Only dependency audit |

---

## Audit Methodology

### 1. Scope Resolution
Expand the provided glob or `full` keyword into a file list. Read all in-scope files before analysis.

### 2. STRIDE Analysis
Evaluate each threat category systematically:
- **S**poofing — identity/authentication weaknesses
- **T**ampering — input validation, integrity controls
- **R**epudiation — audit logging gaps
- **I**nformation Disclosure — data leakage, secret exposure
- **D**enial of Service — rate limits, resource exhaustion
- **E**levation of Privilege — broken access control, RBAC gaps

### 3. OWASP Top 10 Check
Map findings to OWASP categories (A01–A10). See `references/stride-owasp-checklist.md` for per-category checks.

### 4. Dependency Audit
Run the appropriate package audit tool for the detected stack:
- Node.js: `npm audit`
- Python: `pip-audit`
- Go: `govulncheck`
- Ruby: `bundle audit`

### 5. Secret Detection
Scan for hardcoded API keys, passwords, tokens, and private keys using regex patterns. See `references/stride-owasp-checklist.md` → Secret Patterns.

### 6. Finding Categorization
Assign each finding a severity level (see Severity Definitions below).

---

## Output Format

```
## Security Audit Report

### Summary
- Files scanned: N
- Findings: X critical, Y high, Z medium, W low, V info

### Findings

| # | Severity | Category | File:Line | Description | Fix Recommendation |
|---|----------|----------|-----------|-------------|-------------------|
| 1 | Critical  | Injection | api/users.ts:45 | SQL string concatenation | Use parameterized queries |
| 2 | High      | Auth      | auth/login.ts:12 | No rate limiting | Add express-rate-limit |
```

---

## Fix Mode (--fix)

When `--fix` is provided, apply fixes iteratively after the audit:

1. Sort all findings by severity (Critical → High → Medium → Low)
2. For each finding:
   a. Apply one targeted fix
   b. Run guard (tests or lint) to verify no regression
   c. Commit: `security(fix-N): <short description>`
   d. Advance to next finding
3. Stop early if guard fails — report the failure instead of proceeding
4. Uses `sk:autoresearch` guard pattern for regression prevention

> Tip: Use `--iterations N` to cap total fix iterations when scope is large.

---

## Severity Definitions

| Severity | Description | Fix Priority |
|----------|-------------|-------------|
| Critical | Exploitable now, data breach or RCE risk | Immediate — block release |
| High | Exploitable with moderate effort, significant impact | This sprint |
| Medium | Limited exploitability or impact | Next sprint |
| Low | Theoretical risk, defense-in-depth improvement | Backlog |
| Info | Best practice suggestion, no direct risk | Optional |

---

## Integration with Other Skills

- Run after `sk:predict` when the security persona flags concerns
- Feed Critical/High findings into `sk:autoresearch --fix` for automated remediation
- Use `sk:scenario` with `--focus authorization` for deeper auth flow testing
- Pair with `sk:plan` to schedule Medium/Low findings as sprint tasks

---

## Example Invocations

```bash
# Audit API layer only
/sk:security src/api/**/*.ts

# Audit entire src/ and auto-fix, max 15 iterations
/sk:security src/ --fix --iterations 15

# Full codebase audit (no fix)
/sk:security full
```

---

See `references/stride-owasp-checklist.md` for the detailed per-category checklist and secret detection regex patterns.

---

## Quick Scan Mode (--scan / --secrets-only / --deps-only)

Lightweight scanner using grep patterns — no STRIDE analysis, no file-by-file reading. Fast, no external dependencies.

### Workflow

**1. Detect Project Type**
```
- package.json → Node.js → run npm audit
- requirements.txt / pyproject.toml → Python → run pip audit
- go.mod → Go | Cargo.toml → Rust
```

**2. Secret Detection** (always runs first)

Use Grep tool with patterns from `references/secret-patterns.md`:
- API keys/tokens (AWS `AKIA[0-9A-Z]{16}`, GitHub, Stripe, etc.)
- Private keys and certificates
- DB connection strings with credentials
- Hardcoded passwords

**Exclude:** `.env.example`, test fixtures, docs, `node_modules/`, `dist/`

For each match: verify real secret (not placeholder like `YOUR_API_KEY`), rate severity:
- CRITICAL = exposed prod key
- HIGH = real credential
- MEDIUM = possible credential

**3. Dependency Audit**
```bash
npm audit --json 2>/dev/null || echo '{"error":"npm audit failed"}'
pip audit --format json 2>/dev/null || echo '{"error":"pip audit unavailable"}'
```

**4. Code Pattern Analysis**

Use Grep with patterns from `references/vulnerability-patterns.md`:
- SQL injection (string concat in queries)
- XSS (`innerHTML`, `dangerouslySetInnerHTML` without sanitization)
- Command injection (`exec`/`spawn` with unsanitized input)
- Path traversal (user input in file paths)
- Insecure randomness (`Math.random` for security)
- `eval()` / `Function()` with dynamic input

**5. .env Exposure Check**
```bash
git ls-files --error-unmatch .env .env.local .env.production 2>/dev/null
grep -n "\.env" .gitignore 2>/dev/null
```

**6. Quick Scan Report**

```markdown
# Security Scan Report
**Project:** {name} | **Scanned:** {date} | **Files:** {count}

## Summary
| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| Secrets  | X | X | X | - |
| Deps     | X | X | X | X |
| Code     | X | X | X | - |

## Findings
### CRITICAL
1. **[SECRET]** Hardcoded AWS key in `src/config.js:42`
   - Pattern: `AKIA[0-9A-Z]{16}`
   - Fix: Move to environment variable
```

If `--auto` mode active: save to `{CK_REPORTS_PATH}` or `plans/reports/security-scan-{date}.md`.

### Security Policy (Quick Scan)
- NEVER output actual secret values — redact to first 4 + last 2 chars
- NEVER execute secrets or credentials found
- NEVER modify code automatically — report only with fix suggestions
- If real credential found: recommend immediate rotation

---

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).

**Rules:**
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts like "Please answer: 1) X? 2) Y?"
- Each question: 2-4 predefined options + auto "Something else"
- Exception: genuine free-form inputs (file paths, custom names, code snippets)

See rule for full specification.

