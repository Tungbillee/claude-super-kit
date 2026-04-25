---
name: sk:ui-ux-pro-max
description: "UI/UX design intelligence for web and mobile. Includes 50+ styles, 161 color palettes, 57 font pairings, 161 product types, 99 UX guidelines, and 25 chart types across 10 stacks (React, Next.js, Vue, Svelte, SwiftUI, React Native, Flutter, Tailwind, shadcn/ui, and HTML/CSS). Actions: plan, build, create, design, implement, review, fix, improve, optimize, enhance, refactor, and check UI/UX code. Projects: website, landing page, dashboard, admin panel, e-commerce, SaaS, portfolio, blog, and mobile app. Elements: button, modal, navbar, sidebar, card, table, form, and chart. Styles: glassmorphism, claymorphism, minimalism, brutalism, neumorphism, bento grid, dark mode, responsive, skeuomorphism, and flat design. Topics: color systems, accessibility, animation, layout, typography, font pairing, spacing, interaction states, shadow, and gradient. Integrations: shadcn/ui MCP for component search and examples."
metadata:
  author: claudekit
  version: "1.1.0"
  last_updated: "2026-04-25"
---

# UI/UX Pro Max - Design Intelligence

Comprehensive design guide for web and mobile applications. Contains 50+ styles, 161 color palettes, 57 font pairings, 161 product types with reasoning rules, 99 UX guidelines, and 25 chart types across 10 technology stacks.

## When to Apply

### Must Use
- Designing new pages (Landing Page, Dashboard, Admin, SaaS, Mobile App)
- Creating or refactoring UI components (buttons, modals, forms, tables, charts)
- Choosing color schemes, typography systems, spacing standards, or layout systems
- Reviewing UI code for user experience, accessibility, or visual consistency
- Implementing navigation structures, animations, or responsive behavior
- Making product-level design decisions (style, information hierarchy, brand expression)

### Recommended
- UI looks "not professional enough" but the reason is unclear
- Receiving feedback on usability or experience
- Pre-launch UI quality optimization
- Aligning cross-platform design (Web / iOS / Android)

### Skip
- Pure backend logic, API/database design, infrastructure, DevOps, non-visual scripts

**Decision criteria**: If the task changes how a feature **looks, feels, moves, or is interacted with**, use this skill.

## Rule Categories by Priority

| Priority | Category | Impact | Domain | Key Checks (Must Have) | Anti-Patterns (Avoid) |
|----------|----------|--------|--------|------------------------|------------------------|
| 1 | Accessibility | CRITICAL | `ux` | Contrast 4.5:1, Alt text, Keyboard nav, Aria-labels | Removing focus rings, Icon-only buttons without labels |
| 2 | Touch & Interaction | CRITICAL | `ux` | Min size 44×44px, 8px+ spacing, Loading feedback | Reliance on hover only, Instant state changes (0ms) |
| 3 | Performance | HIGH | `ux` | WebP/AVIF, Lazy loading, Reserve space (CLS < 0.1) | Layout thrashing, Cumulative Layout Shift |
| 4 | Style Selection | HIGH | `style`, `product` | Match product type, Consistency, SVG icons (no emoji) | Mixing flat & skeuomorphic randomly, Emoji as icons |
| 5 | Layout & Responsive | HIGH | `ux` | Mobile-first breakpoints, Viewport meta, No horizontal scroll | Horizontal scroll, Fixed px container widths, Disable zoom |
| 6 | Typography & Color | MEDIUM | `typography`, `color` | Base 16px, Line-height 1.5, Semantic color tokens | Text < 12px body, Gray-on-gray, Raw hex in components |
| 7 | Animation | MEDIUM | `ux` | Duration 150–300ms, Motion conveys meaning, Spatial continuity | Decorative-only animation, Animating width/height, No reduced-motion |
| 8 | Forms & Feedback | MEDIUM | `ux` | Visible labels, Error near field, Helper text, Progressive disclosure | Placeholder-only label, Errors only at top, Overwhelm upfront |
| 9 | Navigation Patterns | HIGH | `ux` | Predictable back, Bottom nav ≤5, Deep linking | Overloaded nav, Broken back behavior, No deep links |
| 10 | Charts & Data | LOW | `chart` | Legends, Tooltips, Accessible colors | Relying on color alone to convey meaning |

## Quick Reference

### 1. Accessibility (CRITICAL)
- `color-contrast` - Minimum 4.5:1 ratio for normal text (large text 3:1)
- `focus-states` - Visible focus rings on interactive elements (2–4px)
- `alt-text` - Descriptive alt text for meaningful images
- `aria-labels` - aria-label for icon-only buttons; accessibilityLabel in native
- `keyboard-nav` - Tab order matches visual order; full keyboard support
- `form-labels` - Use label with for attribute
- `skip-links` - Skip to main content for keyboard users
- `heading-hierarchy` - Sequential h1→h6, no level skip
- `color-not-only` - Don't convey info by color alone (add icon/text)
- `dynamic-type` - Support system text scaling; avoid truncation as text grows
- `reduced-motion` - Respect prefers-reduced-motion; reduce/disable animations
- `voiceover-sr` - Meaningful accessibilityLabel/accessibilityHint; logical reading order
- `escape-routes` - Provide cancel/back in modals and multi-step flows
- `keyboard-shortcuts` - Preserve system and a11y shortcuts; offer keyboard alternatives

