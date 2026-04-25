---
name: sk:semantic-release
description: "semantic-release — automated versioning, changelogs, GitHub releases, multi-branch, GitHub Actions integration"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: devops
last_updated: 2026-04-25
license: MIT
---

# sk:semantic-release — Automated Semantic Versioning

## When to Use

- Automate npm publish + GitHub releases from CI
- Generate CHANGELOG.md from conventional commits
- Multi-branch release flow (main/beta/alpha)
- Monorepo release coordination

## Conventional Commits → Version Bumps

| Commit prefix | Version bump | Example |
|--------------|-------------|---------|
| `fix:` | patch (0.0.x) | `fix: correct payment hash` |
| `feat:` | minor (0.x.0) | `feat: add ZaloPay support` |
| `feat!:` or `BREAKING CHANGE:` | major (x.0.0) | `feat!: new auth API` |
| `chore:`, `docs:`, `style:` | no release | `docs: update README` |
| `perf:` | patch | `perf: cache db queries` |

## Install

```bash
npm install --save-dev \
  semantic-release \
  @semantic-release/commit-analyzer \
  @semantic-release/release-notes-generator \
  @semantic-release/changelog \
  @semantic-release/npm \
  @semantic-release/github \
  @semantic-release/git
```

## .releaserc.json Template

```json
{
  "branches": [
    "main",
    { "name": "beta", "prerelease": true },
    { "name": "alpha", "prerelease": true },
    { "name": "next", "prerelease": true }
  ],
  "plugins": [
    ["@semantic-release/commit-analyzer", {
      "preset": "conventionalcommits",
      "releaseRules": [
        { "type": "feat",     "release": "minor" },
        { "type": "fix",      "release": "patch" },
        { "type": "perf",     "release": "patch" },
        { "type": "revert",   "release": "patch" },
        { "breaking": true,   "release": "major" }
      ]
    }],
    ["@semantic-release/release-notes-generator", {
      "preset": "conventionalcommits",
      "presetConfig": {
        "types": [
          { "type": "feat",  "section": "Features" },
          { "type": "fix",   "section": "Bug Fixes" },
          { "type": "perf",  "section": "Performance" },
          { "type": "revert","section": "Reverts" }
        ]
      }
    }],
    ["@semantic-release/changelog", {
      "changelogFile": "CHANGELOG.md"
    }],
    ["@semantic-release/npm", {
      "npmPublish": true
    }],
    ["@semantic-release/git", {
      "assets": ["CHANGELOG.md", "package.json"],
      "message": "chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}"
    }],
    ["@semantic-release/github", {
      "assets": [
        { "path": "dist/*.js", "label": "Distribution" }
      ]
    }]
  ]
}
```

## GitHub Actions Integration

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main, beta, alpha]

permissions:
  contents: write
  issues: write
  pull-requests: write
  id-token: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0        # full history required
          persist-credentials: false

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - run: npm ci

      - run: npm run build

      - name: Semantic Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
        run: npx semantic-release
```

## Multi-Branch Strategy

```
main   → stable releases    1.2.3
beta   → pre-releases       1.3.0-beta.1
alpha  → dev pre-releases   1.3.0-alpha.1
next   → next major         2.0.0-next.1
```

Branch config in `.releaserc.json`:

```json
"branches": [
  "main",
  { "name": "1.x", "range": "1.x.x", "channel": "1.x" },
  { "name": "beta", "prerelease": true },
  { "name": "alpha", "prerelease": true, "channel": "alpha" }
]
```

## Electron App Release (No npm Publish)

```json
{
  "branches": ["main", { "name": "beta", "prerelease": true }],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/changelog", { "changelogFile": "CHANGELOG.md" }],
    ["@semantic-release/npm", { "npmPublish": false }],
    ["@semantic-release/git", {
      "assets": ["CHANGELOG.md", "package.json"],
      "message": "chore(release): ${nextRelease.version} [skip ci]"
    }],
    ["@semantic-release/github", {
      "assets": [
        { "path": "release/*.dmg",     "label": "macOS" },
        { "path": "release/*.exe",     "label": "Windows" },
        { "path": "release/*.AppImage","label": "Linux" }
      ]
    }]
  ]
}
```

## Monorepo with Changesets (Alternative)

When semantic-release isn't right for monorepos, use Changesets:

```bash
npm install --save-dev @changesets/cli
npx changeset init

# Developer workflow:
npx changeset          # describe what changed (interactive)
npx changeset version  # bump versions + update changelogs
npx changeset publish  # publish to npm
```

```yaml
# .github/workflows/release.yml — Changesets PR approach
- name: Create Release PR or Publish
  uses: changesets/action@v1
  with:
    publish: npm run release
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

## Decision: semantic-release vs Changesets

| Factor | semantic-release | Changesets |
|--------|-----------------|------------|
| Single package | Best fit | Overkill |
| Monorepo | Complex config | Best fit |
| Fully automated | Yes | Semi-manual |
| Developer involvement | Commit message only | Explicit changeset file |
| Independent versioning | Hard | Native |

## Local Dry Run

```bash
# Test without publishing — shows what WOULD be released
npx semantic-release --dry-run --no-ci

# Debug: see which commits trigger releases
npx semantic-release --dry-run --debug
```

## Required GitHub Secrets

| Secret | Source | Used by |
|--------|--------|---------|
| `GITHUB_TOKEN` | Auto (Actions) | GitHub releases |
| `NPM_TOKEN` | npmjs.com → Access Tokens | npm publish |

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "What type of project?",
      header: "Project",
      options: [
        { label: "npm library", description: "Publish to npmjs.com" },
        { label: "Electron app", description: "GitHub releases + binaries" },
        { label: "Monorepo", description: "Multiple packages" },
        { label: "Backend / internal", description: "No npm publish" }
      ]
    },
    {
      question: "Release branch strategy?",
      header: "Branches",
      options: [
        { label: "main only", description: "Simple single-channel" },
        { label: "main + beta", description: "Stable + pre-release" },
        { label: "main + beta + alpha", description: "Full multi-channel" }
      ]
    }
  ]
})
```
