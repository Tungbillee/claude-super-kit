---
name: sk:solidjs-development
description: Solid 1.8+ fine-grained reactivity, signals (createSignal/createEffect/createMemo), stores (createStore), control flow (Show/For/Switch), Solid Router, performance comparison vs React. Zero VDOM overhead.
license: MIT
argument-hint: "[signals|store|router|performance|component] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: frontend
  last_updated: "2026-04-25"
---

# SolidJS Development Skill

Fine-grained reactive UI with SolidJS - no virtual DOM, surgical DOM updates.

## When to Use

- Building high-performance reactive UIs
- Migrating from React (similar JSX, different mental model)
- Situations where VDOM overhead matters
- Learning fine-grained reactivity patterns
- Building with Solid Router for SPA/SSR

## Core Reactivity

### Signals

```typescript
import { createSignal, createEffect, createMemo, on } from 'solid-js';

// Signal = reactive primitive
const [count, setCount] = createSignal(0);
const [user, setUser] = createSignal<User | null>(null);

// Read: count() — always call as function
// Write: setCount(1) or setCount(prev => prev + 1)

// Memo = derived reactive value (lazy, cached)
const doubled = createMemo(() => count() * 2);
const full_name = createMemo(() => `${user()?.first} ${user()?.last}`);

// Effect = side effect (auto-tracks dependencies)
createEffect(() => {
  console.log('Count is now:', count()); // re-runs when count changes
  document.title = `Count: ${count()}`;
});

// Effect with explicit deps (on utility)
createEffect(on(count, (val, prev_val) => {
  console.log(`${prev_val} → ${val}`);
}, { defer: true })); // skip initial run
```

### Stores (Nested Reactive State)

```typescript
import { createStore, produce, reconcile } from 'solid-js/store';

const [state, setState] = createStore({
  user: { name: 'Alice', age: 30 },
  todos: [{ id: 1, text: 'Learn Solid', done: false }]
});

// Path-based update (fine-grained - only updates nested property)
setState('user', 'name', 'Bob');
setState('todos', 0, 'done', true);

// Produce (Immer-like immutable update)
setState(produce(state => {
  state.todos.push({ id: 2, text: 'Build app', done: false });
  state.user.age++;
}));

// Reconcile (diff and update entire structure)
setState('todos', reconcile(newTodosFromServer));

// Filter update
setState('todos', todo => !todo.done, 'text', t => `[done] ${t}`);
```

## Components

```tsx
import { type Component, type JSX, splitProps } from 'solid-js';

interface ButtonProps {
  label: string;
  variant?: 'primary' | 'secondary';
  onClick?: () => void;
  children?: JSX.Element;
}

const Button: Component<ButtonProps> = (props) => {
  // splitProps prevents reactivity loss when spreading
  const [local, rest] = splitProps(props, ['label', 'variant', 'onClick']);

  return (
    <button
      class={`btn btn-${local.variant ?? 'primary'}`}
      onClick={local.onClick}
      {...rest}
    >
      {local.label}
      {props.children}
    </button>
  );
};
```

## Control Flow (JSX Primitives)

```tsx
import { Show, For, Switch, Match, Index, Dynamic, Portal, ErrorBoundary } from 'solid-js';

// Show - conditional (keyed fallback)
<Show when={user()} fallback={<p>Loading...</p>}>
  {(u) => <p>Hello {u().name}</p>}  {/* accessor pattern - avoids re-render */}
</Show>

// For - list (tracks by reference)
<For each={todos()} fallback={<p>No todos</p>}>
  {(todo, index) => (
    <li class={todo.done ? 'done' : ''}>
      {index() + 1}. {todo.text}
    </li>
  )}
</For>

// Index - list (tracks by index, stable for primitives)
<Index each={numbers()}>
  {(num, i) => <span>{i}: {num()}</span>}
</Index>

// Switch/Match
<Switch fallback={<p>Unknown role</p>}>
  <Match when={role() === 'admin'}><AdminPanel /></Match>
  <Match when={role() === 'user'}><UserDashboard /></Match>
</Switch>

// Dynamic - dynamic component
<Dynamic component={components[type()]} {...props} />

// Portal - render outside tree
<Portal mount={document.getElementById('modal-root')!}>
  <Modal />
</Portal>

// ErrorBoundary
<ErrorBoundary fallback={(err, reset) => (
  <div>Error: {err.message} <button onClick={reset}>Retry</button></div>
)}>
  <RiskyComponent />
</ErrorBoundary>
```

## Context API

```tsx
import { createContext, useContext } from 'solid-js';

const ThemeContext = createContext<{ theme: string; toggle: () => void }>();

function ThemeProvider(props: { children: JSX.Element }) {
  const [theme, setTheme] = createSignal('light');
  return (
    <ThemeContext.Provider value={{ get theme() { return theme(); }, toggle: () => setTheme(t => t === 'light' ? 'dark' : 'light') }}>
      {props.children}
    </ThemeContext.Provider>
  );
}

function ThemedButton() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('Must be inside ThemeProvider');
  return <button onClick={ctx.toggle}>Theme: {ctx.theme}</button>;
}
```

## Solid Router v0.13+

```tsx
import { Router, Route, A, useParams, useNavigate, useSearchParams } from '@solidjs/router';

// App setup
function App() {
  return (
    <Router>
      <Route path="/" component={Home} />
      <Route path="/blog" component={Blog}>
        <Route path="/:slug" component={BlogPost} />
      </Route>
      <Route path="*404" component={NotFound} />
    </Router>
  );
}

// Route component with params
function BlogPost() {
  const params = useParams<{ slug: string }>();
  const navigate = useNavigate();
  const [search, setSearch] = useSearchParams();

  const [post] = createResource(() => params.slug, fetchPost);

  return (
    <Suspense fallback={<p>Loading...</p>}>
      <Show when={post()}>
        <h1>{post()?.title}</h1>
        <A href="/blog">← Back</A>
      </Show>
    </Suspense>
  );
}
```

## Async: createResource

```typescript
import { createResource, Suspense } from 'solid-js';

// Simple resource
const [data] = createResource(fetchData);

// Parameterized resource (re-fetches when param changes)
const [post, { refetch, mutate }] = createResource(
  () => params.id,          // source signal
  (id) => fetchPost(id),    // fetcher
  { initialValue: null }
);

// Usage
<Suspense fallback={<Spinner />}>
  <Show when={post()} fallback={<p>Not found</p>}>
    <Article post={post()!} />
  </Show>
</Suspense>
```

## Solid vs React Comparison

| Feature | React | Solid |
|---------|-------|-------|
| Rendering | VDOM diffing | Fine-grained DOM updates |
| Re-renders | Component re-renders | Only affected DOM nodes update |
| State | `useState` hook | `createSignal` |
| Derived | `useMemo` | `createMemo` |
| Effects | `useEffect` | `createEffect` |
| Context | `useContext` + Provider | Same API |
| Lists | `key` prop | `<For>` component |
| Conditionals | Ternary/`&&` | `<Show>` component |
| Performance | Good with memoization | Excellent by default |

## Resources

- SolidJS docs: https://www.solidjs.com/docs/latest
- Solid Router: https://docs.solidjs.com/solid-router
- Tutorial: https://www.solidjs.com/tutorial

## User Interaction (MANDATORY)

When activated, ask:

1. **Background:** "Bạn có background React không? Để tôi highlight key differences"
2. **Task:** "Bạn cần xây dựng gì? (component/store/routing/async data)"
3. **Pattern:** "Đây là SPA hay SSR (SolidStart)?"

Then provide idiomatic Solid code with explanations of reactivity differences.
