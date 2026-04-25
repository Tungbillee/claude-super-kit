---
name: sk:visual-regression
description: "Visual regression testing: Percy (CI integration, snapshot management), Chromatic (Storybook native), Playwright visual testing, snapshot comparison strategies, failure triage workflow, baseline management."
argument-hint: "[tool: percy|chromatic|playwright] [--storybook] [--threshold N] [--ci]"
metadata:
  author: Claude Super Kit
  namespace: sk
  version: "1.0.0"
  last_updated: "2026-04-25"
  license: MIT
  category: testing
---

# sk:visual-regression — Visual Regression Testing

Catch unintended UI changes automatically using screenshot comparison across Percy, Chromatic, and Playwright.

## When to Use

- Before merging UI component changes
- Validating CSS/design system updates don't break pages
- Cross-browser visual consistency checks
- Storybook component visual review in PRs

## When NOT to Use

- Dynamic content that changes every render (charts with live data, timestamps)
- Testing business logic (use unit tests)
- Pages behind flaky auth flows

---

## Tool Comparison

| Feature | Percy | Chromatic | Playwright |
|---------|-------|-----------|------------|
| Storybook native | Partial | Yes (best) | Partial |
| Self-hosted | No | No | Yes |
| Cross-browser | Yes | Yes (via BrowserStack) | Yes |
| Free tier | 5k screenshots/mo | 5k snapshots/mo | Unlimited (self) |
| AI diff review | Yes | Yes | No |
| Setup complexity | Medium | Low | Low |

---

## Playwright Visual Testing (Self-hosted, Recommended Start)

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    // Screenshot settings
    screenshot: 'only-on-failure',
  },
  // Visual snapshot settings
  expect: {
    toHaveScreenshot: {
      maxDiffPixels: 50,          // allow minor anti-aliasing diffs
      maxDiffPixelRatio: 0.001,   // 0.1% of total pixels
      threshold: 0.2,             // per-pixel color tolerance
      animations: 'disabled',     // freeze CSS animations
    },
  },
  snapshotDir: 'tests/visual/snapshots',
  snapshotPathTemplate:
    '{snapshotDir}/{testFilePath}/{arg}-{projectName}{ext}',
});
```

```typescript
// tests/visual/components.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Visual regression — Homepage', () => {
  test.beforeEach(async ({ page }) => {
    // Freeze dynamic content
    await page.addInitScript(() => {
      // Mock Date to stabilize timestamps
      const FIXED_DATE = new Date('2024-01-15T12:00:00Z');
      Date.now = () => FIXED_DATE.getTime();
    });
  });

  test('hero section matches snapshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Hide dynamic elements before screenshot
    await page.evaluate(() => {
      document.querySelectorAll('[data-testid="live-counter"]')
        .forEach(el => (el as HTMLElement).style.visibility = 'hidden');
    });

    await expect(page.locator('.hero-section')).toHaveScreenshot(
      'hero-section.png',
      { fullPage: false }
    );
  });

  test('dark mode renders correctly', async ({ page }) => {
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.goto('/');
    await expect(page).toHaveScreenshot('homepage-dark.png', { fullPage: true });
  });

  test('mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto('/');
    await expect(page).toHaveScreenshot('homepage-mobile.png');
  });
});

// Component-level visual test
test('button variants', async ({ page }) => {
  await page.goto('/storybook/iframe.html?id=button--primary');
  await expect(page.locator('#storybook-root')).toHaveScreenshot('button-primary.png');
});
```

### Updating Snapshots

```bash
# First run — create baselines
npx playwright test --update-snapshots

# Run visual tests
npx playwright test tests/visual/

# Update specific snapshot
npx playwright test tests/visual/components.spec.ts --update-snapshots
```

---

## Percy Integration

```bash
npm install --save-dev @percy/cli @percy/playwright
```

```typescript
// tests/visual/percy.spec.ts
import { test } from '@playwright/test';
import percySnapshot from '@percy/playwright';

test('homepage percy snapshot', async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');

  await percySnapshot(page, 'Homepage', {
    widths: [375, 768, 1280],   // responsive snapshots
    minHeight: 600,
  });
});

test('product card states', async ({ page }) => {
  await page.goto('/products');

  await percySnapshot(page, 'Product Listing — Default');

  await page.hover('.product-card:first-child');
  await percySnapshot(page, 'Product Card — Hover State');
});
```

```yaml
# .github/workflows/visual-test.yml
name: Visual Tests

on: [pull_request]

