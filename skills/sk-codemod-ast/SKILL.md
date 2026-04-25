---
name: sk:codemod-ast
description: AST-based code transformations with jscodeshift and ts-morph. Write codemods to rename APIs, refactor function signatures, migrate patterns across large codebases. Test patterns and common transforms.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: dx-tools
argument-hint: "[codemod task or AST transformation]"
---

# sk:codemod-ast

Guide for writing automated code transformations (codemods) using jscodeshift and ts-morph to migrate large codebases efficiently.

## When to Use

- Renaming functions, variables, or imports across entire codebase
- Migrating deprecated API calls to new signatures
- Transforming code patterns (e.g., callbacks → promises → async/await)
- Upgrading library APIs after major version changes
- Adding/removing arguments from function calls consistently
- TypeScript-aware transformations with full type information

---

## 1. jscodeshift Basics

```bash
npm install --save-dev jscodeshift @types/jscodeshift
```

### Minimal Codemod Structure

```typescript
// codemods/rename-function.ts
import { Transform, API, FileInfo, Options } from 'jscodeshift';

const transform: Transform = (file: FileInfo, api: API, options: Options) => {
  const j = api.jscodeshift;
  const root = j(file.source);

  // Find and transform
  root
    .find(j.CallExpression, {
      callee: { type: 'Identifier', name: 'oldFunction' },
    })
    .forEach((path) => {
      path.node.callee = j.identifier('newFunction');
    });

  return root.toSource({ quote: 'single' });
};

export default transform;
```

```bash
# Run codemod
npx jscodeshift -t codemods/rename-function.ts src/**/*.ts --parser=tsx --dry
# Remove --dry to apply changes
```

---

## 2. AST Concepts: Find / Replace / Insert

### Find Nodes

```typescript
// Find all import declarations from 'lodash'
root.find(j.ImportDeclaration, { source: { value: 'lodash' } });

// Find specific function calls
root.find(j.CallExpression, {
  callee: { object: { name: 'console' }, property: { name: 'log' } },
});

// Find variable declarations with specific name
root.find(j.VariableDeclarator, {
  id: { type: 'Identifier', name: 'myVar' },
});

// Find class declarations
root.find(j.ClassDeclaration).filter(
  (path) => path.node.superClass?.name === 'React.Component'
);
```

### Replace Nodes

```typescript
// Rename import source
root
  .find(j.ImportDeclaration, { source: { value: 'old-package' } })
  .forEach((path) => {
    path.node.source = j.literal('new-package');
  });

// Replace method call: obj.oldMethod() → obj.newMethod()
root
  .find(j.MemberExpression, {
    property: { name: 'oldMethod' },
  })
  .forEach((path) => {
    (path.node.property as any).name = 'newMethod';
  });

// Replace entire expression
root
  .find(j.CallExpression, { callee: { name: 'deprecated' } })
  .replaceWith((path) =>
    j.callExpression(j.identifier('updated'), path.node.arguments)
  );
```

### Insert / Add Nodes

```typescript
// Add import if not exists
const has_import = root.find(j.ImportDeclaration, {
  source: { value: 'react' },
}).length > 0;

if (!has_import) {
  const react_import = j.importDeclaration(
    [j.importDefaultSpecifier(j.identifier('React'))],
    j.literal('react')
  );
  root.find(j.Program).get('body', 0).insertBefore(react_import);
}

// Add named import to existing declaration
root
  .find(j.ImportDeclaration, { source: { value: 'react' } })
  .forEach((path) => {
    const already_imported = path.node.specifiers?.some(
      (s) => s.type === 'ImportSpecifier' && s.local.name === 'useState'
    );
    if (!already_imported) {
      path.node.specifiers?.push(
        j.importSpecifier(j.identifier('useState'))
      );
    }
  });
```

---

## 3. Common Transforms

### Rename Function + Update All Call Sites

```typescript
// codemods/rename-api.ts
const transform: Transform = (file, api) => {
  const j = api.jscodeshift;
  const root = j(file.source);
  let changed = false;

  // Rename in import
  root
    .find(j.ImportSpecifier, { imported: { name: 'fetchUser' } })
    .forEach((path) => {
      path.node.imported.name = 'getUser';
      if (!path.node.local || path.node.local.name === 'fetchUser') {
        path.node.local = j.identifier('getUser');
      }
      changed = true;
    });

  // Rename all call sites
  root
    .find(j.CallExpression, { callee: { name: 'fetchUser' } })
    .forEach((path) => {
      (path.node.callee as any).name = 'getUser';
      changed = true;
    });

  return changed ? root.toSource({ quote: 'single' }) : null; // null = no change
};
```

### Migrate Callback to Promise

