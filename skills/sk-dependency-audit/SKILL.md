---
name: sk:dependency-audit
description: Automated dependency management with Renovate and Dependabot. Security advisory analysis, breaking change detection, upgrade strategies, monorepo considerations.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: devops
argument-hint: "[dependency update task or security audit]"
---

# sk:dependency-audit

Guide for automating dependency updates, security auditing, and managing breaking changes across projects.

## When to Use

- Setting up automated dependency update PRs (Renovate or Dependabot)
- Auditing npm packages for security vulnerabilities
- Detecting breaking changes before upgrading major versions
- Configuring smart update strategies (group, schedule, auto-merge)
- Handling monorepo dependency management
- Analyzing npm audit reports and CVE advisories

---

## 1. npm Security Audit

```bash
# Basic audit
npm audit

# JSON output for scripting
npm audit --json

# Fix automatically (safe patches only)
npm audit fix

# Fix including major version bumps (review first!)
npm audit fix --force

# Audit specific severity
npm audit --audit-level=high   # only show high/critical

# pnpm
pnpm audit --fix

# yarn
yarn audit
```

### Parse Audit Output

```bash
# Count vulnerabilities by severity
npm audit --json | jq '.metadata.vulnerabilities'
# { "info": 0, "low": 2, "moderate": 5, "high": 1, "critical": 0 }

# List only critical/high packages
npm audit --json | jq '.vulnerabilities | to_entries[] | select(.value.severity == "critical" or .value.severity == "high") | .key'
```

---

## 2. Dependabot Setup

```yaml
# .github/dependabot.yml
version: 2
updates:
  # npm dependencies
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "Asia/Ho_Chi_Minh"
    open-pull-requests-limit: 10
    groups:
      # Group minor/patch updates together
      minor-and-patch:
        patterns: ["*"]
        update-types: ["minor", "patch"]
    ignore:
      - dependency-name: "react"
        update-types: ["version-update:semver-major"]
    labels:
      - "dependencies"
      - "automated"
    commit-message:
      prefix: "chore"
      include: "scope"

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"

  # Docker
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Dependabot Auto-merge (GitHub Actions)

```yaml
# .github/workflows/dependabot-auto-merge.yml
name: Dependabot auto-merge
on: pull_request

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - name: Get metadata
        id: meta
        uses: dependabot/fetch-metadata@v2
        with:
          github-token: "${{ secrets.GITHUB_TOKEN }}"

      - name: Auto-merge patch updates
        if: steps.meta.outputs.update-type == 'version-update:semver-patch'
        run: gh pr merge --auto --merge "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Auto-merge minor dev dependencies
        if: |
          steps.meta.outputs.update-type == 'version-update:semver-minor' &&
          steps.meta.outputs.dependency-type == 'direct:development'
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 3. Renovate Configuration

```bash
# Install Renovate Bot via GitHub App: https://github.com/apps/renovate
# Or self-host:
npm install --save-dev renovate
```

```json
// renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    "schedule:weekly",
    ":dependencyDashboard"
  ],
  "timezone": "Asia/Ho_Chi_Minh",
  "schedule": ["before 9am on Monday"],
  "prHourlyLimit": 3,
  "prConcurrentLimit": 10,
  "labels": ["dependencies"],
  "packageRules": [
    {
      "description": "Auto-merge minor/patch for dev deps",
      "matchDepTypes": ["devDependencies"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true
    },
    {
      "description": "Group all ESLint updates",
      "matchPackagePatterns": ["^eslint"],
      "groupName": "ESLint packages",
      "automerge": true
    },
    {
      "description": "Group all testing libraries",
      "matchPackageNames": ["vitest", "@vitest/coverage-v8", "jest", "@types/jest"],
      "groupName": "Testing framework",
      "automerge": true
    },
    {
      "description": "Hold major React updates for manual review",
      "matchPackageNames": ["react", "react-dom", "react-router-dom"],
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["breaking-change", "manual-review"]
    },
    {
      "description": "Pin GitHub Actions to SHA for security",
      "matchManagers": ["github-actions"],
      "pinDigests": true
    }
  ],
  "vulnerabilityAlerts": {
    "enabled": true,
    "labels": ["security"],
    "automerge": true
  }
}
```