jobs:
  percy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npx playwright install chromium

      - name: Start app
        run: npm run build && npm run preview &

      - name: Wait for app
        run: npx wait-on http://localhost:4173 --timeout 30000

      - name: Run Percy visual tests
        run: npx percy exec -- npx playwright test tests/visual/
        env:
          PERCY_TOKEN: ${{ secrets.PERCY_TOKEN }}
```

---

## Chromatic (Storybook Native)

```bash
npm install --save-dev chromatic
```

```yaml
# .github/workflows/chromatic.yml
name: Chromatic

on: [push]

jobs:
  chromatic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # required for TurboSnap (only changed stories)

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci

      - name: Publish to Chromatic
        uses: chromaui/action@latest
        with:
          projectToken: ${{ secrets.CHROMATIC_PROJECT_TOKEN }}
          buildScriptName: 'build-storybook'
          onlyChanged: true          # TurboSnap — only changed stories
          exitZeroOnChanges: false   # fail PR if visual changes found
          autoAcceptChanges: main    # auto-accept on main branch merges
```

### Storybook Story Best Practices for Visual Testing

```typescript
// src/components/Button/Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';

const meta: Meta<typeof Button> = {
  component: Button,
  // Disable animations for stable snapshots
  parameters: {
    chromatic: { delay: 300 },         // wait for animations
    backgrounds: {
      default: 'white',
      values: [
        { name: 'white', value: '#ffffff' },
        { name: 'dark', value: '#1a1a1a' },
      ],
    },
  },
};

export default meta;
type Story = StoryObj<typeof Button>;

export const AllVariants: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
      <Button variant="primary">Primary</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="danger">Danger</Button>
      <Button disabled>Disabled</Button>
      <Button loading>Loading</Button>
    </div>
  ),
  parameters: {
    chromatic: { viewports: [320, 768, 1200] },
  },
};
```

---

## Snapshot Management

### Baseline Strategy

```bash
# Workflow for updating baselines:
# 1. Developer makes intentional UI change
# 2. Review visual diff in Percy/Chromatic UI
# 3. Approve changes to update baseline
# 4. Merge PR — new baseline committed

# Playwright: baseline stored in git
git add tests/visual/snapshots/
git commit -m "chore: update visual regression baselines"

# Percy/Chromatic: baselines stored in cloud, approved via UI
```

### Excluding Flaky Elements

```typescript
// Mask dynamic regions before snapshot
await page.evaluate(() => {
  // Replace with stable placeholder
  document.querySelectorAll('.avatar-image').forEach(el => {
    (el as HTMLImageElement).src = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
  });
});

// Percy mask option
await percySnapshot(page, 'Dashboard', {
  percyCSS: `
    .live-chart { visibility: hidden; }
    .timestamp { opacity: 0; }
  `,
});
```

---

## Failure Triage Workflow

```
Visual regression failure detected
│
├── Is the change intentional?
│   ├── YES → Review in Percy/Chromatic UI → Approve → Merge
│   └── NO → Investigate
│
└── Investigate regression
    ├── Check git diff for CSS changes
    ├── Check if third-party library updated
    ├── Run test locally with --update-snapshots to see diff image
    └── Fix root cause → Re-run tests
```

```bash
# Debug failing visual test locally
npx playwright test tests/visual/ --headed --project=chromium

# View diff images
open test-results/  # contains actual/expected/diff images on failure
```

---

## Checklist

- [ ] Playwright snapshot config has `animations: 'disabled'`
- [ ] Dynamic content (timestamps, avatars, charts) masked/frozen
- [ ] Baselines generated for all critical pages/components
- [ ] Multiple viewports tested (mobile 375px, tablet 768px, desktop 1280px)
- [ ] Dark mode snapshots captured if supported
- [ ] CI blocks PR merge on visual regression failure
- [ ] Baseline update process documented in CONTRIBUTING.md

---

## References

- [Playwright visual comparisons](https://playwright.dev/docs/screenshots)
- [Percy docs](https://docs.percy.io/)
- [Chromatic docs](https://www.chromatic.com/docs/)
- [Storybook visual testing](https://storybook.js.org/docs/writing-tests/visual-testing)

---

## User Interaction (MANDATORY)

After reading this skill, Claude MUST:

1. **Ask for tool preference**: Playwright (self-hosted, free), Percy (cloud), or Chromatic (Storybook)?
2. **Ask about Storybook**: Already using Storybook? Chromatic becomes the obvious choice
3. **Ask about viewport coverage**: Which screen sizes matter? Mobile? Tablet?
4. **Ask about dynamic content**: What elements change on every render that need masking?

Then generate complete visual test setup with config, example specs, snapshot masking for dynamic content, and CI workflow.
