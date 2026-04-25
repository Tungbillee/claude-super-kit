---
name: sk:test
description: "Run unit, integration, e2e, UI, performance, accessibility, and visual regression tests. Use for test execution, coverage analysis, build verification, Playwright/k6/axe-core, and QA reports."
argument-hint: "[context] OR ui [url] OR perf [url] OR a11y [url]"
metadata:
  author: claudekit
  version: "1.1.0"
  last_updated: "2026-04-25"
---

# Testing & Quality Assurance

Comprehensive testing framework covering code-level testing (unit, integration, e2e), UI/visual testing via browser automation, coverage analysis, and structured QA reporting.

## Default (No Arguments)

If invoked with context (test scope), proceed with testing. If invoked WITHOUT arguments, use `AskUserQuestion` to present available test operations:

| Operation | Description |
|-----------|-------------|
| `(default)` | Run unit/integration/e2e tests |
| `ui` | Run UI tests on a website |

Present as options via `AskUserQuestion` with header "Test Operation", question "What would you like to do?".

## Core Principle

**NEVER IGNORE FAILING TESTS.** Fix root causes, not symptoms. No mocks/cheats/tricks to pass builds.

## When to Use

- **After implementation**: Validate new features or bug fixes
- **Coverage checks**: Ensure coverage meets project thresholds (80%+)
- **UI verification**: Visual regression, responsive layout, accessibility
- **Build validation**: Verify build process, dependencies, CI/CD compatibility
- **Pre-commit/push**: Final quality gate

## Workflows

### 1. Code Testing (`references/test-execution-workflow.md`)

Execute test suites, analyze results, generate coverage. Supports JS/TS (Jest/Vitest/Mocha), Python (pytest), Go, Rust, Flutter. Includes working process, quality standards, and tool commands.

**Load when:** Running unit/integration/e2e tests, checking coverage, validating builds

### 2. UI Testing (`references/ui-testing-workflow.md`)

Browser-based visual testing via `sk:chrome-devtools` skill. Screenshots, responsive checks, accessibility audits, form automation, console error collection. Includes auth injection for protected routes.

**Load when:** Visual regression testing, UI bugs, responsive layout checks, accessibility audits

### 3. Report Format (`references/report-format.md`)

Structured QA report template: test results overview, coverage metrics, failed tests, performance, build status, recommendations.

**Load when:** Generating test summary reports

## Quick Reference

```
Code tests     → test-execution-workflow.md
  npm test / pytest / go test / cargo test / flutter test
  Coverage: npm run test:coverage / pytest --cov

UI tests       → ui-testing-workflow.md
  Screenshots, responsive, a11y, forms, console errors
  Auth: inject-auth.js for protected routes

Reports        → report-format.md
  Structured QA summary with metrics & recommendations
```

## Working Process

1. Identify testing scope from recent changes or requirements
2. Run typecheck/analyze commands to catch syntax errors first
3. Execute appropriate test suites
4. Analyze results — focus on failures
5. Generate coverage reports if applicable
6. For frontend: run UI tests via `sk:chrome-devtools` skill
7. Produce structured summary report

## Tools Integration

- **Test runners**: Jest, Vitest, Mocha, pytest, go test, cargo test, flutter test
- **E2E / Browser**: Playwright (E2E, component testing, visual regression)
- **Coverage**: Istanbul/c8/nyc, pytest-cov, go cover
- **Browser automation**: `sk:chrome-devtools` skill for UI testing (screenshots, ARIA, console, network)
- **Analysis**: `sk:ai-multimodal` skill for screenshot analysis
- **Debugging**: `sk:debug` skill when tests reveal bugs requiring investigation
- **Thinking**: `sk:sequential-thinking` skill for complex test failure analysis

## Testing Strategy

| Model | Structure | Best For |
|-------|-----------|----------|
| Pyramid | Unit 70% > Integration 20% > E2E 10% | Monoliths |
| Trophy | Integration-heavy | Modern SPAs |
| Honeycomb | Contract-centric | Microservices |

→ `./references/testing-pyramid-strategy.md`

