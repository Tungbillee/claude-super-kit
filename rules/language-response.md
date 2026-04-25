# Response Language Auto-Detection (MANDATORY)

**Version:** 1.0.0
**Applies to:** All Claude Super Kit interactions

---

## Core Rule

**Detect user's input language → respond in that same language.**

| User asks in | Claude responds in |
|---|---|
| Vietnamese | Vietnamese |
| English | English |
| Other (Chinese, Japanese, etc.) | That language |
| Mixed | Primary language of the message |

---

## Implementation Rules

### 1. Skill source code (SKILL.md, references/)
**ALWAYS English.** Reasons:
- LLM training data optimization (better understanding)
- International contributors can read
- Universal technical terms

### 2. CLAUDE.md (project rules)
**Project-specific.** Vietnamese for VN projects, English for international.

### 3. User-facing responses (chat)
**Auto-detect from latest user message.**

### 4. Reports / journals / plans (in `plans/`, `docs/`)
**Match session language.** If user converses in Vietnamese, write reports in Vietnamese.

### 5. Code identifiers, file paths, commands
**ALWAYS preserve original (English/code-conventions).** Don't translate variable names.

### 6. Diagrams, charts, slide content
**Match response language.** Labels, titles, annotations follow user's language.

---

## Edge Cases

### Mixed input
User: "Em hãy refactor cái function `getUserById` này"
→ Vietnamese (primary), keep `getUserById` as-is

### Ambiguous input (single word, code-only)
Default to last detected language in conversation.

### First message in session
Detect from first user message. If unclear, default to English.

### Subagent reports
Subagents should check parent session's language and match.

---

## Vietnamese Quality Requirements

When responding in Vietnamese:
- **Full diacritics required** — never write "nao" for "não", "khong" for "không"
- Maintain proper accent marks at all times
- Use formal but friendly tone (anh/em, không "tao/mày")
- Technical terms: keep English when no clear Vietnamese equivalent (e.g., "webhook", "middleware", "deployment")

---

## Examples

### ✅ GOOD

**User (VN):** "Giúp anh tạo function login"
**Claude:**
> Em sẽ tạo function `login()` cho anh. Em đề xuất dùng email + password với bcrypt hash.
> ...

**User (EN):** "Help me create a login function"
**Claude:**
> I'll create a `login()` function. I suggest email + password with bcrypt hashing.
> ...

### ❌ BAD

**User (VN):** "Giúp anh tạo function login"
**Claude (responding in English):**
> "I'll create a login function..."

**User (EN):** "Help me create a login function"
**Claude (responding in Vietnamese):**
> "Em sẽ tạo function login cho anh..."

---

## Why This Rule

1. **Natural UX** — User shouldn't have to switch languages
2. **Inclusive** — Support Vietnamese-first workflow without losing international devs
3. **Skill quality unaffected** — Skills stay English (LLM-optimal)

---

## Related Rules

- `interactive-ui-protocol.md` — Interactive UI for all questions
- `primary-workflow.md` — Main development flow

---

**Last updated:** 2026-04-25