```typescript
// Before: fs.readFile(path, callback)
// After:  fs.promises.readFile(path)
const transform: Transform = (file, api) => {
  const j = api.jscodeshift;
  const root = j(file.source);

  root
    .find(j.CallExpression, {
      callee: {
        object: { name: 'fs' },
        property: { name: 'readFile' },
      },
    })
    .filter((path) => path.node.arguments.length === 2)
    .replaceWith((path) =>
      j.callExpression(
        j.memberExpression(
          j.memberExpression(j.identifier('fs'), j.identifier('promises')),
          j.identifier('readFile')
        ),
        [path.node.arguments[0]] // drop callback
      )
    );

  return root.toSource();
};
```

### Add Argument to Function Signature

```typescript
// Add `options = {}` param to all calls of `createClient(config)`
// → createClient(config, options)
root
  .find(j.CallExpression, { callee: { name: 'createClient' } })
  .filter((path) => path.node.arguments.length === 1)
  .forEach((path) => {
    path.node.arguments.push(
      j.objectExpression([]) // {}
    );
  });
```

---

## 4. Testing Codemods

```bash
npm install --save-dev jest @types/jest
```

```typescript
// codemods/__tests__/rename-api.test.ts
import { describe, it, expect } from 'vitest';
import jscodeshift from 'jscodeshift';
import transform from '../rename-api';

const j = jscodeshift.withParser('tsx');

describe('rename-api codemod', () => {
  it('renames fetchUser import to getUser', () => {
    const input = `import { fetchUser } from './api';`;
    const expected = `import { getUser } from './api';`;
    const output = transform({ source: input, path: 'test.ts' }, { jscodeshift: j }, {});
    expect(output).toBe(expected);
  });

  it('renames fetchUser call sites', () => {
    const input = `const user = fetchUser(id);`;
    const expected = `const user = getUser(id);`;
    const output = transform({ source: input, path: 'test.ts' }, { jscodeshift: j }, {});
    expect(output).toBe(expected);
  });

  it('returns null when no changes needed', () => {
    const input = `import { getUser } from './api';`;
    const output = transform({ source: input, path: 'test.ts' }, { jscodeshift: j }, {});
    expect(output).toBeNull();
  });
});
```

---

## 5. TypeScript Codemods with ts-morph

ts-morph provides type-aware transformations — it knows actual types, not just AST structure.

```bash
npm install --save-dev ts-morph
```

```typescript
// codemods/ts-rename-type.ts
import { Project, SyntaxKind } from 'ts-morph';

const project = new Project({
  tsConfigFilePath: './tsconfig.json',
});

// Add source files
project.addSourceFilesAtPaths('src/**/*.{ts,tsx}');

// Rename interface across codebase (type-safe)
project.getSourceFiles().forEach((source_file) => {
  source_file
    .getDescendantsOfKind(SyntaxKind.TypeReference)
    .filter((ref) => ref.getTypeName().getText() === 'OldInterface')
    .forEach((ref) => ref.getTypeName().rename('NewInterface'));
});

// Add missing return types
project.getSourceFiles().forEach((source_file) => {
  source_file.getFunctions().forEach((fn) => {
    if (!fn.getReturnTypeNode()) {
      const return_type = fn.getReturnType().getText();
      fn.setReturnType(return_type);
    }
  });
});

// Save changes
project.saveSync();
```

### ts-morph: Remove Unused Imports

```typescript
project.getSourceFiles().forEach((source_file) => {
  source_file.getImportDeclarations().forEach((import_decl) => {
    const named_imports = import_decl.getNamedImports();
    named_imports.forEach((named) => {
      const refs = named.getNameNode().findReferencesAsNodes();
      // refs[0] is the import itself — if only 1 ref, it's unused
      if (refs.length === 1) {
        named.remove();
      }
    });
    // Remove empty import declaration
    if (import_decl.getNamedImports().length === 0 && !import_decl.getDefaultImport()) {
      import_decl.remove();
    }
  });
});
project.saveSync();
```

---

## 6. Running at Scale

```bash
# Dry run — preview changes
npx jscodeshift -t codemod.ts 'src/**/*.{ts,tsx}' --parser=tsx --dry --print

# Apply changes
npx jscodeshift -t codemod.ts 'src/**/*.{ts,tsx}' --parser=tsx

# With extensions filter
npx jscodeshift -t codemod.ts src/ --extensions=ts,tsx --ignore-pattern='**/*.test.*'

# Run ts-morph codemod
npx ts-node codemods/ts-rename-type.ts
```

---

## Reference Docs

- [jscodeshift](https://github.com/facebook/jscodeshift)
- [AST Explorer](https://astexplorer.net/) — visualize AST of any code
- [ts-morph docs](https://ts-morph.com/)
- [jscodeshift API](https://github.com/benjamn/ast-types)
- [Codeshift Community](https://www.codeshiftcommunity.com/)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Bạn cần transform gì? (rename function/import / change API signature / migrate pattern / remove dead code)"
2. "Bạn dùng JavaScript hay TypeScript? TypeScript cần type-awareness không?"
3. "Scope của codebase: bao nhiêu files? Cần dry-run trước không?"

Paste code before/after example để hiểu rõ transformation, sau đó viết codemod cụ thể.