### 2. Touch & Interaction (CRITICAL)
- `touch-target-size` - Min 44×44pt (Apple) / 48×48dp (Material)
- `touch-spacing` - Minimum 8px/8dp gap between touch targets
- `hover-vs-tap` - Use click/tap for primary interactions; don't rely on hover alone
- `loading-buttons` - Disable button during async operations; show spinner or progress
- `error-feedback` - Clear error messages near problem
- `gesture-conflicts` - Avoid horizontal swipe on main content; prefer vertical scroll
- `tap-delay` - Use touch-action: manipulation to reduce 300ms delay
- `standard-gestures` - Use platform standard gestures consistently
- `press-feedback` - Visual feedback on press (ripple/highlight)
- `haptic-feedback` - Use haptic for confirmations; avoid overuse
- `safe-area-awareness` - Keep primary touch targets away from notch, Dynamic Island, gesture bar

### 3. Performance (HIGH)
- `image-optimization` - Use WebP/AVIF, responsive images (srcset/sizes), lazy load
- `image-dimension` - Declare width/height or use aspect-ratio to prevent layout shift
- `font-loading` - Use font-display: swap/optional; reserve space to reduce layout shift
- `critical-css` - Prioritize above-the-fold CSS
- `lazy-loading` - Lazy load non-hero components via dynamic import
- `bundle-splitting` - Split code by route/feature to reduce initial load and TTI
- `virtualize-lists` - Virtualize lists with 50+ items
- `main-thread-budget` - Keep per-frame work under ~16ms for 60fps
- `progressive-loading` - Use skeleton screens instead of long blocking spinners >1s
- `debounce-throttle` - Use debounce/throttle for high-frequency events

### 4. Style Selection (HIGH)
- `style-match` - Match style to product type
- `consistency` - Use same style across all pages
- `no-emoji-icons` - Use SVG icons (Heroicons, Lucide), not emojis
- `color-palette-from-product` - Choose palette from product/industry
- `platform-adaptive` - Respect platform idioms (iOS HIG vs Material)
- `elevation-consistent` - Use a consistent elevation/shadow scale
- `dark-mode-pairing` - Design light/dark variants together
- `primary-action` - Each screen has only one primary CTA

### 5. Layout & Responsive (HIGH)
- `viewport-meta` - width=device-width initial-scale=1 (never disable zoom)
- `mobile-first` - Design mobile-first, then scale up
- `breakpoint-consistency` - Use systematic breakpoints (375 / 768 / 1024 / 1440)
- `readable-font-size` - Minimum 16px body text on mobile
- `horizontal-scroll` - No horizontal scroll on mobile
- `spacing-scale` - Use 4pt/8dp incremental spacing system
- `container-width` - Consistent max-width on desktop (max-w-6xl / 7xl)
- `viewport-units` - Prefer min-h-dvh over 100vh on mobile

### 6. Typography & Color (MEDIUM)
- `line-height` - Use 1.5-1.75 for body text
- `line-length` - Limit to 65-75 characters per line
- `font-pairing` - Match heading/body font personalities
- `font-scale` - Consistent type scale (e.g. 12 14 16 18 24 32)
- `color-semantic` - Define semantic color tokens (primary, secondary, error, surface)
- `color-dark-mode` - Dark mode uses desaturated/lighter tonal variants, not inverted
- `color-accessible-pairs` - Foreground/background pairs must meet 4.5:1 (AA)
- `truncation-strategy` - Prefer wrapping over truncation
- `number-tabular` - Use tabular/monospaced figures for data columns, prices, timers

### 7. Animation (MEDIUM)
- `duration-timing` - Use 150–300ms for micro-interactions; complex ≤400ms
- `transform-performance` - Use transform/opacity only; avoid animating width/height
- `easing` - Use ease-out for entering, ease-in for exiting
- `motion-meaning` - Every animation must express cause-effect, not be decorative
- `spring-physics` - Prefer spring/physics-based curves for natural feel
- `exit-faster-than-enter` - Exit animations ~60–70% of enter duration
- `interruptible` - Animations must be interruptible by user tap/gesture
- `no-blocking-animation` - Never block user input during an animation

### 8. Forms & Feedback (MEDIUM)
- `input-labels` - Visible label per input (not placeholder-only)
- `error-placement` - Show error below the related field
- `submit-feedback` - Loading then success/error state on submit
- `inline-validation` - Validate on blur; show error only after user finishes input
- `input-type-keyboard` - Use semantic input types to trigger correct mobile keyboard
- `progressive-disclosure` - Reveal complex options progressively
- `undo-support` - Allow undo for destructive or bulk actions
- `error-clarity` - Error messages must state cause + how to fix
- `focus-management` - After submit error, auto-focus the first invalid field