### Renovate: Monorepo Support

```json
// renovate.json — monorepo with pnpm workspaces
{
  "extends": ["config:recommended"],
  "pnpm": { "enabled": true },
  "packageRules": [
    {
      "matchFileNames": ["apps/web/package.json"],
      "groupName": "web app dependencies"
    },
    {
      "matchFileNames": ["packages/*/package.json"],
      "groupName": "shared library dependencies",
      "automerge": true
    }
  ],
  "ignorePaths": ["**/node_modules/**", "**/dist/**"]
}
```

---

## 4. Breaking Change Detection

### Manual: Check Changelog / Release Notes

```bash
# Check what changed between versions
npm show react@18.0.0 description
npm show react@19.0.0 description

# View package changelog
npx changelog react        # if package has CHANGELOG.md

# Check breaking changes in npm release
npm show react@19.0.0 dist-tags
```

### Automated: npx npm-check-updates

```bash
# Install
npm install -g npm-check-updates

# Check outdated packages
ncu                       # list all outdated
ncu -u                    # update package.json
ncu --target minor        # only minor/patch
ncu --filter react        # specific package
ncu --reject "^react$"    # exclude package

# Interactive mode
ncu --interactive
```

### depcheck — Find Unused Dependencies

```bash
npx depcheck
# Output:
# Unused dependencies: lodash, moment
# Unused devDependencies: @types/node
# Missing dependencies: axios (used but not in package.json)
```

---

## 5. Security Advisory Workflow

```bash
# Step 1: Audit
npm audit --json > audit-report.json

# Step 2: Identify affected packages
cat audit-report.json | jq '.vulnerabilities | keys[]'

# Step 3: Check if fix available
cat audit-report.json | jq '.vulnerabilities.PACKAGE_NAME.fixAvailable'

# Step 4: Try safe fix
npm audit fix

# Step 5: If no auto-fix, check if override works
# package.json overrides (npm v8+)
```

```json
// package.json — force override vulnerable transitive dep
{
  "overrides": {
    "vulnerable-package": "^2.0.0"  // force safe version
  },
  // pnpm equivalent:
  "pnpm": {
    "overrides": {
      "vulnerable-package": "^2.0.0"
    }
  }
}
```

### Snyk Integration

```bash
npm install -g snyk
snyk auth
snyk test                    # scan current project
snyk monitor                 # continuous monitoring
snyk fix                     # auto-fix vulnerabilities
snyk test --severity-threshold=high
```

---

## 6. CI Security Gate

```yaml
# .github/workflows/security-audit.yml
name: Security Audit
on:
  push:
    paths: ['package*.json', 'pnpm-lock.yaml']
  schedule:
    - cron: '0 9 * * 1'   # Every Monday 9 AM

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - name: Run security audit
        run: npm audit --audit-level=high
      - name: Check for critical vulnerabilities
        run: |
          CRITICAL=$(npm audit --json | jq '.metadata.vulnerabilities.critical')
          if [ "$CRITICAL" -gt "0" ]; then
            echo "CRITICAL vulnerabilities found: $CRITICAL"
            exit 1
          fi
```

---

## Reference Docs

- [Renovate Documentation](https://docs.renovatebot.com/)
- [Dependabot Configuration](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file)
- [npm audit](https://docs.npmjs.com/cli/v10/commands/npm-audit)
- [Snyk](https://snyk.io/)
- [npm overrides](https://docs.npmjs.com/cli/v8/configuring-npm/package-json#overrides)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Bạn đang dùng tool nào? (Renovate / Dependabot / chưa có gì)"
2. "Package manager: npm / pnpm / yarn?"
3. "Bạn cần: setup auto-update PRs / audit security / detect breaking changes / handle monorepo?"
4. "Bạn có muốn auto-merge patch/minor không hay cần manual review hết?"

Cung cấp config cụ thể cho tool và strategy phù hợp với team của họ.
