---
name: sk:code-reuse-checker
description: "YAGNI enforcement — scan codebase for similar functions/patterns before implementing, require justification for new code"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: dx-tools
last_updated: 2026-04-25
license: MIT
---

# sk:code-reuse-checker — Code Reuse Enforcement

## Purpose

Prevent duplicated logic by scanning the codebase **before** any new implementation. Enforces YAGNI/DRY principles at the point of request.

## When to Activate

- User asks to implement a new function/utility/component
- User asks to "add X" or "create Y"
- During code review when reviewing new files
- Before writing any utility, hook, composable, service, or helper

## Workflow

```
User: "Implement a function to format currency"
          │
          ▼
1. SCAN — grep/search codebase for similar patterns
          │
          ▼
2. ANALYZE — categorize findings:
   (a) Exact match → point to existing, NO new code
   (b) Partial match → suggest refactor/extend
   (c) No match → proceed, but check libraries first
          │
          ▼
3. REPORT — present findings with file:line refs
          │
          ▼
4. DECIDE — require explicit justification for "write new"
```

## Scan Strategy

### Step 1 — Keyword Extraction

From user request, extract:
- **Function concept**: "format currency" → `format`, `currency`, `money`, `price`
- **Data type**: string, number, date, array, object
- **Pattern type**: util, hook, composable, component, service, middleware

### Step 2 — Grep Search Patterns

```bash
# Search by concept keywords (case-insensitive)
grep -r --include="*.ts" --include="*.js" --include="*.vue" \
  -l "formatCurrency\|format_currency\|formatMoney\|format_price" .

# Search by function signature pattern
grep -rn "function.*format.*\(.*number\|amount\|price\|money" \
  --include="*.ts" --include="*.js" .

# Search for similar logic (Intl.NumberFormat = currency formatting)
grep -rn "Intl\.NumberFormat\|toLocaleString.*currency\|\.toFixed.*currency" \
  --include="*.ts" --include="*.js" .

# Search composables/hooks
grep -rn "^export.*use[A-Z]\|^export function use" \
  --include="*.ts" src/composables/ src/hooks/ .

# Search utils directories
find . -path "*/utils/*" -name "*.ts" | xargs grep -l "format\|currency"
```

### Step 3 — Semantic Analysis

For each match, evaluate:

| Signal | Meaning |
|--------|---------|
| Same input/output shape | Strong reuse candidate |
| Same domain (finance, date, string) | Likely reuse with minor tweak |
| Different abstraction level | May need wrapper, not new impl |
| Different framework context | May need adapter |
| Significantly different scope | New impl justified |

## Decision Tree

```
Found exact match?
├── YES → Use existing. Show: file path, function name, usage example
│
├── PARTIAL (70–90% similar)?
│   ├── Extend with optional param → suggest PR to existing file
│   ├── Extract shared core → suggest refactor plan
│   └── Wrap existing → show wrapper pattern
│
└── NO match in codebase?
    ├── Check standard library / built-ins first
    ├── Check installed packages (package.json / go.mod)
    └── Only then → authorize new implementation
```

## Output Format

### Case A: Exact Match Found

```
REUSE CANDIDATE FOUND

Existing: src/utils/format.ts:34
Function: formatCurrency(amount: number, currency = 'VND'): string
Usage:    import { formatCurrency } from '@/utils/format'

No new code needed. Use existing function.
```

### Case B: Partial Match — Suggest Extension

```
PARTIAL MATCH FOUND

Existing: src/utils/format.ts:34
Current:  formatCurrency(amount: number) — hardcoded VND
Request:  needs multi-currency support

RECOMMENDED: Extend existing function (add `currency` param with default)
instead of creating new formatMultiCurrency().

Diff suggestion:
- formatCurrency(amount: number): string
+ formatCurrency(amount: number, currency = 'VND'): string
```

### Case C: No Match — Proceed with Checks

```
NO EXISTING MATCH

Searched: src/**/*.ts, src/**/*.vue
Keywords: format, currency, money, price, Intl.NumberFormat

Library check:
✓ No lodash/dayjs/etc equivalent found in package.json
✓ Native Intl.NumberFormat available (no dep needed)

AUTHORIZED: Proceed with new implementation.
Recommended location: src/utils/format-currency.ts
Export as: formatCurrency (camelCase per coding standards)
```

## Justification Requirement

When user wants "write new" despite existing match:

```javascript
AskUserQuestion({
  questions: [{
    question: "Existing similar function found. Why write new?",
    header: "Justification",
    options: [
      { label: "Different behavior", description: "Existing doesn't fit my use case" },
      { label: "Different scope", description: "Too broad/narrow to reuse" },
      { label: "Will refactor later", description: "Tech debt acknowledged" },
      { label: "Replace existing", description: "New version supersedes old" }
    ]
  }]
})
```

If "Will refactor later" → create `// TODO(reuse): consolidate with src/utils/format.ts:34`

## Anti-Patterns Caught

| Pattern | Detection | Action |
|---------|----------|--------|
| Duplicate util functions | grep same name variants | Point to existing |
| Parallel composables | grep `use` + concept | Suggest merge |
| Copied component logic | grep component props signature | Extract shared composable |
| Repeated API call wrappers | grep endpoint strings | Centralize in service |
| Duplicated type definitions | grep interface/type names | Move to shared types |

## Integration Points

- Run **before** any `/sk:cook` implementation task
- Run **during** `/sk:code-review` as DRY check
- Run **before** creating new files in `utils/`, `hooks/`, `composables/`

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "What are you about to implement?",
      header: "Task Type",
      options: [
        { label: "Utility function", description: "format, parse, validate, etc." },
        { label: "Component / UI", description: "Vue/React component" },
        { label: "Composable / Hook", description: "useXxx shared logic" },
        { label: "Service / API", description: "API wrapper, data service" }
      ]
    },
    {
      question: "Scan scope?",
      header: "Scope",
      options: [
        { label: "Current module", description: "Same feature folder" },
        { label: "Whole src/", description: "Full source tree" },
        { label: "utils + composables", description: "Shared code locations only" }
      ]
    }
  ]
})
```
