---
name: sk:a11y-testing
description: "Accessibility testing: axe-core integration (Jest/Cypress/Playwright), WCAG 2.1 AA criteria, Lighthouse a11y audits, screen reader testing (VoiceOver/NVDA), color contrast tools, ARIA patterns. Covers automated + manual testing."
argument-hint: "[framework: jest|cypress|playwright] [--wcag AA|AAA] [--lighthouse] [--aria]"
metadata:
  author: Claude Super Kit
  namespace: sk
  version: "1.0.0"
  last_updated: "2026-04-25"
  license: MIT
  category: testing
---

# sk:a11y-testing — Accessibility Testing

Implement automated and manual accessibility testing to meet WCAG 2.1 AA compliance.

## When to Use

- Before releasing user-facing features
- Auditing existing components for compliance
- Setting up a11y gates in CI/CD
- Screen reader and keyboard navigation validation

---

## WCAG 2.1 AA Key Criteria

| Criterion | Level | Requirement |
|-----------|-------|-------------|
| 1.1.1 Non-text content | A | Alt text for images |
| 1.3.1 Info & relationships | A | Semantic HTML, labels |
| 1.4.3 Contrast (minimum) | AA | 4.5:1 normal text, 3:1 large text |
| 1.4.11 Non-text contrast | AA | 3:1 for UI components |
| 2.1.1 Keyboard | A | All functionality via keyboard |
| 2.4.3 Focus order | A | Logical focus sequence |
| 2.4.7 Focus visible | AA | Visible focus indicator |
| 3.1.1 Language of page | A | `lang` attribute on `<html>` |
| 4.1.2 Name, role, value | A | ARIA labels, roles, states |

---

## axe-core + Jest (Component Testing)

```bash
npm install --save-dev @axe-core/react jest-axe
```

```typescript
// tests/a11y/setup.ts
import { configureAxe } from 'jest-axe';
import '@testing-library/jest-dom';

// Global axe config
export const axe = configureAxe({
  rules: {
    // Disable rules not applicable to component-level tests
    'region': { enabled: false },         // page regions (test at page level)
    'landmark-one-main': { enabled: false },
  },
  // Target WCAG 2.1 AA
  runOnly: {
    type: 'tag',
    values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'best-practice'],
  },
});
```

```typescript
// tests/a11y/button.test.tsx
import { render } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import { Button } from '../../src/components/Button';

expect.extend(toHaveNoViolations);

describe('Button accessibility', () => {
  it('has no axe violations', async () => {
    const { container } = render(
      <Button onClick={() => {}} aria-label="Save document">Save</Button>
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('is keyboard accessible', async () => {
    const handle_click = jest.fn();
    const { getByRole } = render(<Button onClick={handle_click}>Submit</Button>);

    const button = getByRole('button', { name: 'Submit' });
    button.focus();
    expect(button).toHaveFocus();

    fireEvent.keyDown(button, { key: 'Enter' });
    expect(handle_click).toHaveBeenCalled();
  });

  it('disabled state has correct ARIA', () => {
    const { getByRole } = render(<Button disabled>Submit</Button>);
    expect(getByRole('button')).toHaveAttribute('aria-disabled', 'true');
  });
});
```

---

## axe-core + Cypress

```bash
npm install --save-dev cypress-axe axe-core
```

```typescript
// cypress/support/e2e.ts
import 'cypress-axe';

// Custom command to check a11y and log violations
Cypress.Commands.add('checkA11y', (context, options) => {
  cy.checkA11y(context, options, (violations) => {
    violations.forEach((v) => {
      Cypress.log({
        name: 'A11y violation',
        message: `${v.id}: ${v.description}`,
        consoleProps: () => ({
          id: v.id,
          description: v.description,
          impact: v.impact,
          nodes: v.nodes.length,
          help: v.helpUrl,
        }),
      });
    });
  });
});
```

```typescript
// cypress/e2e/a11y.cy.ts
describe('Page accessibility', () => {
  it('login page has no violations', () => {
    cy.visit('/login');
    cy.injectAxe();
    cy.checkA11y(undefined, {
      runOnly: { type: 'tag', values: ['wcag2aa', 'wcag21aa'] },
      includedImpacts: ['critical', 'serious'],
    });
  });

  it('modal dialog is accessible', () => {
    cy.get('[data-testid="open-modal"]').click();
    cy.get('[role="dialog"]').should('be.visible');
    cy.injectAxe();
    cy.checkA11y('[role="dialog"]');

    // Focus should be trapped in modal
    cy.focused().should('be.within', '[role="dialog"]');
  });
});
```

---

## axe-core + Playwright

```typescript
// tests/a11y/playwright-a11y.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Dashboard a11y', () => {
  test('has no WCAG 2.1 AA violations', async ({ page }) => {
    await page.goto('/dashboard');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .exclude('#third-party-widget')   // exclude widgets you don't control
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('data table is accessible', async ({ page }) => {
    await page.goto('/reports');
    await page.waitForSelector('table');

    const results = await new AxeBuilder({ page })
      .include('table')
      .analyze();

    // Log violations with details
    if (results.violations.length > 0) {
      console.table(results.violations.map(v => ({
        id: v.id, impact: v.impact, count: v.nodes.length,
      })));
    }

    expect(results.violations).toHaveLength(0);
  });
});
```