### 9. Navigation Patterns (HIGH)
- `bottom-nav-limit` - Bottom navigation max 5 items; use labels with icons
- `back-behavior` - Back navigation must be predictable and preserve scroll/state
- `deep-linking` - All key screens reachable via deep link / URL
- `nav-label-icon` - Navigation items must have both icon and text label
- `modal-escape` - Modals must offer clear close/dismiss affordance
- `state-preservation` - Navigating back must restore previous scroll and filter state
- `adaptive-navigation` - Large screens (≥1024px) prefer sidebar; small screens use bottom nav
- `focus-on-route-change` - After page transition, move focus to main content region

### 10. Charts & Data (LOW)
- `chart-type` - Match chart type to data type (trend→line, comparison→bar, proportion→pie)
- `color-guidance` - Use accessible color palettes; avoid red/green only pairs
- `data-table` - Provide table alternative for accessibility
- `legend-visible` - Always show legend near the chart
- `tooltip-on-interact` - Provide tooltips/data labels on hover (Web) or tap (mobile)
- `responsive-chart` - Charts must reflow on small screens
- `no-pie-overuse` - Avoid pie/donut for >5 categories; switch to bar chart

## How to Use This Skill

| Scenario | Trigger Examples | Start From |
|----------|-----------------|------------|
| **New project / page** | "Build a landing page", "Build a dashboard" | Step 1 → Step 2 (design system) |
| **New component** | "Create a pricing card", "Add a modal" | Step 3 (domain search: style, ux) |
| **Choose style / color / font** | "What style fits a fintech app?" | Step 2 (design system) |
| **Review existing UI** | "Review this page for UX issues" | Quick Reference checklist above |
| **Fix a UI bug** | "Button hover is broken" | Quick Reference → relevant section |
| **Add charts / data viz** | "Add an analytics dashboard chart" | Step 3 (domain: chart) |

### Step 1: Analyze User Requirements
Extract: **Product type**, **Target audience**, **Style keywords**, **Stack** (React Native).

### Step 2: Generate Design System (REQUIRED)

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<product_type> <industry> <keywords>" --design-system [-p "Project Name"]
```

Add `--persist` to save as `design-system/MASTER.md` + `design-system/pages/<page>.md` for hierarchical retrieval across sessions.

### Step 3: Supplement with Detailed Searches

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<keyword>" --domain <domain> [-n <max_results>]
```

| Need | Domain | Need | Domain |
|------|--------|------|--------|
| Product patterns | `product` | Font pairings | `typography` |
| Style options | `style` | Charts | `chart` |
| Color palettes | `color` | UX best practices | `ux` |
| Individual Google Fonts | `google-fonts` | React Native perf | `react` |
| Landing structure | `landing` | App interface a11y | `web` |

### Step 4: Stack Guidelines (React Native)

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<keyword>" --stack react-native
```

> See [examples-detailed.md](references/examples-detailed.md) for full worked example, output formats, and tips.
> See [patterns-advanced.md](references/patterns-advanced.md) for detailed icon, interaction, dark mode, and layout rules.

## Pre-Delivery Checklist

Scope: App UI (iOS/Android/React Native/Flutter).

### Visual Quality
- [ ] No emojis used as icons (use SVG instead)
- [ ] All icons from a consistent icon family and style
- [ ] Official brand assets used with correct proportions
- [ ] Pressed-state visuals do not shift layout bounds
- [ ] Semantic theme tokens used consistently (no ad-hoc hardcoded colors)

### Interaction
- [ ] All tappable elements provide clear pressed feedback (ripple/opacity/elevation)
- [ ] Touch targets meet minimum size (>=44x44pt iOS, >=48x48dp Android)
- [ ] Micro-interaction timing stays in 150-300ms range
- [ ] Disabled states are visually clear and non-interactive
- [ ] Screen reader focus order matches visual order

### Light/Dark Mode
- [ ] Primary text contrast >=4.5:1 in both light and dark mode
- [ ] Secondary text contrast >=3:1 in both modes
- [ ] Dividers/borders distinguishable in both modes
- [ ] Modal scrim opacity 40-60% black in both modes

### Layout
- [ ] Safe areas respected for headers, tab bars, bottom CTA bars
- [ ] Scroll content not hidden behind fixed/sticky bars
- [ ] Verified on small phone, large phone, and tablet (portrait + landscape)
- [ ] 4/8dp spacing rhythm maintained

### Accessibility
- [ ] All meaningful images/icons have accessibility labels
- [ ] Form fields have labels, hints, and clear error messages
- [ ] Color is not the only indicator
- [ ] Reduced motion and dynamic text size supported

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).

**Rules:**
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts like "Please answer: 1) X? 2) Y?"
- Each question: 2-4 predefined options + auto "Something else"
- Exception: genuine free-form inputs (file paths, custom names, code snippets)

See rule for full specification.