## Performance Testing (k6, Artillery)

Load and performance testing for APIs and web apps.

```bash
k6 run load-test.js                    # Basic load test
k6 run --vus 50 --duration 30s test.js # 50 virtual users, 30s
npx lighthouse https://example.com     # Lighthouse performance audit
npx lhci autorun                       # Lighthouse CI
```

Key metrics: LCP, CLS, INP (Core Web Vitals), throughput, p95/p99 latency.

→ `./references/load-testing-k6.md` | `./references/performance-core-web-vitals.md`

## Accessibility Testing (axe-core, WCAG)

Automated and manual a11y auditing to WCAG 2.1 AA/AAA standards.

```bash
npx @axe-core/cli https://example.com  # CLI audit
npx playwright test --project=a11y     # Playwright + axe integration
```

Checks: keyboard navigation, ARIA roles, color contrast, screen reader compatibility, focus management.

→ `./references/accessibility-testing.md`

## Visual Regression (Percy, Chromatic)

Screenshot comparison testing to catch unintended visual changes.

```bash
npx playwright test --update-snapshots  # Update baseline screenshots
# Percy: percy exec -- playwright test
# Chromatic: npx chromatic --project-token=<token>
```

Workflow: baseline capture → code change → comparison → approve/reject diffs.

→ `./references/visual-regression.md`

## Cross-Browser & Mobile

→ `./references/cross-browser-checklist.md` | `./references/mobile-gesture-testing.md`

## E2E with Playwright

```bash
npx playwright test              # Run all E2E
npx playwright test --ui         # Interactive UI mode
npx playwright test --debug      # Debug mode
node ./references/scripts/init-playwright.js  # Project setup
```

→ `./references/e2e-testing-playwright.md` | `./references/playwright-component-testing.md`

## CI/CD Integration

```yaml
jobs:
  test:
    steps:
      - run: npm run test:unit       # Gate 1: Fast fail
      - run: npm run test:e2e        # Gate 2: After unit pass
      - run: npm run test:a11y       # Accessibility
      - run: npx lhci autorun        # Performance
```

→ `./references/ci-cd-testing-workflows.md`

## Extended References

| Topic | Reference |
|-------|-----------|
| Unit/Integration | `./references/unit-integration-testing.md` |
| E2E Playwright | `./references/e2e-testing-playwright.md` |
| Component testing | `./references/component-testing.md` |
| Test data/fixtures | `./references/test-data-management.md` |
| Database testing | `./references/database-testing.md` |
| Contract testing | `./references/contract-testing.md` |
| API testing | `./references/api-testing.md` |
| Security testing | `./references/security-testing-overview.md` |
| Flakiness | `./references/test-flakiness-mitigation.md` |
| Pre-release | `./references/pre-release-checklist.md` |

## Quality Standards

- All critical paths must have test coverage
- Validate happy path AND error scenarios
- Ensure test isolation — no interdependencies
- Tests must be deterministic and reproducible
- Clean up test data after execution
- Never ignore failing tests to pass the build

## Report Output
**IMPORTANT:** Invoke "/sk:project-organization" skill to organize the outputs.

Use naming pattern from `## Naming` section injected by hooks.

## Team Mode

When operating as teammate:
1. On start: check `TaskList`, claim assigned/next unblocked task via `TaskUpdate`
2. Read full task description via `TaskGet` before starting
3. Wait for blocked tasks (implementation) to complete before testing
4. Respect file ownership — only create/edit test files assigned
5. When done: `TaskUpdate(status: "completed")` then `SendMessage` results to lead

**Fallback:** Task tools (`TaskList`/`TaskUpdate`/`TaskGet`) are CLI-only — unavailable in VSCode extension. If they error, use `TodoWrite` for progress tracking and coordinate via `SendMessage` only.


## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).

**Rules:**
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts like "Please answer: 1) X? 2) Y?"
- Each question: 2-4 predefined options + auto "Something else"
- Exception: genuine free-form inputs (file paths, custom names, code snippets)

See rule for full specification.

