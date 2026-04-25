---
name: sk:lerna-monorepo
description: Lerna v8+ monorepo management with npm/pnpm/yarn workspaces, fixed vs independent versioning strategies, lerna publish workflow, package hoisting, comparison with Nx.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: monorepo
argument-hint: "[Lerna task or versioning strategy]"
---

# sk:lerna-monorepo

Complete guide for managing JavaScript/TypeScript monorepos with Lerna v8+ and workspace package managers.

## When to Use

- Managing multiple npm packages in a single repository
- Coordinating version bumps and changelogs across packages
- Publishing packages to npm registry (public or private)
- Setting up workspace-based monorepo with Lerna orchestration
- Migrating from Lerna v6/v7 to v8
- Choosing between Lerna vs Nx for monorepo management

---

## 1. Setup: Lerna v8 + pnpm Workspaces

```bash
# Initialize new Lerna monorepo
npx lerna init --packages="packages/*" --independent

# Or add Lerna to existing workspace
npm install --save-dev lerna@latest
```

### Workspace Structure

```
my-monorepo/
├── packages/
│   ├── core/
│   │   ├── src/
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── ui/
│   │   ├── src/
│   │   └── package.json
│   ├── utils/
│   │   └── package.json
│   └── cli/
│       └── package.json
├── lerna.json
├── package.json          # workspace root
└── pnpm-workspace.yaml   # if using pnpm
```

### lerna.json

```json
{
  "$schema": "node_modules/lerna/schemas/lerna-schema.json",
  "version": "independent",
  "npmClient": "pnpm",
  "command": {
    "version": {
      "conventionalCommits": true,
      "changelogPreset": "conventional-changelog-conventionalcommits",
      "createRelease": "github",
      "allowBranch": ["main", "release/*"]
    },
    "publish": {
      "registry": "https://registry.npmjs.org",
      "conventionalCommits": true
    }
  },
  "packages": ["packages/*"]
}
```

### pnpm-workspace.yaml

```yaml
packages:
  - 'packages/*'
  - 'apps/*'
  - '!**/__tests__/**'
```

### Root package.json

```json
{
  "name": "my-monorepo",
  "private": true,
  "scripts": {
    "build": "lerna run build --stream",
    "test": "lerna run test --stream",
    "lint": "lerna run lint",
    "version": "lerna version --conventional-commits",
    "publish": "lerna publish from-git"
  },
  "devDependencies": {
    "lerna": "^8.0.0"
  }
}
```

---

## 2. Package Configuration

```json
// packages/core/package.json
{
  "name": "@my-org/core",
  "version": "1.2.0",
  "main": "./dist/index.cjs",
  "module": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "require": "./dist/index.cjs",
      "types": "./dist/index.d.ts"
    }
  },
  "scripts": {
    "build": "tsup src/index.ts --format cjs,esm --dts",
    "test": "vitest run",
    "lint": "eslint src"
  },
  "publishConfig": {
    "access": "public",
    "registry": "https://registry.npmjs.org"
  }
}
```

### Inter-package Dependencies

```json
// packages/ui/package.json — depends on core
{
  "name": "@my-org/ui",
  "dependencies": {
    "@my-org/core": "*"   // "*" = use workspace version
  }
}
```

```bash
# With pnpm — link workspace packages
pnpm install  # auto-links workspace packages
```

---

## 3. Versioning Strategies

### Fixed Versioning (all packages same version)

```json
// lerna.json
{ "version": "2.0.0" }  // all packages → 2.0.0
```

```bash
lerna version 2.1.0          # bump all to specific version
lerna version minor           # bump all minor
lerna version --conventional-commits  # auto from commits
```

Best for: UI component libraries, tightly coupled packages.

### Independent Versioning (each package its own version)

```json
// lerna.json
{ "version": "independent" }
```

```bash
lerna version  # interactive: select version bump per changed package
```

Output:
```
? Select a new version for @my-org/core (currently 1.2.0)
  ❯ Patch (1.2.1)
    Minor (1.3.0)
    Major (2.0.0)
    Custom
```

Best for: packages with different release cadences, separate teams.

---

## 4. Conventional Commits + Changelog

```bash
npm install --save-dev @commitlint/config-conventional @commitlint/cli conventional-changelog-conventionalcommits
```

