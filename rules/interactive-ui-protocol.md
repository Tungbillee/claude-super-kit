# Interactive UI Protocol (MANDATORY)

**Version:** 1.0.0
**Applies to:** ALL skills in Claude Super Kit (every `/sk:*` command)
**Status:** Enforced

---

## Core Rule

When ANY skill needs user input for clarification, choices, or decisions, it **MUST** use the `AskUserQuestion` tool — NOT free-text prompts.

---

## Why This Rule Exists

1. **Speed** — User navigates with arrow keys + Enter, no typing required
2. **Accuracy** — Predefined options eliminate typos and ambiguity
3. **UX** — Clean, professional interface (checkbox/radio UI)
4. **Consistency** — All skills behave identically
5. **LLM reliability** — Structured input → fewer parsing errors

---

## Format Requirements

### Question Structure

- **1-4 questions** per `AskUserQuestion` call
- Each question: **2-4 predefined options**
- **Header**: max 12 characters (displayed as chip/tag)
- **Options**: concrete, mutually exclusive, clear
- Auto-included: "Something else" option (user can input free text)

### Standard Option Sets (Templates)

| Category | Options |
|---|---|
| **Priority** | `[Low, Medium, High, Critical]` |
| **Time budget** | `[Quick (<1h), Normal (1 day), Deep (1 week)]` |
| **Scope** | `[Single file, Module, Project, Full repo]` |
| **Environment** | `[Dev, Staging, Production]` |
| **Depth** | `[Surface, Standard, Deep dive]` |
| **Yes/No** | `[Yes, No]` + description with reasoning |
| **Confirmation** | `[Proceed, Modify, Cancel]` |

### Dynamic Options

Extract from project context:
- **Framework options** → read `package.json`, `go.mod`, `Cargo.toml`
- **File options** → scan directory
- **Branch options** → `git branch --list`
- **Database options** → read config files

---

## Exceptions (Free-Form Input Allowed)

Only these cases allow plain text input:

1. **File paths** — User must type specific path
2. **Custom names** — Project name, variable name, branch name
3. **Custom URLs/endpoints** — External service URLs
4. **Code snippets** — User pasting code to analyze
5. **Long-form descriptions** — Feature spec, bug description

Even in exceptions: use `AskUserQuestion` first with option "Type custom value" → then prompt for input.

---

## Examples

### ❌ BAD (Free-Text Prompts)

```
"Please provide the following:
1. What framework are you using?
2. What database?
3. What auth method?
4. What deployment target?"
```

Problems:
- User must type 4 answers
- Typos possible (e.g., "Postgres" vs "PostgreSQL")
- No auto-complete, no validation
- Parser must handle free text

### ✅ GOOD (AskUserQuestion)

```javascript
AskUserQuestion({
  questions: [
    {
      question: "Which framework?",
      header: "Framework",
      options: [
        { label: "Next.js", description: "React SSR/SSG" },
        { label: "Nuxt", description: "Vue SSR/SSG" },
        { label: "SvelteKit", description: "Svelte full-stack" },
        { label: "Astro", description: "Islands architecture" }
      ]
    },
    {
      question: "Which database?",
      header: "Database",
      options: [
        { label: "PostgreSQL", description: "Relational, ACID" },
        { label: "MongoDB", description: "Document store" },
        { label: "Firebase", description: "Real-time NoSQL" }
      ]
    },
    {
      question: "Auth method?",
      header: "Auth",
      options: [
        { label: "Email + password", description: "Classic" },
        { label: "OAuth (Google/GitHub)", description: "Social login" },
        { label: "Passkey/WebAuthn", description: "Passwordless" }
      ]
    },
    {
      question: "Deploy target?",
      header: "Deploy",
      options: [
        { label: "Vercel", description: "Zero-config" },
        { label: "Cloudflare Pages", description: "Edge-first" },
        { label: "Docker/K8s", description: "Self-hosted" }
      ]
    }
  ]
})
```

Benefits:
- Zero typing
- Clear mutually-exclusive choices
- Descriptions explain trade-offs
- User navigates keyboard: ↑↓ Enter

---

## Implementation Checklist

When building/updating a skill:

- [ ] Audit SKILL.md for free-text question prompts
- [ ] Replace with `AskUserQuestion` calls
- [ ] Group related questions (max 4 per call)
- [ ] Write clear, 1-sentence questions
- [ ] Provide 2-4 concrete options with descriptions
- [ ] Set `header` ≤ 12 chars
- [ ] Test: user can complete flow without typing (except genuine free-form cases)

---

## Multi-Select (Checkbox) vs Single-Select (Radio)

Default: **single-select** (radio buttons).

Use `multiSelect: true` when:
- Features are non-exclusive (e.g., "Which testing types to enable?")
- Components to include (e.g., "Which shadcn/ui components?")
- Languages to support (e.g., "Which locales?")

---

## Anti-Patterns to Avoid

| Anti-Pattern | Fix |
|---|---|
| "Tell me more about your project" | AskUserQuestion: project type options |
| "What do you want to do?" | AskUserQuestion: action options |
| Numbered list in prose ("1. X, 2. Y") | AskUserQuestion: multiple questions |
| Open-ended "What framework?" | AskUserQuestion: list common frameworks |
| Asking user to repeat info | Cache answers, reuse across skills |

---

## Testing the Rule

A skill is compliant if:
- ✅ Zero `"Please tell me:"`, `"Answer the following:"`, `"1)... 2)... 3)..."` patterns
- ✅ All decision points use `AskUserQuestion`
- ✅ User can complete workflow using arrow keys + Enter only
- ✅ Free-form inputs are clearly marked as exceptions

---

## Related Rules

- `language-response.md` — Response language auto-detection
- `orchestration-protocol.md` — Subagent delegation
- `primary-workflow.md` — Main development flow

---

**Last updated:** 2026-04-25
**Author:** Claude Super Kit
