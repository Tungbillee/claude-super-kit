---
name: sk:nx-monorepo
description: Nx workspace setup, generators (lib/app), task dependency graph, computation caching, distributed task execution (Nx Cloud), affected commands, project boundaries with ESLint rules.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: monorepo
argument-hint: "[Nx task or workspace configuration]"
---

# sk:nx-monorepo

Complete guide for managing monorepos with Nx — the scalable build system with smart caching and task orchestration.

## When to Use

- Setting up a new Nx monorepo workspace
- Adding libraries and applications to an existing Nx workspace
- Configuring computation caching (local + Nx Cloud)
- Running only affected projects after code changes
- Enforcing module boundaries between projects
- Optimizing CI pipelines with distributed task execution

---

## 1. Workspace Setup

```bash
# Create new Nx workspace
npx create-nx-workspace@latest my-org --preset=ts
# Presets: ts | react | angular | next | node | empty

# Or integrate into existing monorepo
npx nx@latest init

# Add plugins
nx add @nx/react
nx add @nx/node
nx add @nx/next
nx add @nx/express
```

### Workspace Structure

```
my-org/
├── apps/
│   ├── web/                  # React/Next.js app
│   ├── api/                  # Node.js API
│   └── mobile/               # React Native app
├── libs/
│   ├── shared/
│   │   ├── ui/               # Shared UI components
│   │   ├── utils/            # Shared utilities
│   │   └── types/            # Shared TypeScript types
│   ├── feature-auth/         # Auth feature lib
│   └── data-access-users/    # Users data layer
├── nx.json                   # Nx configuration
├── package.json
└── tsconfig.base.json
```

---

## 2. Generators — Create Apps and Libs

```bash
# Generate React application
nx g @nx/react:app web --directory=apps/web --bundler=vite

# Generate Node API
nx g @nx/node:app api --directory=apps/api --framework=express

# Generate shared library
nx g @nx/js:lib shared-utils --directory=libs/shared/utils --bundler=tsc

# Generate React component library
nx g @nx/react:lib ui --directory=libs/shared/ui --bundler=vite

# Generate feature library (with routing)
nx g @nx/react:lib feature-auth --directory=libs/feature-auth

# Generate library with custom tags (for boundary enforcement)
nx g @nx/js:lib data-access-users \
  --directory=libs/data-access-users \
  --tags="scope:shared,type:data-access"
```

### project.json (per project config)

```json
// apps/web/project.json
{
  "name": "web",
  "projectType": "application",
  "tags": ["scope:web", "type:app"],
  "targets": {
    "build": {
      "executor": "@nx/vite:build",
      "options": { "outputPath": "dist/apps/web" },
      "configurations": {
        "production": { "mode": "production" }
      }
    },
    "serve": { "executor": "@nx/vite:dev-server" },
    "test":  { "executor": "@nx/vitest:vitest" },
    "lint":  { "executor": "@nx/eslint:lint" }
  }
}
```

---

## 3. Running Tasks

```bash
# Run single target on one project
nx build web
nx test shared-utils
nx lint api

# Run target on all projects
nx run-many -t build
nx run-many -t test --parallel=4

# Run multiple targets
nx run-many -t build,test,lint

# Run with specific configuration
nx build web --configuration=production

# Watch mode
nx serve web
```

---

## 4. Affected Commands (CI Optimization)

```bash
# Only build/test projects affected by current changes
nx affected -t build
nx affected -t test
nx affected -t lint

# Against specific base branch
nx affected -t build --base=main --head=HEAD

# Show what's affected (visualize)
nx affected:graph

# In CI (GitHub Actions example)
nx affected -t build,test --base=${{ github.event.pull_request.base.sha }}
```

```yaml
# .github/workflows/ci.yml
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - run: npx nx affected -t lint,test,build --base=origin/main
```

---

## 5. Task Dependency Graph

