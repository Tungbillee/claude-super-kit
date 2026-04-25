---
name: sk:mutation-testing
description: "Mutation testing with Stryker: setup for JS/TS projects, mutator config, test runner integration (Jest/Vitest/Mocha), mutation score interpretation, performance optimization, identifying weak test suites."
argument-hint: "[runner: jest|vitest|mocha] [--incremental] [--dashboard] [--threshold N]"
metadata:
  author: Claude Super Kit
  namespace: sk
  version: "1.0.0"
  last_updated: "2026-04-25"
  license: MIT
  category: testing
---

# sk:mutation-testing — Mutation Testing with Stryker

Validate test suite quality by introducing code mutations and measuring how many your tests catch.

## When to Use

- Auditing test quality beyond coverage percentage
- Finding untested edge cases (boundary conditions, boolean logic)
- Before critical releases requiring high confidence
- Establishing quality gates for CI/CD

## When NOT to Use

- Projects with < 50% line coverage (fix coverage first)
- Performance-critical CI pipelines without incremental mode
- Generated/boilerplate code files

---

## Core Concepts

**Mutation score** = (killed mutants / total mutants) × 100%

| Score | Assessment |
|-------|-----------|
| > 80% | Excellent — strong test suite |
| 60–80% | Good — some gaps to address |
| 40–60% | Fair — significant untested paths |
| < 40% | Poor — tests provide false confidence |

**Mutant statuses:**
- `Killed` — test caught the mutation (good)
- `Survived` — no test caught it (write more tests)
- `No coverage` — no test runs this code at all
- `Timeout` — mutation caused infinite loop (counted as killed)

---

## Stryker Setup (TypeScript + Jest)

```bash
npm install --save-dev @stryker-mutator/core @stryker-mutator/jest-runner
```

```javascript
// stryker.config.mjs
/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  packageManager: 'npm',
  reporters: ['html', 'clear-text', 'progress', 'dashboard'],
  testRunner: 'jest',
  coverageAnalysis: 'perTest',   // fastest: only run tests that cover each mutant

  jest: {
    projectType: 'custom',
    configFile: 'jest.config.ts',
    enableFindRelatedTests: true,  // only run tests related to mutated file
  },

  // Files to mutate (exclude boilerplate)
  mutate: [
    'src/**/*.ts',
    '!src/**/*.spec.ts',
    '!src/**/*.test.ts',
    '!src/**/index.ts',         // barrel files
    '!src/**/*.dto.ts',         // DTOs (generated)
    '!src/**/*.module.ts',      // NestJS modules
    '!src/migrations/**',
  ],

  // Mutation score thresholds
  thresholds: {
    high: 80,      // green
    low: 60,       // yellow (warning)
    break: 50,     // red (fail CI)
  },

  // Timeout config
  timeoutMS: 60_000,
  timeoutFactor: 1.5,

  // Parallel execution
  concurrency: 4,
  maxConcurrentTestRunners: 4,
};
```

---

## Stryker + Vitest

```bash
npm install --save-dev @stryker-mutator/core @stryker-mutator/vitest-runner
```

```javascript
// stryker.config.mjs
export default {
  testRunner: 'vitest',
  coverageAnalysis: 'perTest',
  vitest: {
    configFile: 'vitest.config.ts',
  },
  mutate: ['src/**/*.ts', '!src/**/*.{test,spec}.ts'],
  thresholds: { high: 80, low: 60, break: 50 },
};
```

---

## Mutator Configuration

```javascript
// stryker.config.mjs — selective mutators
export default {
  // ... base config ...

  mutator: {
    // Exclude specific mutator types (when too noisy)
    excludedMutations: [
      'StringLiteral',     // string changes often produce false survived
      'ObjectLiteral',     // object shape mutations in config files
    ],
  },

  // Focus on high-value mutations only
  // Available mutators:
  // ArithmeticOperator, ArrayDeclaration, ArrowFunction,
  // BlockStatement, BooleanLiteral, ConditionalExpression,
  // EqualityOperator, LogicalOperator, MethodExpression,
  // NoArgCall, OptionalChaining, RegexLiteral,
  // StringLiteral, UnaryOperator, UpdateOperator
};
```

**High-value mutators to focus on:**
- `ConditionalExpression` — catches boundary condition bugs
- `EqualityOperator` — `===` vs `!==`, `>` vs `>=`
- `LogicalOperator` — `&&` vs `||`
- `BooleanLiteral` — `true` vs `false`
- `BlockStatement` — empty function bodies

---

## Incremental Mode (Performance Optimization)