---

## ARIA Patterns

```tsx
// Modal dialog with focus management
function Modal({ is_open, on_close, title, children }: ModalProps) {
  const modal_ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (is_open) {
      // Save previously focused element
      const previous_focus = document.activeElement as HTMLElement;
      // Focus first focusable element
      modal_ref.current?.querySelector<HTMLElement>(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      )?.focus();

      return () => previous_focus?.focus();  // restore on close
    }
  }, [is_open]);

  if (!is_open) return null;

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
      aria-describedby="modal-desc"
      ref={modal_ref}
      onKeyDown={(e) => e.key === 'Escape' && on_close()}
    >
      <h2 id="modal-title">{title}</h2>
      <div id="modal-desc">{children}</div>
      <button onClick={on_close} aria-label="Close dialog">×</button>
    </div>
  );
}

// Form with accessible labels
function LoginForm() {
  const [errors, set_errors] = useState<Record<string, string>>({});

  return (
    <form noValidate aria-label="Login form">
      <div>
        <label htmlFor="email">
          Email address
          <span aria-hidden="true"> *</span>
        </label>
        <input
          id="email"
          type="email"
          required
          aria-required="true"
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? 'email-error' : undefined}
          autoComplete="email"
        />
        {errors.email && (
          <p id="email-error" role="alert" aria-live="polite">
            {errors.email}
          </p>
        )}
      </div>
    </form>
  );
}
```

---

## Color Contrast Checking

```typescript
// src/utils/color-contrast.ts
// WCAG contrast ratio calculation
function getLuminance(r: number, g: number, b: number): number {
  const [rs, gs, bs] = [r, g, b].map((c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
}

export function getContrastRatio(hex1: string, hex2: string): number {
  const toRgb = (hex: string) => {
    const n = parseInt(hex.replace('#', ''), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255] as const;
  };

  const l1 = getLuminance(...toRgb(hex1));
  const l2 = getLuminance(...toRgb(hex2));
  const [light, dark] = l1 > l2 ? [l1, l2] : [l2, l1];

  return (light + 0.05) / (dark + 0.05);
}

// WCAG thresholds
export function meetsWCAG(
  hex_foreground: string,
  hex_background: string,
  level: 'AA' | 'AAA' = 'AA',
  is_large_text = false,
): boolean {
  const ratio = getContrastRatio(hex_foreground, hex_background);
  if (level === 'AAA') return ratio >= (is_large_text ? 4.5 : 7);
  return ratio >= (is_large_text ? 3 : 4.5);
}
```

---

## Lighthouse A11y Audit (CLI)

```bash
# Single page audit
npx lighthouse https://myapp.com/login \
  --only-categories=accessibility \
  --output=json \
  --output-path=./reports/a11y-report.json

# CI integration
npx lhci autorun --collect.url=http://localhost:3000 \
  --assert.preset=lighthouse:recommended \
  --assert.assertions.'categories:accessibility'.minScore=0.9
```

---

## Screen Reader Testing Checklist

**VoiceOver (macOS):** `Cmd + F5` to activate
- Tab through all interactive elements — verify announced name/role/state
- Use `VO + Right` to read content linearly
- Check landmarks: `VO + U` opens rotor

**NVDA (Windows):** Free at nvaccess.org
- `NVDA + Space` to enter/exit browse mode
- `H` key navigates headings — verify heading hierarchy
- `F` key navigates form fields — verify all labels announced

**Manual a11y checklist:**
- [ ] All images have meaningful alt text (or `alt=""` if decorative)
- [ ] Heading hierarchy: single `<h1>`, logical `h2`→`h3` structure
- [ ] All form inputs have visible, programmatic labels
- [ ] Error messages announced via `aria-live="polite"`
- [ ] Modal dialogs trap focus and restore on close
- [ ] Skip navigation link at page top
- [ ] No content accessible only via hover/color

---

## Checklist

- [ ] `jest-axe` or `@axe-core/playwright` added to test suite
- [ ] axe configured with `wcag2aa` and `wcag21aa` tags
- [ ] All new components have a11y unit test
- [ ] Color contrast verified against 4.5:1 for normal text
- [ ] Keyboard navigation tested for all interactive elements
- [ ] ARIA roles/labels/states correct on custom components
- [ ] Lighthouse a11y score ≥ 90 in CI

---

## References

- [axe-core rules](https://dequeuniversity.com/rules/axe/)
- [WCAG 2.1 quick reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [ARIA authoring practices](https://www.w3.org/WAI/ARIA/apg/)
- [Playwright axe](https://playwright.dev/docs/accessibility-testing)

---

## User Interaction (MANDATORY)

After reading this skill, Claude MUST:

1. **Ask for test framework**: Jest + RTL, Cypress, or Playwright?
2. **Ask about compliance level**: WCAG 2.1 AA (standard) or AAA (strict)?
3. **Ask about component types**: Forms, modals, data tables, navigation? (to provide relevant ARIA patterns)
4. **Ask about CI**: Should a11y failures block the pipeline?

Then generate complete axe setup with config, example tests for the components mentioned, and CI integration snippet.