```json
// nx.json
{
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],   // build deps first
      "cache": true,
      "inputs": ["production", "^production"]
    },
    "test": {
      "dependsOn": ["build"],
      "cache": true,
      "inputs": ["default", "^production", "{workspaceRoot}/jest.preset.js"]
    },
    "lint": { "cache": true }
  },
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": [
      "default",
      "!{projectRoot}/**/*.spec.*",
      "!{projectRoot}/src/test-setup.*"
    ],
    "sharedGlobals": ["{workspaceRoot}/tsconfig.base.json"]
  }
}
```

```bash
# Visualize full task graph
nx graph
nx graph --focus=web     # focus on one project
```

---

## 6. Computation Caching

```json
// nx.json — local cache config
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "nx/tasks-runners/default",
      "options": {
        "cacheableOperations": ["build", "test", "lint", "e2e"],
        "cacheDirectory": ".nx/cache"
      }
    }
  }
}
```

```bash
# Clear local cache
nx reset

# Show cache status
nx show project web --web
```

### Nx Cloud (Distributed Caching)

```bash
# Connect to Nx Cloud
npx nx connect

# nx.json after connection
{
  "nxCloudAccessToken": "YOUR_TOKEN"
}
```

---

## 7. Project Boundaries (ESLint)

```bash
npm install @nx/eslint-plugin --save-dev
```

```json
// .eslintrc.json (root)
{
  "plugins": ["@nx"],
  "rules": {
    "@nx/enforce-module-boundaries": [
      "error",
      {
        "enforceBuildableLibDependency": true,
        "allow": [],
        "depConstraints": [
          {
            "sourceTag": "type:app",
            "onlyDependOnLibsWithTags": ["type:feature", "type:ui", "type:data-access", "type:utils"]
          },
          {
            "sourceTag": "type:feature",
            "onlyDependOnLibsWithTags": ["type:ui", "type:data-access", "type:utils"]
          },
          {
            "sourceTag": "type:data-access",
            "onlyDependOnLibsWithTags": ["type:utils"]
          },
          {
            "sourceTag": "scope:web",
            "onlyDependOnLibsWithTags": ["scope:web", "scope:shared"]
          }
        ]
      }
    ]
  }
}
```

---

## 8. Path Aliases (tsconfig.base.json)

```json
// tsconfig.base.json — auto-generated by Nx generators
{
  "compilerOptions": {
    "paths": {
      "@my-org/shared-utils": ["libs/shared/utils/src/index.ts"],
      "@my-org/shared-ui": ["libs/shared/ui/src/index.ts"],
      "@my-org/feature-auth": ["libs/feature-auth/src/index.ts"],
      "@my-org/data-access-users": ["libs/data-access-users/src/index.ts"]
    }
  }
}
```

```typescript
// Import using path alias
import { formatDate } from '@my-org/shared-utils';
import { Button } from '@my-org/shared-ui';
```

---

## 9. Custom Generators

```bash
# Generate a custom generator
nx g @nx/plugin:generator my-component --project=tools-generators
```

```typescript
// tools/generators/my-component/generator.ts
import { Tree, formatFiles, generateFiles, names } from '@nx/devkit';

export default async function (tree: Tree, options: { name: string; project: string }) {
  const name_variants = names(options.name);
  generateFiles(tree, path.join(__dirname, 'files'), `libs/${options.project}/src`, {
    ...name_variants,
    tmpl: '',
  });
  await formatFiles(tree);
}
```

---

## Reference Docs

- [Nx Documentation](https://nx.dev/getting-started/intro)
- [Nx Cloud](https://nx.app/)
- [Affected Projects](https://nx.dev/nx-api/nx/documents/affected)
- [Module Boundaries](https://nx.dev/features/enforce-module-boundaries)
- [Task Pipeline](https://nx.dev/concepts/task-pipeline-configuration)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Bạn đang setup workspace mới hay integrate vào project có sẵn?"
2. "Tech stack của bạn là gì? (React / Next.js / Node / Angular / mixed)"
3. "Bạn cần help với: setup / generators / caching / affected commands / module boundaries?"

Cung cấp commands và config cụ thể cho tech stack và use case của họ.