```json
// commitlint.config.js
module.exports = { extends: ['@commitlint/config-conventional'] };
```

```bash
# Auto version bump + changelog from commits
lerna version --conventional-commits --yes

# This reads commits since last tag:
# feat: → minor bump
# fix: → patch bump
# BREAKING CHANGE: → major bump
```

Generated `CHANGELOG.md` per package:
```markdown
# Change Log
## [1.3.0] - 2026-04-25
### Features
- **core:** add new authentication method (#42)
### Bug Fixes
- **ui:** fix button disabled state (#38)
```

---

## 5. Publishing

```bash
# Publish packages with new versions (after lerna version)
lerna publish from-git        # publish commits tagged by lerna version
lerna publish from-package    # compare local vs registry versions

# Publish to private registry
lerna publish --registry=https://npm.mycompany.com

# Pre-release / canary
lerna publish --canary        # 1.2.0-alpha.0+sha
lerna publish prerelease --preid=beta  # 1.2.0-beta.0

# Dry run — see what would be published
lerna publish --dry-run
```

### .npmrc (authentication)

```ini
//registry.npmjs.org/:_authToken=${NPM_TOKEN}
@my-org:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
```

### GitHub Actions CI

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    branches: [main]
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0, token: '${{ secrets.GH_TOKEN }}' }
      - uses: pnpm/action-setup@v3
      - run: pnpm install --frozen-lockfile
      - run: pnpm run build
      - run: pnpm run test
      - name: Configure npm auth
        run: echo "//registry.npmjs.org/:_authToken=${{ secrets.NPM_TOKEN }}" > .npmrc
      - run: npx lerna publish from-git --yes
        env:
          GH_TOKEN: ${{ secrets.GH_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

---

## 6. Running Commands Across Packages

```bash
# Run script in all packages
lerna run build --stream         # stream output in real-time
lerna run test --parallel        # run in parallel
lerna run build --since=main     # only changed since main

# Run in specific packages
lerna run build --scope=@my-org/core
lerna run build --scope="{@my-org/core,@my-org/ui}"

# Exclude packages
lerna run test --ignore=@my-org/cli

# Pass args to underlying script
lerna run test -- --coverage --watchAll=false
```

---

## 7. Hoisting (npm/yarn workspaces)

```json
// package.json (root) — yarn workspaces with hoisting
{
  "workspaces": {
    "packages": ["packages/*"],
    "nohoist": ["**/react-native", "**/react-native/**"]
  }
}
```

```json
// lerna.json — enable hoisting
{
  "npmClient": "yarn",
  "useWorkspaces": true
}
```

With pnpm — hoisting via `.npmrc`:
```ini
# .npmrc
shamefully-hoist=true       # hoist all (not recommended)
public-hoist-pattern[]=*eslint*
public-hoist-pattern[]=*prettier*
```

---

## 8. Lerna vs Nx Comparison

| Feature | Lerna v8 | Nx |
|---|---|---|
| Primary focus | Package versioning + publishing | Build system + task orchestration |
| Task caching | Via Nx integration | Built-in (local + cloud) |
| Affected detection | `--since` (git-based) | Smart dep graph |
| Code generators | No | Yes (full generator system) |
| Module boundaries | No | Yes (ESLint rules) |
| Best for | OSS library publishing | Large app monorepos |
| Nx integration | `lerna add-caching` | Native |

```bash
# Use Lerna + Nx together (best of both)
npx lerna add-caching   # adds Nx task runner to Lerna workspace
```

---

## Reference Docs

- [Lerna v8 Docs](https://lerna.js.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [pnpm Workspaces](https://pnpm.io/workspaces)
- [Lerna + Nx](https://nx.dev/recipes/adopting-nx/lerna-and-nx)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Bạn dùng package manager nào? (npm / pnpm / yarn)"
2. "Mục tiêu chính: publish npm packages / quản lý internal apps / cả hai?"
3. "Bạn cần fixed versioning (all packages same) hay independent versioning (mỗi package khác nhau)?"
4. "Bạn đã dùng Lerna chưa hay đang setup từ đầu?"

Cung cấp config và workflow publishing phù hợp với setup của họ.