```javascript
// stryker.config.mjs
export default {
  // ... base config ...

  // Incremental: only re-run mutants affected by changed files
  incremental: true,
  incrementalFile: '.stryker-tmp/incremental.json',

  // Cache for faster reruns
  tempDirName: '.stryker-tmp',
  cleanTempDir: 'always',  // 'always' | 'never' | default
};
```

```bash
# First run (full)
npx stryker run

# Subsequent runs (incremental — much faster)
npx stryker run --incremental
```

---

## Interpreting Results — Survived Mutants

```typescript
// Example: survived mutant analysis
// Original code:
function isEligible(age: number): boolean {
  return age >= 18;  // Stryker mutates this to: age > 18
}

// If mutation to `age > 18` SURVIVES, your test is missing:
it('should return true for exactly 18', () => {
  expect(isEligible(18)).toBe(true);  // boundary condition
});

// Another example — LogicalOperator mutation:
function canAccess(is_admin: boolean, is_owner: boolean): boolean {
  return is_admin || is_owner;
  // Mutation: is_admin && is_owner — test both individual conditions!
}

// Tests needed:
it('grants access for admin non-owner', () => expect(canAccess(true, false)).toBe(true));
it('grants access for owner non-admin', () => expect(canAccess(false, true)).toBe(true));
it('denies access for non-admin non-owner', () => expect(canAccess(false, false)).toBe(false));
```

---

## Stryker Dashboard (CI Reporting)

```javascript
// stryker.config.mjs
export default {
  // ... base config ...
  reporters: ['html', 'clear-text', 'dashboard'],
  dashboard: {
    project: 'github.com/org/repo',
    version: process.env.GITHUB_REF_NAME || 'main',
    module: 'api',   // for monorepos
    baseUrl: 'https://dashboard.stryker-mutator.io',
    reportType: 'full',   // 'full' | 'mutationScore'
  },
};
```

---

## CI/CD Integration

```yaml
# .github/workflows/mutation-test.yml
name: Mutation Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  mutation-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # required for incremental mode

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Restore Stryker incremental cache
        uses: actions/cache@v4
        with:
          path: .stryker-tmp/incremental.json
          key: stryker-${{ github.ref }}-${{ hashFiles('src/**/*.ts') }}
          restore-keys: stryker-${{ github.ref }}-

      - name: Run mutation tests
        run: npx stryker run --incremental
        env:
          STRYKER_DASHBOARD_API_KEY: ${{ secrets.STRYKER_DASHBOARD_API_KEY }}

      - name: Upload HTML report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: mutation-report
          path: reports/mutation/
```

---

## Ignoring False Positives

```typescript
// Ignore specific mutations inline
function getDisplayName(user: User): string {
  // Stryker disable next-line StringLiteral
  return user.display_name || 'Anonymous';  // default string is not business logic
}

// Ignore entire block
/* Stryker disable all */
export const FEATURE_FLAGS = {
  new_dashboard: process.env.FEATURE_NEW_DASHBOARD === 'true',
};
/* Stryker enable all */
```

---

## Performance Tips

- Use `coverageAnalysis: 'perTest'` (default) — runs each mutant only against covering tests
- Enable `incremental` mode after first run — skips unchanged mutants
- Set `concurrency` to `Math.floor(cpus / 2)` — avoid thrashing
- Exclude generated/config files from `mutate` glob
- Run full mutation tests on main branch only; PRs use incremental

---

## Checklist

- [ ] `stryker.config.mjs` created with correct test runner
- [ ] `mutate` glob excludes generated files and barrel exports
- [ ] Thresholds set: `break` at 50, `low` at 60, `high` at 80
- [ ] `coverageAnalysis: 'perTest'` enabled
- [ ] Incremental mode configured with cache in CI
- [ ] Survived mutants reviewed and corresponding tests added
- [ ] HTML report artifact uploaded in CI for review

---

## References

- [Stryker docs](https://stryker-mutator.io/docs/)
- [Stryker configuration](https://stryker-mutator.io/docs/stryker-js/configuration/)
- [Mutation testing concepts](https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/)

---

## User Interaction (MANDATORY)

After reading this skill, Claude MUST:

1. **Ask for test runner**: Jest, Vitest, or Mocha?
2. **Ask about project size**: How many source files? Large projects need incremental mode
3. **Ask for current coverage**: Low coverage projects should fix coverage before mutation testing
4. **Ask about CI**: Does CI need to fail on low mutation score? What threshold?

Then generate complete `stryker.config.mjs`, explain how to read results, and suggest specific tests for common survived mutant patterns.
